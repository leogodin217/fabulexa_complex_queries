# PACK-101 — solution

## The bug

`mortality_death_monthly` was changed to count deaths by joining each spell
to the patient's **current** `dim_patient` version:

```sql
    join dim_patient
        on dim_patient.patient_id = spell_attributed.patient_id
        and dim_patient.valid_to is null
    where dim_patient.status = 'deceased'
```

`valid_to IS NULL` is the extract's end, not "now" and not "then": it reads
every patient's **final** status into all of history. A patient who died in
November 2025 but had three earlier spells now contributes a "death" to each
of those spells' admission months. 78 real deaths become 119 phantom ones
(one per spell of an ever-deceased patient), landing in admission months,
not death months.

This is the warehouse README's third trap verbatim: *"The current version
is the tape's end, not 'now'. Joining facts to `valid_to IS NULL` rows reads
every patient's final status into all of history."*

Also note the month bug that rode along: with no death instant available,
the buggy code dated deaths by `admitted_at`.

## The fix

Restore the spell-timeline read — the death is the spell's `deceased` state
entry, counted in the month it happened:

```sql
mortality_death_monthly as (
    select
        date_trunc('month', died_at) as month_start,
        specialty,
        count(*) as deaths
    from spell_attributed
    where died_at is not null
    group by 1, 2
),
```

(`died_at` is already computed in the `spell` conforming CTE and carried
through `spell_attributed`; the buggy version simply stopped using it.)

## Why it was silent

Same columns, same 2,376 rows, every value plausible — mortality merely ran
~50% hot and shifted between months. Nothing errors; only the register
comparison (or a set-diff against a known-good pack) catches it.

## Verify

```bash
scripts/check-pack.sh nhs exercises/nhs/reference/performance_pack.sql exercises/nhs/01-phantom-deaths/query.sql
```

46 rows differ before the fix; `EQUAL` after.
