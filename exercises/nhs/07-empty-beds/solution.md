# PACK-107 — solution

## The bug

`ward_stay_interval` gained one line:

```sql
    where spell.ended_at is not null
```

with a comment arguing that a stay with no recorded end "has no measurable
end, so it is excluded from the census rather than guessed at." But a NULL
`ended_at` is not missing data — it is **information**: the spell is still
open at the extract's end, which means the patient is *in the bed* on every
census day from assignment to the end of the extract. Excluding those stays
deletes precisely the patients who are currently occupying beds.

That is why the damage is confined to the end of the window: a stay that is
still open mostly started recently, so the deleted bed-days pile up in the
last month. December 2025 loses 134 of its 873 occupied bed-days (−15%),
and both census metrics (`bed_occupancy_pct` and `bed_day_cost_gbp`) fall
together because they share the census CTE.

The warehouse README's trap list states it directly: *"Open intervals are
NULL-ended, and that is information... Dropping NULL ends from the census
understates recent months."*

## The fix

Remove the `where` clause (and restore the comment that explains the NULL):
the census join already handles the open interval correctly —

```sql
        and (ward_stay_interval.ended_at is null
             or ward_stay_interval.ended_at >= cast(census_day.date as timestamp))
```

an open stay occupies every census day from assignment onward.

## Why it was silent

Only 21 of 2,875 stays are open, so 26 months are completely untouched and
the recent months merely drift low — plausible if you don't ask the wards.
Same shape, same row count, no errors.

## Verify

```bash
scripts/check-pack.sh nhs exercises/nhs/reference/performance_pack.sql exercises/nhs/07-empty-beds/query.sql
```

10 rows differ before the fix (December 2025, five ward specialties × two
census metrics); `EQUAL` after.
