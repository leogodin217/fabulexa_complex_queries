# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

SQL teaching exercises: for each dataset and tier, a clean `reference.sql` and an
`inherited.sql` (the same result after years of "maintenance"), plus an exact grader.
There is no application code, build step, or test framework. The only runtime is the
DuckDB CLI (`duckdb` on PATH, **1.3 or newer** — older releases are an order of magnitude
slower and can OOM on the advanced tier; check with `duckdb --version` before blaming a
query). The warehouse `datasets/<name>/warehouse.duckdb` is gitignored and downloaded by
the setup script (sha256-verified against a GitHub release asset).

## Commands (run from the repo root)

```bash
datasets/saas-billing/setup.sh                                   # fetch + verify warehouse (idempotent)
scripts/run.sh   saas-billing <query.sql>                        # run a query, table to stdout
scripts/run.sh   saas-billing <query.sql> out.csv                # ...or CSV to a file
scripts/check.sh saas-billing <tier> <candidate.sql>             # grade: prints EQUAL / DIFFERENT, exit 0 only on EQUAL
```

`<tier>` is `beginner`, `intermediate`, or `advanced`. Sanity-check the track itself with
`scripts/check.sh saas-billing <tier> exercises/saas-billing/<tier>/inherited.sql` — every
inherited query must be `EQUAL` to its reference. `.bat` twins of each script exist for
Windows and take the same arguments; keep them in sync when changing a `.sh`.

## How grading works

`scripts/check.sh` wraps the reference and the candidate as
`create temp table expected/actual as <query>;` and pipes that plus `scripts/check.sql`
into `duckdb -readonly`. `check.sql` compares column name/type/position (via `describe`)
and then the multiset of rows (`EXCEPT ALL` both ways on each row cast to varchar), and
prints up to 20 differing rows. Consequences:

- Query files must be a single bare `SELECT` (no trailing semicolon, no `.mode` dot
  commands, no DDL) — they are spliced into a `CREATE TABLE AS`.
- Column names, types (`DECIMAL(12,2)` everywhere) and order matter, not just values.
- Row order does not matter; duplicates do.

## Where the truth lives

- `exercises/<dataset>/CONVENTIONS.md` — the pinned side of every billing ambiguity (as-of
  rules, rounding, month spine, stage definitions). The reference implements this exactly;
  any change to a reference query must be reflected here and vice versa.
- `datasets/<dataset>/README.md` — data dictionary and business spec, written by
  fabulexa-forge and copied verbatim. Do not edit by hand.
- `datasets/<dataset>/PROVENANCE.md` — source pack, producer version, digests, release tag.
  Regenerating a warehouse produces a new sha256, which must be updated in `setup.sh`
  (`SHA256`, `TAG`) and here.

## Structure of the exercise queries

- Tiers are prefixes of one pipeline: the beginner and intermediate references are
  literally the advanced reference (`with recursive` chain: `calendar` → `account` →
  `billable_seats` → `metered_usage` → `rated_usage` → `addon_charge` → `term` /
  `commit_*` → `credit` / `ledger` → final select) cut short, so a column shared across
  tiers must carry the same value for the same company-month. Fix a bug in one tier's
  reference and propagate it to the others.
- References: one CTE per spec stage, in stage order, month spine from `dim_date` (never
  generated), all money in `DECIMAL(28,14)` with a single `ROUND` at the end.
  `materialized` CTE hints are performance-only.
- Inherited queries are deliberately ugly (comma joins, deep nesting, copy-pasted
  subqueries, 1,600-char lines) but must stay output-identical. Do not "clean them up";
  that is the learner's exercise.
