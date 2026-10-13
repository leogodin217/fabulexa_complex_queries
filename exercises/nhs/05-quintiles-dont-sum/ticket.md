# PACK-105 — DNA quintile denominators doubled overnight

**From:** Health inequalities lead
**Severity:** High — equity report due
**Kind:** Bug, symptom only

The outpatient DNA family is broken and we cannot see how. Two facts:

1. The clinic system resolved **5,040** outpatient appointments over
   2023–2025 (4,085 attended + 955 DNA). Summing the pack's five
   `outpatient_dna_pct_imd_q*` denominators now gives **10,633** — more
   than double, and not *exactly* double either.
2. The rates themselves moved in every single month, in both directions.
   Our deprivation gradient (q1 worst, q5 best) is still visible but the
   levels are wrong.

Nobody touched the DNA arithmetic — the DNA/attended classification and the
quintile formula are character-for-character what they were. Whatever
changed is in *how the family looks things up*, and it was sold as a
performance improvement.

Find it, explain why the denominator more than doubled (and why the excess
is not uniform), and restore the pack.

## Acceptance

```bash
scripts/check-pack.sh nhs exercises/nhs/reference/performance_pack.sql exercises/nhs/05-quintiles-dont-sum/query.sql
```

prints `EQUAL`. Full explanation in `solution.md` (spoilers).
