# PACK-110 — Stratify the whole pack by deprivation quintile (capstone)

**From:** Board, via the health inequalities programme
**Severity:** Normal — but it touches every family
**Kind:** Change request (the capstone: a grain change)

The board wants the inequality lens on **everything**, not just DNAs. Add an
`imd_quintile` column to the pack and cut every patient-anchored family by
it.

## The contract

Output: one row per **month × specialty × metric × imd_quintile**, dense.
Columns: `month, specialty, metric, imd_quintile, numerator, denominator,
value, target` (the new column sits after `metric`; everything else keeps
its type and meaning; final ordering adds `imd_quintile` last).

- `imd_quintile` is `'q1'`..`'q5'` (q1 = most deprived fifth; quintile =
  `ceil(imd_decile / 2.0)`) or `'all'` for the roll-up.
- The quintile is read from the **dim_patient version in force at the
  family's anchor instant** — the same instant-grain as-of join the DNA
  family already uses, never the current version, never a day-grain key
  join. Anchors: A&E = arrival; the three cancer standards = referral;
  DM01 = order; readmission, mortality and DTOC = the spell's
  admission-triage entry (one read per spell, used by both sides of each
  ratio); FFT = the response's `recorded_at`; DNA = the resolution
  milestone.
- **Patient-anchored families** emit `q1..q5` and `all`. The `all` row must
  equal the unstratified pack's value — the roll-up is your built-in
  regression check.
- **Estate families** (bed occupancy, theatre utilisation, casemix income,
  bed-day cost) emit `all` only: their denominators are capacity and
  catalogue, not patients.
- The DNA family stops smuggling its strata through metric keys:
  `outpatient_dna_pct_imd_q1..q5` become one metric, `outpatient_dna_pct`,
  stratified like everything else.
- Dense inventory: 36 months × 232 (metric, specialty, stratum) pairs =
  **8,352 rows**, key unique. Update the header contract.

Start from `query.sql` (a pristine copy of the reference).

## Acceptance

```bash
scripts/check-pack.sh nhs exercises/nhs/10-imd-stratification/solution.sql exercises/nhs/10-imd-stratification/query.sql
```

prints `EQUAL`. Sanity checks worth running yourself before comparing: the
key is unique over 8,352 rows; each patient family's five quintile
numerators and denominators sum to its `all` row; the `all` slice (plus the
re-keyed DNA quintiles) reproduces the reference pack exactly.
