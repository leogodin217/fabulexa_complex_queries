# Performance pack spec — the pinned conventions

The reference query (`reference/performance_pack.sql`) implements the NHS
metric catalog in `../../datasets/nhs/README.md` exactly. That README is the
authoritative definition of every metric, target, ambiguity and trap; this
file records which side of each ambiguity the **reference** takes and the
exact output contract, so that a set-diff against the reference view is an
exact-equality test. A candidate that picks a different reading is not wrong
about the NHS — it is wrong about *this* pack, and the diff will say where.

## Output

One row per **month × specialty × metric**. The key is unique and the row
inventory is **dense**: every family produces a row for every grid month and
every value of its specialty domain, whether or not anything happened —
a quiet month is `numerator 0, denominator 0, value NULL`, not a missing row.
Set-diff verification depends on this: a candidate that drops empty rows is
`DIFFERENT` by row count alone.

| Column | Type | Meaning |
|---|---|---|
| `month` | `DATE` | first day of the calendar month |
| `specialty` | `VARCHAR` | the family's specialty surface (below); `trust` where the family reports trust-level; `unattributed` where attribution is defined but no allocation covers the anchor instant |
| `metric` | `VARCHAR` | one of the 18 metric keys below |
| `numerator` | `DECIMAL(18,4)` | metric-specific (count, bed-days, £) |
| `denominator` | `DECIMAL(18,4)` | metric-specific |
| `value` | `DECIMAL(14,2)` | the headline figure; `NULL` when `denominator` is 0 |
| `target` | `DECIMAL(14,2)` | the pinned national target, `NULL` where none is pinned |

`value` is rounded exactly once, in the final select (DuckDB `ROUND`, half
away from zero). Intermediates are `DECIMAL` wide enough that nothing rounds
implicitly; `DOUBLE` source columns (`tariff`, `cost_per_bed_day`, the
`hours_from_*` clocks) are cast or compared at the boundary. Row order is not
part of the contract (the reference still `ORDER BY month, metric, specialty`
for readability).

Row inventory: 36 months × 66 (metric, specialty) pairs = **2,376 rows**.

## Time

- **The extract ends** at the last `fact_pathway_state.entered_at`
  (2025-12-31 00:00:00 in this build). It is read from the data, never
  written into the query.
- **The month grid** is `dim_date` grouped by year, month, kept between the
  first and last `fact_pathway_state.entered_at` (2023-01 … 2025-12, 36
  months). The calendar runs to 2028-12-31 because confirmed bookings open
  slots after the extract ends; a grid over all of `dim_date` manufactures
  three empty years.
- **An instant belongs to the month of its `*_date_key`** row on `dim_date`;
  the key renders the same UTC day as the timestamp beside it, so
  `date_trunc('month', <timestamp>)` agrees and a candidate may use either.
- **Interval membership is instant-grain.** A fact instant `t` is inside
  `[from, to)` when `from <= t AND (to IS NULL OR to > t)`. This is the only
  as-of rule in the pack; it reads `dim_patient` versions,
  `fact_consultant_allocation` and every state interval. Day-grain joins
  through the `*_date_key` columns are **wrong here**: 12,693 patient-days
  carry more than one `dim_patient` version.
- **Patient attributes as of an event** are the `dim_patient` version whose
  window contains the event instant — never the `valid_to IS NULL` version.

## Specialty attribution

The spec's default rule is the consultant allocated to the patient at the
episode's **anchor instant** (`fact_consultant_allocation` interval join →
`dim_consultant.main_specialty`), `unattributed` when no allocation covers
it. Families with a native specialty surface use their own dimension. Per
family:

| Family | Rule | Domain (dense) |
|---|---|---|
| A&E 4-hour | allocation at the attendance's `arrived` instant | `110,180,300,301,320,340` + `unattributed` |
| Readmission, mortality, DTOC | allocation at the spell's `admission_triage` instant | same 7 |
| Cancer 2WW / FDS / 62-day | `trust` — consultants are allocated at first contact, so no allocation exists at the referral instant that anchors the denominator | `trust` |
| DM01 | `trust` — 8 of 12 catalogue tests are cross-specialty (blank `main_specialty`) | `trust` |
| FFT | `trust` | `trust` |
| Bed occupancy, bed-day cost | native `dim_ward.main_specialty` | `110,300,301,320,340` |
| Theatre utilisation | native `dim_theatre.theatre_specialty` | `cardiac, day_case, general, obstetric, orthopaedic` |
| Casemix income | native `dim_procedure.main_specialty` | the 13 codes in `dim_procedure` |
| Outpatient DNA × IMD | `trust`; the stratum lives in the metric key | `trust` |

Specialty domains are read from the dimensions (`dim_consultant`,
`dim_ward`, `dim_theatre`, `dim_procedure`), never hardcoded.

## Metrics

Targets are literals in the reference, each defined once in the header
contract comment with its national definition and source (a change request
later converts them to a `VALUES` CTE). "Month of" always means the month of
the named instant.

1. **`ae_4hr_pct`** — target **78.00** (operational target to March 2026;
   the constitutional standard is 95%). Per ED attendance
   (`fact_pathway_state`, `pathway_type = 'ed_attendance'`): clock from the
   `arrived` entry to the first `discharged_home` or `admitted` entry — the
   true arrival-to-departure standard, **not** the `ed_assessment` proxy in
   `fact_emergency_care.minutes_from_arrival`. Month and attribution anchor:
   arrival. Numerator: attendances departing within 4 hours (`departure <=
   arrival + 4 hours`, boundary inclusive). Denominator: attendances arrived
   in the month. An attendance with no departure (none exist in this build,
   but the rule is pinned) stays in the denominator as a breach. The 4-hour
   clock's end for admitted patients is the `admitted` **state entry**
   (decision-to-admit), not the `ward_assignment` milestone.
2a. **`cancer_2ww_first_seen_pct`** — no pinned target (the catalog names
   the 336-hour clock but pins no target; the FDS replaced the 2WW
   operational standard). Numerator = pathways with a `cancer_first_seen`
   milestone at `hours_from_referral <= 336`; denominator = referrals in
   the month. Cutoff: `cancer_referral occurred_at <= extract_end − 336
   hours`.

2b. **`cancer_62day_treatment_pct`** — no pinned target. 1488-hour clock;
   the milestone surface carries no treatment-start row, so the clock's
   end is the pathway's `treatment_started` **state entry** in
   `fact_pathway_state` (the one cancer endpoint read from the state
   timeline — documented in the reference header). Cutoff:
   `cancer_referral occurred_at <= extract_end − 1488 hours`.

2. **`cancer_fds_28day_pct`** — target **75.00** (the Faster Diagnosis
   Standard; it rises to 80% from March 2026). Per cancer pathway
   (`fact_cancer_pathway`): numerator = pathways with a
   `cancer_diagnosis_confirmed` milestone at `hours_from_referral <= 672`;
   denominator = pathways whose `cancer_referral` falls in the month. A
   pathway never diagnosed stays in the denominator as a breach.
   **Right-censoring cutoff (stated, per the README's trap):** only
   referrals with a full 28-day window are reported — `cancer_referral
   occurred_at <= extract_end − 672 hours`; later referrals are excluded
   from numerator and denominator both.
3. **`dm01_6week_pct`** — target **99.00**. Per diagnostic request
   (`fact_diagnostics`): numerator = requests with a `diagnostic_performed`
   milestone at `hours_from_order <= 1008`; denominator = requests whose
   `diagnostic_ordered` falls in the month. Ordered-never-performed stays in
   the denominator. Cutoff as in FDS: `diagnostic_ordered occurred_at <=
   extract_end − 1008 hours`.
4. **`readmission_30day_pct`** — no pinned target (national benchmark
   12–14%). Source of truth is the **computed window**, not the care
   system's recorded loop (315 vs 333 in this extract; the recorded
   `readmitting` states have no 30-day cutoff). Denominator: spells whose
   `inpatient_discharged` entry falls in the month **and** has a full
   follow-up window — `discharge <= extract_end − 30 days`. Numerator:
   those with the same patient's next `admission` milestone in
   `fact_admitted_care` strictly after discharge and within 30 days
   (`> discharge AND <= discharge + 30 days`).
5. **`mortality_pct`** — no pinned target (SHMI context). Crude monthly
   rate: numerator = spells entering the `deceased` state in the month;
   denominator = spells entering `admission_triage` in the month (different
   cohorts — a crude rate, stated as such). Both sides attribute via the
   spell's admission-instant allocation.
6. **`dtoc_mean_days`** — no pinned target (DTOC collection discontinued;
   kept as a delay measure). Over spells whose `inpatient_discharged` entry
   falls in the month and that have a `medically_fit` entry: mean of
   (discharge − medically_fit) in days. `value` = the mean, 2 dp;
   numerator = total delay days; denominator = spells.
7. **`fft_recommend_pct`** — no pinned target (national positive rate
   typically 85–90%). Numerator: `fact_fft_response` outcomes `very_good` +
   `good` recorded in the month. Denominator: recorded outcomes
   **excluding `no_response`**. (The other two defensible denominators —
   all recorded outcomes, and all invitations on `fact_fft` — are the
   subject of a change request.)
8. **`bed_occupancy_pct`** — target **85.00** (the risk threshold; here
   *lower* is better — `value > target` is the alarm). True daily census:
   a stay runs from `fact_ward_stay.assigned_at` to its spell's terminal
   state entry (`inpatient_discharged` or `deceased`, reached via
   `event_id → fact_admitted_care.episode_id`); a stay with no terminal
   entry is **still open** and occupies every census day through the
   extract end. A stay occupies census day `d` when it overlaps `[d, d+1)`
   — the bed-days reading of the census ambiguity, so a same-day stay
   counts its day. Numerator: occupied bed-days in the month per ward
   specialty. Denominator: `total_beds` × days in month, summed over the
   specialty's wards.
9. **`theatre_utilisation_pct`** — no pinned target. Numerator: theatre
   sessions used in the month (`fact_theatre_session` rows, month of
   `used_at`). Denominator: `sessions_per_day` × days in month, summed over
   the specialty's theatres. Ratio of sums over the month — **not** the
   mean of per-day ratios.
10. **`casemix_income_gbp`** — no pinned target. `dim_procedure.tariff` ×
    procedures **performed**: `fact_procedure` joined to
    `fact_surgical_pathway` on `event_id`, keeping `milestone =
    'surgery_performed'` only (the catalogue binds each procedure twice —
    planned and performed). Month of the performing event. `value` = the
    income; numerator = income; denominator = procedures performed.
11. **`bed_day_cost_gbp`** — no pinned target. Occupied bed-days exactly as
    in the census (metric 8) × `dim_ward.cost_per_bed_day`. `value` = the
    cost; numerator = cost; denominator = occupied bed-days.
12. **`outpatient_dna_pct_imd_q1` … `_q5`** — no pinned target; the
    inequality stratification family. Per outpatient episode reaching its
    resolution milestone (`appointment_attended` or `appointment_dna` in
    `fact_outpatient`, month of that instant): numerator = DNAs,
    denominator = both. Stratum: `dim_patient.imd_decile` **as of the
    milestone instant** (the instant-grain as-of join — the decile is
    constant per patient, but the join stays uniform), cast to integer,
    quintile = `ceil(decile / 2.0)`, so `q1` is the most deprived fifth.

## Pinned ambiguity choices (summary)

| Ambiguity (README) | The reference takes |
|---|---|
| Readmission source of truth | computed 30-day window (315), not the recorded loop (333) |
| FFT denominator | recorded outcomes excluding `no_response` |
| Specialty attribution | allocation-based for ED and spell families; native dimension for ward/theatre/procedure families; `trust` for cancer, DM01, FFT, DNA |
| 4-hour clock end for admitted patients | the `admitted` state entry |
| Census instant | day-overlap (bed-days), not midnight head-count |
| Winter | not surfaced in the pack (month grain only) |
| Edge censoring | stated cutoffs: 2WW 336 h, FDS 672 h, 62-day 1488 h, DM01 1008 h, readmission 30 days before extract end; A&E and all others uncensored |

## Verification

`check.sql` defines `pack_diff(expected, actual)` — an `EXCEPT ALL` table
macro over `query_table()` that compares two views (or tables) as multisets
of rows and returns the differing rows tagged `missing` (in expected only) /
`unexpected` (in candidate only). Empty result = the packs are equal.

From the repo root:

```bash
scripts/check-pack.sh nhs exercises/nhs/reference/performance_pack.sql my_pack.sql
```

wraps both files (bare `SELECT`s) as temp views over the read-only
warehouse, loads the macro, prints up to 20 differing rows and a final
`EQUAL` / `DIFFERENT` verdict (exit 0 only on `EQUAL`). The six bug
exercises verify against the reference itself; a change-request exercise
whose ticket changes the output verifies against its own `solution.sql`.
