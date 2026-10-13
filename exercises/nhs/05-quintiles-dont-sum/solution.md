# PACK-105 — solution

## The bug

The patient as-of join in `outpatient_quintile` was rewritten from the
instant-grain form to a **day-grain join through the `*_date_key` columns**:

```sql
    join dim_patient
        on dim_patient.patient_id = outpatient_resolution.patient_id
        and outpatient_resolution.occurred_date_key
            between dim_patient.valid_from_date_key
                and coalesce(dim_patient.valid_to_date_key, 99991231)
```

`dim_patient` is SCD-2 at **timestamp** grain. 12,693 patient-days carry
more than one version (a patient can be `in_ed` and `admitted` within one
afternoon), and on a version boundary the outgoing row's
`valid_to_date_key` **equals** the incoming row's `valid_from_date_key` —
they are the same calendar day. A day-grain BETWEEN therefore matches an
appointment to *every version that touches that day*: usually two, sometimes
three. 5,040 resolutions fan out to 10,633 joined rows. The excess is not
uniform because it lands only on patients whose record was re-versioned on
their appointment day — which correlates with how much care they were
receiving.

This is the warehouse README's second trap, stated almost word for word:
*"The window is timestamp-grain; the day is not the version... joining or
deduplicating at day grain through the `*_date_key` columns collapses real
same-day versions and fans out events."*

The quintile happens to be constant per patient, so every duplicate carries
the *same* quintile — the rates shift only because each duplicated
appointment is counted twice in its quintile's numerator and/or denominator.
Had the stratum been a changing attribute (like `status`), the day-grain
join would also have *mis-assigned* it. Both failure modes come from the
same wrong join.

## The fix

Restore the instant-grain as-of join (and drop `occurred_date_key` from
`outpatient_resolution`, which only the buggy join needed):

```sql
    join dim_patient
        on dim_patient.patient_id = outpatient_resolution.patient_id
        and dim_patient.valid_from <= outpatient_resolution.occurred_at
        and (dim_patient.valid_to is null or dim_patient.valid_to > outpatient_resolution.occurred_at)
```

## Why it was silent

The fan-out happens before the group-by; the output keeps its dense
2,376-row shape. The deprivation gradient survives (the duplicates carry
true quintiles), so the numbers still *look* like the story everyone
expects.

## Verify

```bash
scripts/check-pack.sh nhs exercises/nhs/reference/performance_pack.sql exercises/nhs/05-quintiles-dont-sum/query.sql
```

All 180 DNA rows differ before the fix; `EQUAL` after.
