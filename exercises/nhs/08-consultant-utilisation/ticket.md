# PACK-108 — New metric family: consultant utilisation

**From:** Medical director's office
**Severity:** Normal
**Kind:** Change request (new family)

The metric catalog promises interval-based consultant utilisation ("the old
track could only count events; here allocation is an interval fact with a
capacity denominator") and the pack still doesn't carry it. Add the family.

**`consultant_utilisation_pct`** — time-weighted caseload over capacity,
per **consultant specialty** (the native domain: a caseload interval always
belongs to a consultant, so there is no `unattributed` bucket):

- **Numerator**: caseload-days. For every `fact_consultant_caseload`
  interval overlapping the month: the overlap length in days (fractional —
  seconds / 86,400) × the caseload carried throughout that interval. An
  interval with a NULL end is open and runs to the **extract end**.
- **Denominator**: `dim_consultant.capacity` × days in month, summed over
  the specialty's consultants.
- **Value**: 100 × numerator / denominator, the usual single rounding.
- Dense on the spine like every family: 36 months × 6 specialties = 216 new
  rows, 2,592 total. Update the header contract (19 metric keys).

Two warnings from the data dictionary: `fact_consultant_caseload.caseload`
arrives as **VARCHAR** (cast at the boundary, never aggregate text), and the
ratio is a **ratio of monthly sums**, not a mean of per-day ratios.

Start from `query.sql` (a pristine copy of the reference).

## Acceptance

```bash
scripts/check-pack.sh nhs exercises/nhs/08-consultant-utilisation/solution.sql exercises/nhs/08-consultant-utilisation/query.sql
```

prints `EQUAL`.
