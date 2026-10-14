# NHS performance pack — maintenance exercises

The second flagship track, and the opposite exercise to saas-billing's.
That track hands you bad code that produces right answers and asks you to
decode it. This one hands you **good code** — a single ~1,000-line layered
reference query over the `nhs` warehouse — and asks you to *live inside
it*: find planted silent bugs from a ticket, and land change requests
without breaking the other seventeen metrics.

Fetch the warehouse once with `datasets/nhs/setup.sh`. The data dictionary,
the NHS metric catalog (definitions + national targets), the deliberate
ambiguities and the known traps are in `datasets/nhs/README.md` — the
authoritative spec. `spec.md` here records which side of every ambiguity the
reference takes.

| Path | What it is |
|---|---|
| `spec.md` | The pinned conventions: output contract, time rules, specialty attribution, all 18 metric definitions, censoring cutoffs |
| `reference/performance_pack.sql` | The known-good monthly performance pack: one statement, one `WITH` chain, 18 metrics on a dense month × specialty grid (2,376 rows, unique key) |
| `check.sql` | `pack_diff(expected, actual)` — the `EXCEPT ALL` table macro the harness uses |
| `NN-*/` | One exercise each: `ticket.md` (start here) + `query.sql` (the pack as the ticket hands it to you) + `solution.md` / `solution.sql` (spoilers — openly readable, by design) |

## The exercises

Six tickets carry a single planted silent bug — the query runs clean, keeps
its exact shape, and produces plausible wrong numbers. Four are change
requests against the pristine reference. The ramp: the first two bugs tell
you where to look (navigation training), the middle ones give you only a
symptom, the last one gives you nothing but a diff against the known-good.

| # | Exercise | Kind | You get |
|---|---|---|---|
| 01 | `01-phantom-deaths` | bug | symptom + the family it's in |
| 02 | `02-double-counted-attendances` | bug | symptom + the family it's in |
| 03 | `03-targets-as-data` | change | refactor; output must not move |
| 04 | `04-fds-miracle` | bug | symptom + the suspect diff |
| 05 | `05-quintiles-dont-sum` | bug | symptom only |
| 06 | `06-fft-all-invitations` | change | new denominator definition |
| 07 | `07-empty-beds` | bug | symptom only |
| 08 | `08-consultant-utilisation` | change | a new metric family |
| 09 | `09-regression-hunt` | bug | nothing. Diff and hunt |
| 10 | `10-imd-stratification` | change | the capstone: a grain change touching every family |

Every bug is one of the warehouse README's documented trap classes, planted
where the data actually bites: a current-version SCD-2 read, a dropped
interval predicate, a denominator exclusion, a day-grain join through
`*_date_key` columns, discarded open intervals, a deleted right-censoring
cutoff. The header contract at the top of each `query.sql` still states the
*correct* rule — spotting code that no longer does what its contract says is
most of the job.

## Run and check

From the repo root, with the DuckDB CLI (1.3+) on `PATH`:

```bash
datasets/nhs/setup.sh                                               # once
scripts/run.sh nhs exercises/nhs/reference/performance_pack.sql     # see the pack
scripts/check-pack.sh nhs <expected.sql> <candidate.sql>            # EQUAL / DIFFERENT, exit 0 on EQUAL
```

Each ticket's acceptance section names its expected file: the six bug
exercises and 03 verify against `reference/performance_pack.sql` (a correct
fix restores the canonical output — output equality, not textual similarity,
is the standard); 06, 08 and 10 verify against their own `solution.sql`.

The two solution forms are deliberate, not drift: a bug ticket ships
`solution.md` — a prose diagnosis — because the correct code is the
reference itself; a change request ships `solution.sql`, the expected query
(for 06, 08 and 10 it is also the acceptance oracle the check runs against),
with its rationale required in the file's header comment.

Working inside `duckdb` directly, the same comparison is two temp views and
the macro:

```sql
.read exercises/nhs/check.sql
create temp view expected as <select ...>;
create temp view actual   as <select ...>;
select * from pack_diff('expected', 'actual');   -- empty = equal
```

Each metric family in the reference is independently SELECT-able: swap the
final select for `select * from <family>_rows` while you work.
