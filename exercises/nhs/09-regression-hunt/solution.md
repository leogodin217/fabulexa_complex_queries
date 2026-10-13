# PACK-109 — solution

## The hunt

`pack_diff` returns 10 rows (5 missing, 5 unexpected). Reading them: every
one is `readmission_30day_pct`, every one is **December 2025** — the last
month of the extract — and the candidate's denominators are *larger* while
the rates are *lower*. One family, one month, at the reporting edge,
rates diluted: that pattern is right-censoring mishandled.

## The bug

The tidy-up deleted the readmission family's censoring cutoff (and the
`activity_window` reference it used):

```sql
    where spell_attributed.discharged_at is not null
-     and spell_attributed.discharged_at <= activity_window.extract_end - interval 30 day
```

The 30-day readmission window of a December discharge extends past the end
of the extract: a patient discharged on 20 December who bounces back on
10 January *will* be a readmission, but this extract cannot see it. Counting
those discharges in the denominator scores every unobservable readmission
as a success — December's rate dips for no clinical reason (112 censored
discharges re-enter the denominator; only the 2 readmissions that happened
to land before the extract end re-enter the numerator).

The header contract states the rule the edit broke: *"Censoring, stated:
only discharges with a full 30-day follow-up window count (discharge <=
extract end − 30 days)."* The README's trap list generalises it:
*"readmission and FDS/DM01 clocks near the extract edge are right-censored —
the pack must state its cutoff."*

## The fix

Restore the cutoff:

```sql
    from spell_attributed
    cross join activity_window
    where spell_attributed.discharged_at is not null
      and spell_attributed.discharged_at <= activity_window.extract_end - interval 30 day
```

(and the comment that declares the denominator rule).

## Why no one noticed

A *lower* readmission rate in the newest month reads as good news, the other
35 months are untouched, and the shape is identical. Only the archived
known-good pack made it findable — which is the lesson: a dashboard at the
reporting edge needs a stated cutoff, and a pack needs a regression baseline.

## Verify

```bash
scripts/check-pack.sh nhs exercises/nhs/reference/performance_pack.sql exercises/nhs/09-regression-hunt/query.sql
```

5 rows missing / 5 unexpected before the fix; `EQUAL` after.
