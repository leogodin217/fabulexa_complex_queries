# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

SQL teaching exercises in two track shapes. The **tier track** (saas-billing): for each
tier, a clean `reference.sql` and an `inherited.sql` (the same result after years of
"maintenance"), plus an exact grader. The **pack track** (nhs): one clean ~1,000-line
reference query (`exercises/nhs/reference/performance_pack.sql`) and ten maintenance
exercises — six variants with a single planted silent bug each, four change requests —
graded by set-diff against the reference or the exercise's own `solution.sql`.
There is no application code, build step, or test framework. The only runtime is the
DuckDB CLI (`duckdb` on PATH, **1.3 or newer** — older releases are an order of magnitude
slower and can OOM on the advanced tier; check with `duckdb --version` before blaming a
query). The warehouse `datasets/<name>/warehouse.duckdb` is gitignored and downloaded by
the setup script (sha256-verified against a GitHub release asset).

## Commands (run from the repo root)

```bash
datasets/<name>/setup.sh                                         # fetch + verify warehouse (idempotent)
scripts/run.sh   <name> <query.sql>                              # run a query, table to stdout
scripts/run.sh   <name> <query.sql> out.csv                      # ...or CSV to a file
scripts/check.sh saas-billing <tier> <candidate.sql>             # tier grader: EQUAL / DIFFERENT, exit 0 only on EQUAL
scripts/check-pack.sh nhs <expected.sql> <candidate.sql>         # pack grader: same verdict, any two bare SELECTs
```

`<tier>` is `beginner`, `intermediate`, or `advanced`. Sanity-check the saas track with
`scripts/check.sh saas-billing <tier> exercises/saas-billing/<tier>/inherited.sql` (every
inherited query must be `EQUAL`), and the nhs track per each exercise's `ticket.md`
acceptance line: the six bug exercises must be `DIFFERENT` against the reference as
shipped (they carry the planted bug) and `EQUAL` once fixed; `03/06/08/10`'s
`solution.sql` must be `EQUAL` to its ticket's expected side. `.bat` twins of each script
exist for Windows and take the same arguments; keep them in sync when changing a `.sh`.

## How grading works

`scripts/check.sh` wraps the reference and the candidate as
`create temp table expected/actual as <query>;` and pipes that plus `scripts/check.sql`
into `duckdb -readonly`. `check.sql` compares column name/type/position (via `describe`)
and then the multiset of rows (`EXCEPT ALL` both ways on each row cast to varchar), and
prints up to 20 differing rows. `scripts/check-pack.sh` is the same idea for the nhs
track: it wraps two files as temp views and diffs them with the `pack_diff` table macro
(`exercises/nhs/check.sql`, `EXCEPT ALL` over `query_table()`, rows tagged
missing/unexpected). Consequences:

- Query files must be a single bare `SELECT` (no trailing semicolon, no `.mode` dot
  commands, no DDL) — they are spliced into a `CREATE TABLE AS`.
- Column names, types (`DECIMAL(12,2)` everywhere) and order matter, not just values.
- Row order does not matter; duplicates do.

## Where the truth lives

- `exercises/<dataset>/CONVENTIONS.md` — the pinned side of every billing ambiguity (as-of
  rules, rounding, month spine, stage definitions). The reference implements this exactly;
  any change to a reference query must be reflected here and vice versa.
- `datasets/<dataset>/README.md` and `<dataset>-dimensional-manifest.json` — data
  dictionary, business spec and machine-readable manifest (column `references`), written
  by fabulexa-forge's export and copied verbatim. Do not edit by hand.
- `datasets/<dataset>/PROVENANCE.md` — source pack, producer version, digests, release tag.
  Regenerating a warehouse produces a new sha256, which must be updated in `setup.sh`
  (`SHA256`, `TAG`) and here.

## Structure of the exercise queries

### nhs (pack track)

- The reference is one `WITH` chain in strict layers (base extracts → conforming →
  one CTE family per metric → dense spine assembly → single-rounding presentation),
  18 metric keys, one row per month × specialty × metric (2,376 rows, unique key).
  `exercises/nhs/spec.md` pins every ambiguity; the generated
  `datasets/nhs/README.md` is the authoritative metric catalog — change neither
  lightly, and never the dataset README (vendored verbatim).
- Each `NN-*/query.sql` is the full reference with at most one surgical difference.
  Bug variants must stay *silent*: same columns, same dense row inventory, values
  only. The header contract in each variant still states the correct rule — the
  contradiction between contract and code is the exercise. Don't "fix" a planted
  bug or its misleading comment outside that exercise's solution flow.
- Solutions are openly readable by design (`solution.md` for bugs, `solution.sql`
  for change requests).

### saas-billing (tier track)

- Tiers are prefixes of one pipeline: the beginner and intermediate references are
  literally the advanced reference (`with recursive` chain: `calendar` → `account` →
  `billable_seats` → `metered_usage` → `rated_usage` → `addon_charge` → `term` /
  `commit_*` → `credit` / `ledger` → final select) cut short, so a column shared across
  tiers must carry the same value for the same company-month. Fix a bug in one tier's
  reference and propagate it to the others.
- References: one CTE per spec stage, in stage order, month spine from `dim_date` (never
  generated; the calendar runs 2025-12-01..2031-12-31, past the data at both ends, and
  each account's billing span bounds the spine), all money in `DECIMAL(28,14)` with a
  single `ROUND` at the end.
  `materialized` CTE hints are performance-only.
- Inherited queries are deliberately ugly (comma joins, deep nesting, copy-pasted
  subqueries, 1,600-char lines) but must stay output-identical. Do not "clean them up";
  that is the learner's exercise.
