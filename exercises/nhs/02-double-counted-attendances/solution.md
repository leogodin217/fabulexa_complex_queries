# PACK-102 — solution

## The bug

`ed_attributed` lost the closing half of the interval predicate:

```sql
    left join allocation
        on allocation.patient_id = ed_attendance.patient_id
        and allocation.allocated_at <= ed_attendance.arrived_at
```

An interval join needs all three predicates — key match, started on or
before the instant, **and not yet ended**. Without
`released_at IS NULL OR released_at > arrived_at`, an attendance matches
*every allocation the patient has ever had* up to that instant, not just the
live one. A frequent attender with four historical allocations now counts as
four attendances, one per allocation's specialty: 8,467 attendances fan out
to 11,980 rows, numerators and denominators both inflate, and the specialty
mix tilts toward whatever specialties patients saw in the past.

This is the README's interval-fact trap: *"joining one to an event without
the full three-predicate interval join multiplies rows."*

## The fix

Restore the third predicate:

```sql
    left join allocation
        on allocation.patient_id = ed_attendance.patient_id
        and allocation.allocated_at <= ed_attendance.arrived_at
        and (allocation.released_at is null or allocation.released_at > ed_attendance.arrived_at)
```

## Why it was silent

The fan-out happens *before* the group-by, so the output keeps its exact
2,376-row dense shape — only the counts inside it are wrong. Percentages
stay in plausible ranges because numerator and denominator inflate together
(but not equally: a duplicated attendance carries its breach status to every
copy, under a different specialty).

## Verify

```bash
scripts/check-pack.sh nhs exercises/nhs/reference/performance_pack.sql exercises/nhs/02-double-counted-attendances/query.sql
```

185 rows differ before the fix; `EQUAL` after.
