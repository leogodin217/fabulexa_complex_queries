# BILL-207 — solution

## The bug

DQ-412's "fix" put a dedupe between the warehouse and the seats stage:

```sql
seat_version as (
    select user_id, status, valid_from, valid_to
    from dim_user_status
    qualify row_number() over (
        partition by user_id, valid_from
        order by valid_to asc nulls last, status
    ) = 1
),
```

and pointed `billable_seats` at `seat_version` instead of
`dim_user_status`. On every `(user_id, valid_from)` that carries two
versions, it keeps exactly one — and `order by valid_to asc` keeps the one
whose `valid_to` is smallest. That is always the **zero-length** version
(`valid_to = valid_from`, the smallest value the column can take on that
day), so the row that gets deleted is always the one that spans time.

## Why the dedupe is wrong

`dim_user_status` versions are **date-grained**: `valid_from` and
`valid_to` are `DATE`, not timestamps. A seat that changes state twice in
one day therefore legitimately puts two versions on the same
`(user_id, valid_from)` — and the simulation does this constantly, because
provisioning and activation routinely happen the same day:

| user | status | valid_from | valid_to |
|---|---|---|---|
| USR-000001 | provisioned | 2026-01-23 | 2026-01-23 |
| USR-000001 | active | 2026-01-23 | 2027-01-14 |
| USR-000001 | offboarded | 2027-01-14 | NULL |

The first row is a **zero-length version**: its half-open window
`[2026-01-23, 2026-01-23)` contains no instant at all. It is not a
double-write and not noise — it is real history. It records that the seat
*passed through* `provisioned`, and in what order, on a day too coarse for
the grain to show the duration. What a zero-length version carries is the
**transition**, not time: delete it and you can no longer see that this
seat was provisioned before it activated.

So at date grain, `(user_id, valid_from)` was never the version's
identity. The identity is the three-part key **`(user_id, valid_from,
status)`** — exactly what the warehouse README's last "Known traps" bullet
says, for this table and for `dim_company`. The audit imported a
timestamp-grain assumption into a date-grain table; the premise, not the
data, was dirty.

And the table needs no "protecting", because half-open interval logic
already handles it:

- **As-of joins still match exactly one row.** For any instant on
  2026-01-23, `valid_from <= t < valid_to` is false for the empty
  `[23rd, 23rd)` window and true for `[23rd, 2027-01-14)`. Zero ambiguity,
  no fan-out, nothing to dedupe.
- **Overlap arithmetic gives it zero days.** The seats stage clamps each
  interval to the month and sums day counts; a zero-length interval clamps
  to zero days and contributes nothing.

That immunity is also why the damage was silent: every *correct* reader of
the table is indifferent to the zero-length row. The only query the dedupe
could ever change is the dedupe's own — by deleting the other row.

Here the dedupe deleted 3,672 rows: 3,670 `active` versions (1,830 closed,
1,840 still open at the end of the extract — those seats lost their entire
billable tail) and, in the two pairs where a seat was activated and
offboarded the same day, 2 `offboarded` versions nothing billable ever
read. USR-000001 above keeps only its zero-length `provisioned`
row and its `offboarded` row: 357 days of a live seat, gone. Summed over
the run: $6.80M of $17.89M in seat charges (38%), 7,935 of 10,284
company-months, 417 of 541 companies, every error downward — seat-days can
only be removed by this bug, never added.

## The fix

Delete the `seat_version` CTE and point the seats stage back at the
dimension:

```sql
    join dim_user_status as seat
        on seat.user_id = dim_user.user_id
        and seat.status in ('active', 'using')
        and seat.valid_from < billing_month.next_month_start
        and (seat.valid_to is null or seat.valid_to > billing_month.month_start)
```

The fixed file is the beginner reference again. The half-open overlap
predicate *is* the handling of same-day versions; there is nothing to add.

And close DQ-412 by fixing the audit, not the table: the uniqueness test
belongs on `(user_id, valid_from, status)`, where the warehouse really is
unique.

## The traps inside the trap

Two follow-ups the ticket's question 2 is really probing:

- **The "careful" dedupe is still wrong.** Flipping the order to
  `valid_to desc nulls first` keeps the long version and would leave this
  bill byte-identical — and it still destroys history. The zero-length
  rows carry the transitions: any consumer that counts state *entries*
  (onboarding funnels, time-to-activation, an "ever provisioned" flag)
  breaks, and the bill's indifference is a coincidence of what this one
  query reads. "Which version is in force at instant t?" is a question
  for the as-of join, answered per query; it is not a repair to perform
  on the table.
- **`dim_company` is the same trap, masked harder.** It carries 226
  same-day pairs of its own (zero-length `onboarding` + `active`,
  first on 2026-01-04). Dedupe it the same way and this query's output
  does not move — the churn lookup reads only `status = 'churned'`
  versions, which never share a day — so the audit would have called that
  "fix" safe too. Unchanged output is evidence of nothing: the join that
  would expose the damage just isn't in this query yet.

## Verify

```bash
scripts/check.sh saas-billing beginner exercises/saas-billing/01-debug-the-dedupe/query.sql
```

7,935 rows missing and 7,935 extra before the fix; `EQUAL` after.
