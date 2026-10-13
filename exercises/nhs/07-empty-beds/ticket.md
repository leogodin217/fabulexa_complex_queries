# PACK-107 — December occupancy collapsed; the wards say they're full

**From:** Site operations / finance, jointly
**Severity:** High — winter escalation decisions use this number
**Kind:** Bug, symptom only

This month's pack shows bed occupancy **falling** in December 2025 on every
ward group — cardiology (320) dropped from 42.14% in the last known-good run
to 34.48%, general medicine (300) from 39.86% to 32.03% — and `bed_day_cost_gbp`
fell with it. The ward sisters say December is the fullest they have been
all year, and every earlier month in the pack is untouched.

Two more observations from our own digging:

- The damage is **only in the most recent month**, and only in the two
  census-based metrics.
- The patients "missing" from the December census seem to be the ones who
  are **still here** — long-stayers admitted in November and December who
  have not been discharged yet.

Something in the census changed in the last maintenance pass. Find it,
explain why it only bites at the end of the extract, and restore the pack.

## Acceptance

```bash
scripts/check-pack.sh nhs exercises/nhs/reference/performance_pack.sql exercises/nhs/07-empty-beds/query.sql
```

prints `EQUAL`. Full explanation in `solution.md` (spoilers).
