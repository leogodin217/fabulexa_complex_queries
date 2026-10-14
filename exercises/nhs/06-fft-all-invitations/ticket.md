# PACK-106 — FFT: report the recommend rate over invitations, not responses

**From:** Patient experience team
**Severity:** Normal
**Kind:** Change request

The pack's FFT recommend rate currently divides positive outcomes by
*recorded outcomes excluding non-responses*. For the equity work we need the
harder number: **recommends over every invitation sent**. A patient who
never answers is part of the story — non-response is known to skew by
deprivation, so the flattering denominator hides exactly what we're looking
for.

The new definition for `fft_recommend_pct`:

- **Numerator** (unchanged): `very_good` + `good` outcomes recorded in the
  month (`fact_fft_response.recorded_at`).
- **Denominator**: all invitations **sent** in the month
  (`fact_fft.occurred_at`) — a different event stream on a different
  instant. Do not filter one through the other; aggregate each in its own
  month and join on the grid.

Everything else in the pack must not move. Expect the rate to drop — that is
the point. (For the whole extract: 1,213 recommends over 2,286 invitations ≈
53%, down from ≈ 72%.)

Start from `query.sql` (a pristine copy of the reference).

## Acceptance

```bash
scripts/check-pack.sh nhs exercises/nhs/06-fft-all-invitations/solution.sql exercises/nhs/06-fft-all-invitations/query.sql
```

prints `EQUAL` (exactly the 36 FFT rows differ from the reference).
