# fabulexa_complex_queries

Exercises for understanding, improving and reverse-engineering complex SQL
queries — against realistic warehouses, with an exact grader, and nothing to
install beyond the [DuckDB CLI](https://duckdb.org/docs/installation/)
(1.3 or newer — older releases run these queries an order of magnitude slower
and can run out of memory on the advanced tier).

Each dataset is a finished DuckDB warehouse published as a release asset of
this repo and fetched by a one-line setup script. Each exercise track pairs a
clean **reference** query with an **inherited** one — the same result after
years of maintenance — and a grader that says exactly where a candidate
differs from the reference.

```
datasets/<name>/      README.md (data dictionary + spec) · setup.sh / setup.bat · PROVENANCE.md
exercises/<name>/     README.md · CONVENTIONS.md · <tier>/reference.sql · <tier>/inherited.sql
scripts/              run.sh / run.bat · check.sh / check.bat (+ check.sql, the grader)
```

## Quick start

```bash
datasets/saas-billing/setup.sh                       # downloads warehouse.duckdb (~75 MB) and verifies it
scripts/run.sh   saas-billing exercises/saas-billing/beginner/inherited.sql
scripts/check.sh saas-billing beginner my_query.sql  # EQUAL / DIFFERENT, exit 0 only on EQUAL
```

Windows: `setup.bat`, `run.bat`, `check.bat` — same arguments.

## Datasets

| Name | What it is | Tracks |
|---|---|---|
| [`saas-billing`](datasets/saas-billing/README.md) | A B2B SaaS vendor's billing warehouse over five years — accounts, seats, a metered usage firehose, tier ladders, promotions, commits and credits; the facts of a monthly invoice, never the invoice itself | [billing query exercises](exercises/saas-billing/README.md), three tiers |

Warehouses are produced by [fabulexa-forge](https://github.com/leogodin217/fabulexa_forge)
from simulated base-layer emits; each dataset's `PROVENANCE.md` records the
source pack, producer version and digests so it can be regenerated.

## Grading

`scripts/check.sh <dataset> <tier> <candidate.sql>` runs the tier's reference
and the candidate as temp tables over the read-only warehouse, then compares
column names, types and order, and the multiset of rows (`EXCEPT ALL` both
ways). Exact equality is the bar; the conventions file of each track says
which side of every ambiguity the reference takes, so a `DIFFERENT` verdict
is always attributable.
