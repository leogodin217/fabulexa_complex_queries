-- ============================================================================
-- Monthly trust performance pack — the reference (clean) form.
-- ============================================================================
--
-- One statement, one WITH chain, strictly layered:
--
--     base extracts  ->  conforming CTEs  ->  one CTE family per metric
--                    ->  spine assembly   ->  final presentation
--
-- Runs against datasets/nhs/warehouse.duckdb. The data dictionary and the
-- metric catalog this query implements are in datasets/nhs/README.md; the
-- pinned side of every ambiguity is in ../spec.md. Every metric family is
-- independently SELECT-able: replace the final select with
-- `select * from <family>_rows` to see one family on its spine.
--
-- Output: one row per month x specialty x metric — dense. Every family
-- emits a row for every spine month and every value of its specialty
-- domain; a quiet month is numerator 0, denominator 0, value NULL, never a
-- missing row. 36 months x 66 (metric, specialty) pairs = 2,376 rows, and
-- (month, specialty, metric) is unique, so a set-diff against a known-good
-- pack identifies every discrepancy row-for-row.
--
--     month        DATE           first day of the calendar month
--     specialty    VARCHAR        the family's specialty surface; 'trust'
--                                 where the family reports trust-level;
--                                 'unattributed' where attribution is
--                                 defined but no allocation covers the
--                                 anchor instant
--     metric       VARCHAR        one of the 18 metric keys below
--     numerator    DECIMAL(18,4)  metric-specific (count, bed-days, GBP)
--     denominator  DECIMAL(18,4)  metric-specific
--     value        DECIMAL(14,2)  headline figure; NULL when denominator 0
--     target       DECIMAL(14,2)  pinned national target, NULL where none
--
-- ---------------------------------------------------------------------------
-- THE TARGET CONTRACT — every target in this pack, defined once, here.
-- Each is a literal in its family's rows CTE; the definitions and sources
-- are the metric catalog in datasets/nhs/README.md.
-- ---------------------------------------------------------------------------
--
--   ae_4hr_pct              78.00   A&E 4-hour standard, operational target
--                                   to March 2026 (the constitutional
--                                   standard is 95%). Clock: 'arrived' state
--                                   entry to the first 'discharged_home' or
--                                   'admitted' state entry — arrival to
--                                   departure, the real standard, NOT the
--                                   ed_assessment proxy carried by
--                                   fact_emergency_care.minutes_from_arrival.
--                                   For admitted patients the clock ends at
--                                   the 'admitted' STATE entry (decision to
--                                   admit), not the ward_assignment
--                                   milestone. Boundary inclusive: departure
--                                   <= arrival + 4 hours meets the standard.
--                                   No departure recorded = a breach, still
--                                   in the denominator.
--
--   cancer_fds_28day_pct    75.00   Cancer 28-day Faster Diagnosis Standard
--                                   (rises to 80% from March 2026). Clock:
--                                   hours_from_referral on the
--                                   cancer_diagnosis_confirmed milestone;
--                                   FDS = 672 hours. Never-diagnosed stays
--                                   in the denominator as a breach.
--                                   Right-censoring cutoff, stated: only
--                                   referrals with a full 28-day window are
--                                   reported (cancer_referral occurred_at <=
--                                   extract end - 672 hours).
--
--   cancer_2ww_first_seen_pct
--                           none    Two-week-wait first-seen standard: the
--                                   same hours_from_referral clock read at
--                                   the cancer_first_seen milestone, 336
--                                   hours. The catalog pins no target (the
--                                   FDS replaced the 2WW operational
--                                   standard). Cutoff: referral <= extract
--                                   end - 336 hours.
--
--   cancer_62day_treatment_pct
--                           none    62-day referral-to-treatment standard,
--                                   1488 hours. The milestone surface
--                                   carries no treatment-start row, so the
--                                   clock's end is the pathway's
--                                   treatment_started STATE entry in
--                                   fact_pathway_state — documented here
--                                   because it is the one cancer endpoint
--                                   read from the state timeline. Cutoff:
--                                   referral <= extract end - 1488 hours
--                                   (without it the last two months report
--                                   a manufactured collapse).
--
--   dm01_6week_pct          99.00   Diagnostic 6-week wait (DM01). Clock:
--                                   hours_from_order on the
--                                   diagnostic_performed milestone; 6 weeks
--                                   = 1008 hours. Ordered-never-performed
--                                   stays in the denominator. Cutoff as in
--                                   FDS: ordered <= extract end - 1008 h.
--
--   readmission_30day_pct   none    30-day emergency readmission (national
--                                   benchmark 12-14%). Computed window over
--                                   discharges and the patient's next
--                                   admission milestone — the care system's
--                                   own recorded loop (post_discharge
--                                   'readmitting', 333 in this extract) has
--                                   no 30-day cutoff and is NOT this metric
--                                   (the computed window finds 315).
--                                   Censoring, stated: only discharges with
--                                   a full 30-day follow-up window count
--                                   (discharge <= extract end - 30 days).
--
--   mortality_pct           none    Crude in-hospital mortality, SHMI
--                                   context only: deaths in month over
--                                   admissions in month — different cohorts,
--                                   stated as such.
--
--   dtoc_mean_days          none    Mean medically-fit-to-discharge delay
--                                   over the month's discharges (the DTOC
--                                   collection was discontinued Feb 2020;
--                                   kept as a delay measure).
--
--   fft_recommend_pct       none    Friends and Family Test recommend rate
--                                   (nationally ~85-90% positive).
--                                   Numerator very_good + good; denominator
--                                   recorded outcomes excluding no_response.
--
--   bed_occupancy_pct       85.00   The 85% risk threshold — here LOWER is
--                                   better; value above target is the
--                                   alarm. True daily census from ward-stay
--                                   intervals: a stay runs from assigned_at
--                                   to its spell's terminal state entry
--                                   (discharge or death); a stay with no
--                                   terminal entry is still open and
--                                   occupies every day through the extract
--                                   end. A stay occupies census day d when
--                                   it overlaps [d, d+1) — the bed-days
--                                   reading, so a same-day stay counts.
--
--   theatre_utilisation_pct none    Sessions used over sessions available
--                                   (sessions_per_day x days in month).
--                                   Ratio of monthly sums, not the mean of
--                                   per-day ratios.
--
--   casemix_income_gbp      none    Tariff x procedures PERFORMED — the
--                                   procedure catalogue binds each operation
--                                   twice (planned at pre_op_assessment,
--                                   performed at surgery_performed); income
--                                   keeps milestone = 'surgery_performed'
--                                   only.
--
--   bed_day_cost_gbp        none    Occupied bed-days (exactly the census
--                                   above) x dim_ward.cost_per_bed_day.
--
--   outpatient_dna_pct_imd_q1 .. _q5
--                           none    DNA rate stratified by IMD quintile
--                                   (q1 = most deprived fifth; quintile =
--                                   ceil(imd_decile / 2.0), the decile read
--                                   from the dim_patient version in force
--                                   at the appointment instant — the
--                                   instant-grain as-of join, never the
--                                   valid_to IS NULL version).
--
-- Time conventions: the extract ends at the last fact_pathway_state entry,
-- read from the data; the month spine is dim_date months between the first
-- and last pathway entry (the calendar itself runs years past the data —
-- 877 confirmed bookings open slots after the extract ends). An instant
-- belongs to the month of its *_date_key day; interval membership is
-- instant-grain: from <= t AND (to IS NULL OR to > t). Day-grain joins
-- through *_date_key columns are wrong against dim_patient: 12,693
-- patient-days carry more than one version.
--
-- Specialty attribution: ED and inpatient-spell families use the consultant
-- allocated to the patient at the episode's anchor instant (arrival for ED,
-- admission_triage for spells) via fact_consultant_allocation ->
-- dim_consultant.main_specialty, 'unattributed' when no allocation covers
-- it. Ward, theatre and procedure families use their own dimension's
-- specialty. Cancer FDS, DM01, FFT and the DNA family report trust-level.
-- Domains are read from the dimensions, never hardcoded.
-- ============================================================================

with

-- ---------------------------------------------------------------- calendar

-- One row per calendar month, straight from the warehouse calendar. Nothing
-- about the spine is generated in the query: days_in_month is a row count
-- and next_month_start is the day after the month's last row.
calendar as (
    select
        year,
        month,
        min(date) as month_start,
        cast(max(date) + interval 1 day as date) as next_month_start,
        count(*) as days_in_month
    from dim_date
    group by year, month
),

-- The clinical activity window. The extract ends at the last pathway-state
-- entry; both bounds are read from the data so the query never carries a
-- hardcoded date.
activity_window as (
    select
        min(entered_at) as first_entry,
        max(entered_at) as extract_end
    from fact_pathway_state
),

-- The month spine: calendar months that overlap the activity window. The
-- warehouse calendar runs three years past the data (bookings open slots
-- after the extract ends); grouping all of dim_date would manufacture
-- empty years, so the spine is bounded here, once, for every family.
spine_month as materialized (
    select
        calendar.month_start,
        calendar.next_month_start,
        calendar.days_in_month
    from calendar
    cross join activity_window
    where calendar.month_start >= date_trunc('month', activity_window.first_entry)
      and calendar.month_start <= date_trunc('month', activity_window.extract_end)
),

-- ------------------------------------------------- specialty domains

-- The allocation-attributed families' domain: every consultant specialty,
-- plus the 'unattributed' bucket for events no allocation covers.
specialty_consultant as (
    select distinct main_specialty as specialty from dim_consultant
    union all
    select 'unattributed'
),

specialty_ward as (
    select distinct main_specialty as specialty from dim_ward
),

specialty_theatre as (
    select distinct theatre_specialty as specialty from dim_theatre
),

specialty_procedure as (
    select distinct main_specialty as specialty from dim_procedure
),

-- ------------------------------------------------- conforming: allocation

-- Consultant allocations with the specialty they confer. An event instant t
-- resolves to the allocation with allocated_at <= t < released_at (NULL
-- released_at = still allocated at the extract end).
allocation as materialized (
    select
        fact_consultant_allocation.patient_id,
        fact_consultant_allocation.allocated_at,
        fact_consultant_allocation.released_at,
        dim_consultant.main_specialty
    from fact_consultant_allocation
    join dim_consultant
        on dim_consultant.consultant_id = fact_consultant_allocation.consultant_id
),

-- ------------------------------------------------- conforming: ED episodes

-- One row per A&E attendance: the arrival instant and the departure
-- instant (first discharged_home or admitted state entry — the admitted
-- STATE, not the ward_assignment milestone). A departure can be missing
-- only while the attendance is still open at the extract end.
ed_attendance as (
    select
        episode_id,
        any_value(patient_id) as patient_id,
        min(entered_at) filter (state = 'arrived') as arrived_at,
        min(entered_at) filter (state in ('discharged_home', 'admitted')) as departed_at
    from fact_pathway_state
    where pathway_type = 'ed_attendance'
    group by episode_id
),

-- Each attendance attributed to the specialty of the consultant allocated
-- at the arrival instant.
ed_attributed as (
    select
        ed_attendance.episode_id,
        ed_attendance.arrived_at,
        ed_attendance.departed_at,
        coalesce(allocation.main_specialty, 'unattributed') as specialty
    from ed_attendance
    left join allocation
        on allocation.patient_id = ed_attendance.patient_id
        and allocation.allocated_at <= ed_attendance.arrived_at
        and (allocation.released_at is null or allocation.released_at > ed_attendance.arrived_at)
),

-- ------------------------------------------------- conforming: spells

-- One row per inpatient spell with its anchor instants: admission triage,
-- medically-fit, and the terminal state entry (discharge or death). A spell
-- with no terminal entry is still open at the extract end.
spell as materialized (
    select
        episode_id,
        any_value(patient_id) as patient_id,
        min(entered_at) filter (state = 'admission_triage') as admitted_at,
        min(entered_at) filter (state = 'medically_fit') as fit_at,
        min(entered_at) filter (state = 'inpatient_discharged') as discharged_at,
        min(entered_at) filter (state = 'deceased') as died_at,
        min(entered_at) filter (state in ('inpatient_discharged', 'deceased')) as ended_at
    from fact_pathway_state
    where pathway_type = 'inpatient_spell'
    group by episode_id
),

-- Each spell attributed to the specialty of the consultant allocated at the
-- admission-triage instant. Every spell family (readmission, mortality,
-- DTOC) reads this one attribution.
spell_attributed as materialized (
    select
        spell.episode_id,
        spell.patient_id,
        spell.admitted_at,
        spell.fit_at,
        spell.discharged_at,
        spell.died_at,
        spell.ended_at,
        coalesce(allocation.main_specialty, 'unattributed') as specialty
    from spell
    left join allocation
        on allocation.patient_id = spell.patient_id
        and allocation.allocated_at <= spell.admitted_at
        and (allocation.released_at is null or allocation.released_at > spell.admitted_at)
),

-- ------------------------------------------------- conforming: census

-- One row per ward stay with its occupancy interval: assigned_at to the
-- owning spell's terminal entry, reached via the stay's clinical event.
-- ended_at stays NULL while the spell is open — that is information, not
-- a join failure: the patient is still in the bed at the extract end.
ward_stay_interval as (
    select
        fact_ward_stay.ward_id,
        fact_ward_stay.assigned_at,
        spell.ended_at
    from fact_ward_stay
    join fact_admitted_care
        on fact_admitted_care.event_id = fact_ward_stay.event_id
    join spell
        on spell.episode_id = fact_admitted_care.episode_id
),

-- Every census day in the spine, with its month.
census_day as (
    select
        dim_date.date,
        spine_month.month_start
    from dim_date
    join spine_month
        on dim_date.date >= spine_month.month_start
        and dim_date.date < spine_month.next_month_start
),

-- Occupied bed-days: one row per (stay, census day) the stay overlaps.
-- A stay occupies day d when it overlaps [d, d+1): assigned before the
-- day ends, and not ended before the day starts (NULL end = never ended
-- inside the extract, so it occupies through the last census day).
occupied_bed_day as materialized (
    select
        census_day.month_start,
        census_day.date,
        ward_stay_interval.ward_id
    from census_day
    join ward_stay_interval
        on ward_stay_interval.assigned_at < cast(census_day.date + interval 1 day as timestamp)
        and (ward_stay_interval.ended_at is null
             or ward_stay_interval.ended_at >= cast(census_day.date as timestamp))
),

-- Occupied bed-days per ward per month, with the ward's specialty, bed
-- stock and daily cost alongside.
ward_month as (
    select
        dim_ward.main_specialty as specialty,
        occupied.month_start,
        count(*) as occupied_days,
        any_value(dim_ward.total_beds) as total_beds,
        any_value(dim_ward.cost_per_bed_day) as cost_per_bed_day
    from occupied_bed_day as occupied
    join dim_ward
        on dim_ward.ward_id = occupied.ward_id
    group by dim_ward.main_specialty, dim_ward.ward_id, occupied.month_start
),

-- ============================================================ metric families

-- ------------------------------------------- 1. A&E 4-hour standard

-- Numerator: attendances departing within four hours of arrival (boundary
-- inclusive). Denominator: attendances arrived in the month. A missing
-- departure is a breach: counted in the denominator, never the numerator.
ae_monthly as (
    select
        date_trunc('month', arrived_at) as month_start,
        specialty,
        count(*) filter (
            departed_at is not null
            and departed_at <= arrived_at + interval 4 hour
        ) as within_4h,
        count(*) as attendances
    from ed_attributed
    group by 1, 2
),

ae_rows as (
    select
        spine_month.month_start,
        specialty_consultant.specialty,
        'ae_4hr_pct' as metric,
        coalesce(ae_monthly.within_4h, 0) as numerator,
        coalesce(ae_monthly.attendances, 0) as denominator,
        cast(78.00 as decimal(14,2)) as target
    from spine_month
    cross join specialty_consultant
    left join ae_monthly
        on ae_monthly.month_start = spine_month.month_start
        and ae_monthly.specialty = specialty_consultant.specialty
),

-- ------------------------------------------- 2. Cancer waiting standards

-- One conforming row per cancer pathway: the referral instant and the
-- three clock readings the standards need. The 2WW and FDS clocks are the
-- hours_from_referral column read at their milestone; the milestone
-- surface carries no treatment-start row, so the 62-day clock's end is the
-- pathway's treatment_started STATE entry. A pathway that never reached an
-- endpoint keeps a NULL there — it stays in every denominator its referral
-- qualifies for, as a breach.
cancer_episode as materialized (
    select
        referral.episode_id,
        referral.referred_at,
        first_seen.hours_to_first_seen,
        diagnosis.hours_to_diagnosis,
        treatment.treatment_started_at
    from (
        select episode_id, occurred_at as referred_at
        from fact_cancer_pathway
        where milestone = 'cancer_referral'
    ) as referral
    left join (
        select episode_id, min(hours_from_referral) as hours_to_first_seen
        from fact_cancer_pathway
        where milestone = 'cancer_first_seen'
        group by episode_id
    ) as first_seen
        on first_seen.episode_id = referral.episode_id
    left join (
        select episode_id, min(hours_from_referral) as hours_to_diagnosis
        from fact_cancer_pathway
        where milestone = 'cancer_diagnosis_confirmed'
        group by episode_id
    ) as diagnosis
        on diagnosis.episode_id = referral.episode_id
    left join (
        select episode_id, min(entered_at) as treatment_started_at
        from fact_pathway_state
        where pathway_type = 'cancer_pathway'
          and state = 'treatment_started'
        group by episode_id
    ) as treatment
        on treatment.episode_id = referral.episode_id
),

-- Each standard censors at its own horizon: only referrals old enough to
-- have run the full clock are reported — the clock near the extract edge
-- is right-censored, and the pack states its cutoff rather than reporting
-- a manufactured collapse.
cancer_2ww_monthly as (
    select
        date_trunc('month', cancer_episode.referred_at) as month_start,
        count(*) filter (cancer_episode.hours_to_first_seen <= 336) as within_2ww,
        count(*) as referrals
    from cancer_episode
    cross join activity_window
    where cancer_episode.referred_at <= activity_window.extract_end - interval 336 hour
    group by 1
),

cancer_2ww_rows as (
    select
        spine_month.month_start,
        'trust' as specialty,
        'cancer_2ww_first_seen_pct' as metric,
        coalesce(cancer_2ww_monthly.within_2ww, 0) as numerator,
        coalesce(cancer_2ww_monthly.referrals, 0) as denominator,
        cast(null as decimal(14,2)) as target
    from spine_month
    left join cancer_2ww_monthly
        on cancer_2ww_monthly.month_start = spine_month.month_start
),

fds_monthly as (
    select
        date_trunc('month', cancer_episode.referred_at) as month_start,
        count(*) filter (cancer_episode.hours_to_diagnosis <= 672) as within_28d,
        count(*) as referrals
    from cancer_episode
    cross join activity_window
    where cancer_episode.referred_at <= activity_window.extract_end - interval 672 hour
    group by 1
),

fds_rows as (
    select
        spine_month.month_start,
        'trust' as specialty,
        'cancer_fds_28day_pct' as metric,
        coalesce(fds_monthly.within_28d, 0) as numerator,
        coalesce(fds_monthly.referrals, 0) as denominator,
        cast(75.00 as decimal(14,2)) as target
    from spine_month
    left join fds_monthly
        on fds_monthly.month_start = spine_month.month_start
),

cancer_62day_monthly as (
    select
        date_trunc('month', cancer_episode.referred_at) as month_start,
        count(*) filter (
            cancer_episode.treatment_started_at is not null
            and cancer_episode.treatment_started_at <= cancer_episode.referred_at + interval 1488 hour
        ) as within_62d,
        count(*) as referrals
    from cancer_episode
    cross join activity_window
    where cancer_episode.referred_at <= activity_window.extract_end - interval 1488 hour
    group by 1
),

cancer_62day_rows as (
    select
        spine_month.month_start,
        'trust' as specialty,
        'cancer_62day_treatment_pct' as metric,
        coalesce(cancer_62day_monthly.within_62d, 0) as numerator,
        coalesce(cancer_62day_monthly.referrals, 0) as denominator,
        cast(null as decimal(14,2)) as target
    from spine_month
    left join cancer_62day_monthly
        on cancer_62day_monthly.month_start = spine_month.month_start
),

-- ------------------------------------------- 3. Diagnostic 6-week wait

-- Same shape as FDS: the clock is hours_from_order on the performed
-- milestone, six weeks is 1008 hours, ordered-never-performed stays in the
-- denominator, and the stated cutoff censors orders without a full window.
diagnostic_order as (
    select
        fact_diagnostics.episode_id,
        fact_diagnostics.occurred_at as ordered_at
    from fact_diagnostics
    cross join activity_window
    where fact_diagnostics.milestone = 'diagnostic_ordered'
      and fact_diagnostics.occurred_at <= activity_window.extract_end - interval 1008 hour
),

diagnostic_performed as (
    select
        episode_id,
        min(hours_from_order) as hours_to_performed
    from fact_diagnostics
    where milestone = 'diagnostic_performed'
    group by episode_id
),

dm01_monthly as (
    select
        date_trunc('month', diagnostic_order.ordered_at) as month_start,
        count(*) filter (diagnostic_performed.hours_to_performed <= 1008) as within_6w,
        count(*) as requests
    from diagnostic_order
    left join diagnostic_performed
        on diagnostic_performed.episode_id = diagnostic_order.episode_id
    group by 1
),

dm01_rows as (
    select
        spine_month.month_start,
        'trust' as specialty,
        'dm01_6week_pct' as metric,
        coalesce(dm01_monthly.within_6w, 0) as numerator,
        coalesce(dm01_monthly.requests, 0) as denominator,
        cast(99.00 as decimal(14,2)) as target
    from spine_month
    left join dm01_monthly
        on dm01_monthly.month_start = spine_month.month_start
),

-- ------------------------------------------- 4. 30-day readmission

-- The computed window, not the care system's recorded loop. Denominator:
-- discharges in the month with a full 30-day follow-up window (the stated
-- right-censoring cutoff — without it the last month's rate dips for no
-- clinical reason). Numerator: the same patient's next admission milestone
-- strictly after the discharge and within 30 days.
readmission_discharge as (
    select
        spell_attributed.episode_id,
        spell_attributed.patient_id,
        spell_attributed.specialty,
        spell_attributed.discharged_at
    from spell_attributed
    cross join activity_window
    where spell_attributed.discharged_at is not null
      and spell_attributed.discharged_at <= activity_window.extract_end - interval 30 day
),

readmission_monthly as (
    select
        date_trunc('month', discharged_at) as month_start,
        specialty,
        count(*) filter (
            exists (
                select 1
                from fact_admitted_care
                where fact_admitted_care.patient_id = readmission_discharge.patient_id
                  and fact_admitted_care.milestone = 'admission'
                  and fact_admitted_care.occurred_at > readmission_discharge.discharged_at
                  and fact_admitted_care.occurred_at <= readmission_discharge.discharged_at + interval 30 day
            )
        ) as readmitted,
        count(*) as discharges
    from readmission_discharge
    group by 1, 2
),

readmission_rows as (
    select
        spine_month.month_start,
        specialty_consultant.specialty,
        'readmission_30day_pct' as metric,
        coalesce(readmission_monthly.readmitted, 0) as numerator,
        coalesce(readmission_monthly.discharges, 0) as denominator,
        cast(null as decimal(14,2)) as target
    from spine_month
    cross join specialty_consultant
    left join readmission_monthly
        on readmission_monthly.month_start = spine_month.month_start
        and readmission_monthly.specialty = specialty_consultant.specialty
),

-- ------------------------------------------- 5. Crude mortality

-- Deaths in month over admissions in month — different cohorts, a crude
-- rate by design (the casemix stratification the SHMI discussion needs is
-- on dim_patient). Both sides carry the spell's admission-instant
-- attribution, so the two aggregates conform to one specialty surface.
mortality_death_monthly as (
    select
        date_trunc('month', died_at) as month_start,
        specialty,
        count(*) as deaths
    from spell_attributed
    where died_at is not null
    group by 1, 2
),

mortality_admission_monthly as (
    select
        date_trunc('month', admitted_at) as month_start,
        specialty,
        count(*) as admissions
    from spell_attributed
    where admitted_at is not null
    group by 1, 2
),

mortality_rows as (
    select
        spine_month.month_start,
        specialty_consultant.specialty,
        'mortality_pct' as metric,
        coalesce(mortality_death_monthly.deaths, 0) as numerator,
        coalesce(mortality_admission_monthly.admissions, 0) as denominator,
        cast(null as decimal(14,2)) as target
    from spine_month
    cross join specialty_consultant
    left join mortality_death_monthly
        on mortality_death_monthly.month_start = spine_month.month_start
        and mortality_death_monthly.specialty = specialty_consultant.specialty
    left join mortality_admission_monthly
        on mortality_admission_monthly.month_start = spine_month.month_start
        and mortality_admission_monthly.specialty = specialty_consultant.specialty
),

-- ------------------------------------------- 6. DTOC delay

-- Over spells discharged in the month that have a medically-fit instant:
-- the mean fit-to-discharge gap in days. The numerator carries total delay
-- days so the mean is a ratio of sums, reconstructible from the row.
dtoc_monthly as (
    select
        date_trunc('month', discharged_at) as month_start,
        specialty,
        sum(cast(date_diff('second', fit_at, discharged_at) as decimal(18,4)) / 86400) as delay_days,
        count(*) as delayed_spells
    from spell_attributed
    where discharged_at is not null
      and fit_at is not null
    group by 1, 2
),

dtoc_rows as (
    select
        spine_month.month_start,
        specialty_consultant.specialty,
        'dtoc_mean_days' as metric,
        coalesce(dtoc_monthly.delay_days, 0) as numerator,
        coalesce(dtoc_monthly.delayed_spells, 0) as denominator,
        cast(null as decimal(14,2)) as target
    from spine_month
    cross join specialty_consultant
    left join dtoc_monthly
        on dtoc_monthly.month_start = spine_month.month_start
        and dtoc_monthly.specialty = specialty_consultant.specialty
),

-- ------------------------------------------- 7. FFT recommend rate

-- Recorded outcomes only, no_response excluded from both sides — one of
-- three defensible denominators; the pinned one. Trust-level: the response
-- fact carries no episode or specialty surface.
fft_monthly as (
    select
        date_trunc('month', recorded_at) as month_start,
        count(*) filter (outcome in ('very_good', 'good')) as recommends,
        count(*) filter (outcome <> 'no_response') as responses
    from fact_fft_response
    group by 1
),

fft_rows as (
    select
        spine_month.month_start,
        'trust' as specialty,
        'fft_recommend_pct' as metric,
        coalesce(fft_monthly.recommends, 0) as numerator,
        coalesce(fft_monthly.responses, 0) as denominator,
        cast(null as decimal(14,2)) as target
    from spine_month
    left join fft_monthly
        on fft_monthly.month_start = spine_month.month_start
),

-- ------------------------------------------- 8. Bed occupancy

-- Occupied bed-days over available bed-days, per ward specialty. The
-- census is the conforming CTE above; the denominator is bed stock x days
-- in month summed over the specialty's wards (read from dim_ward, so a
-- recommissioned ward changes the denominator, not this query).
occupancy_monthly as (
    select
        ward_month.specialty,
        ward_month.month_start,
        sum(ward_month.occupied_days) as occupied_days
    from ward_month
    group by 1, 2
),

ward_capacity as (
    select
        main_specialty as specialty,
        sum(total_beds) as total_beds
    from dim_ward
    group by 1
),

occupancy_rows as (
    select
        spine_month.month_start,
        specialty_ward.specialty,
        'bed_occupancy_pct' as metric,
        coalesce(occupancy_monthly.occupied_days, 0) as numerator,
        ward_capacity.total_beds * spine_month.days_in_month as denominator,
        cast(85.00 as decimal(14,2)) as target
    from spine_month
    cross join specialty_ward
    join ward_capacity
        on ward_capacity.specialty = specialty_ward.specialty
    left join occupancy_monthly
        on occupancy_monthly.month_start = spine_month.month_start
        and occupancy_monthly.specialty = specialty_ward.specialty
),

-- ------------------------------------------- 9. Theatre utilisation

-- Sessions used over sessions available, per theatre specialty. The ratio
-- is monthly sums over monthly sums — averaging per-day ratios would skip
-- the days no session ran and flatter every theatre.
theatre_monthly as (
    select
        dim_theatre.theatre_specialty as specialty,
        date_trunc('month', fact_theatre_session.used_at) as month_start,
        count(*) as sessions_used
    from fact_theatre_session
    join dim_theatre
        on dim_theatre.theatre_id = fact_theatre_session.theatre_id
    group by 1, 2
),

theatre_capacity as (
    select
        theatre_specialty as specialty,
        sum(sessions_per_day) as sessions_per_day
    from dim_theatre
    group by 1
),

theatre_rows as (
    select
        spine_month.month_start,
        specialty_theatre.specialty,
        'theatre_utilisation_pct' as metric,
        coalesce(theatre_monthly.sessions_used, 0) as numerator,
        theatre_capacity.sessions_per_day * spine_month.days_in_month as denominator,
        cast(null as decimal(14,2)) as target
    from spine_month
    cross join specialty_theatre
    join theatre_capacity
        on theatre_capacity.specialty = specialty_theatre.specialty
    left join theatre_monthly
        on theatre_monthly.month_start = spine_month.month_start
        and theatre_monthly.specialty = specialty_theatre.specialty
),

-- ------------------------------------------- 10. Casemix income

-- Tariff x procedures performed. The catalogue binds each operation twice
-- (planned and performed); keeping milestone = 'surgery_performed' is what
-- stops the income double-counting. The tariff is DOUBLE in the catalogue;
-- it is cast to money at this boundary and never summed as a float.
performed_procedure as (
    select
        fact_surgical_pathway.occurred_at as performed_at,
        dim_procedure.main_specialty as specialty,
        cast(dim_procedure.tariff as decimal(12,2)) as tariff
    from fact_procedure
    join fact_surgical_pathway
        on fact_surgical_pathway.event_id = fact_procedure.event_id
        and fact_surgical_pathway.milestone = 'surgery_performed'
    join dim_procedure
        on dim_procedure.procedure_id = fact_procedure.procedure_id
),

income_monthly as (
    select
        date_trunc('month', performed_at) as month_start,
        specialty,
        sum(tariff) as income,
        count(*) as procedures
    from performed_procedure
    group by 1, 2
),

income_rows as (
    select
        spine_month.month_start,
        specialty_procedure.specialty,
        'casemix_income_gbp' as metric,
        coalesce(income_monthly.income, 0) as numerator,
        coalesce(income_monthly.procedures, 0) as denominator,
        cast(null as decimal(14,2)) as target
    from spine_month
    cross join specialty_procedure
    left join income_monthly
        on income_monthly.month_start = spine_month.month_start
        and income_monthly.specialty = specialty_procedure.specialty
),

-- ------------------------------------------- 11. Bed-day cost

-- The same census as occupancy, priced: occupied bed-days x the ward's
-- daily cost. cost_per_bed_day is DOUBLE in the catalogue; cast at the
-- boundary, per ward, before the multiply.
bed_cost_monthly as (
    select
        ward_month.specialty,
        ward_month.month_start,
        sum(ward_month.occupied_days * cast(ward_month.cost_per_bed_day as decimal(12,2))) as cost,
        sum(ward_month.occupied_days) as occupied_days
    from ward_month
    group by 1, 2
),

bed_cost_rows as (
    select
        spine_month.month_start,
        specialty_ward.specialty,
        'bed_day_cost_gbp' as metric,
        coalesce(bed_cost_monthly.cost, 0) as numerator,
        coalesce(bed_cost_monthly.occupied_days, 0) as denominator,
        cast(null as decimal(14,2)) as target
    from spine_month
    cross join specialty_ward
    left join bed_cost_monthly
        on bed_cost_monthly.month_start = spine_month.month_start
        and bed_cost_monthly.specialty = specialty_ward.specialty
),

-- ------------------------------------------- 12. Outpatient DNA x IMD

-- Every outpatient episode resolving this month (attended or DNA), with
-- the patient's IMD quintile as of the appointment instant. The decile is
-- constant per patient, but it is read through the same instant-grain
-- as-of join as any other patient attribute: the event timestamp against
-- [valid_from, valid_to) — never the valid_to IS NULL version, and never
-- a day-grain join through the *_date_key columns (12,693 patient-days
-- carry more than one version; day-grain joins fan out).
outpatient_resolution as (
    select
        fact_outpatient.patient_id,
        fact_outpatient.milestone,
        fact_outpatient.occurred_at
    from fact_outpatient
    where fact_outpatient.milestone in ('appointment_attended', 'appointment_dna')
),

outpatient_quintile as (
    select
        outpatient_resolution.milestone,
        outpatient_resolution.occurred_at,
        cast(ceil(cast(dim_patient.imd_decile as integer) / 2.0) as integer) as imd_quintile
    from outpatient_resolution
    join dim_patient
        on dim_patient.patient_id = outpatient_resolution.patient_id
        and dim_patient.valid_from <= outpatient_resolution.occurred_at
        and (dim_patient.valid_to is null or dim_patient.valid_to > outpatient_resolution.occurred_at)
),

dna_monthly as (
    select
        date_trunc('month', occurred_at) as month_start,
        imd_quintile,
        count(*) filter (milestone = 'appointment_dna') as dnas,
        count(*) as resolutions
    from outpatient_quintile
    group by 1, 2
),

imd_quintile_domain as (
    select unnest(generate_series(1, 5)) as imd_quintile
),

dna_rows as (
    select
        spine_month.month_start,
        'trust' as specialty,
        'outpatient_dna_pct_imd_q' || imd_quintile_domain.imd_quintile as metric,
        coalesce(dna_monthly.dnas, 0) as numerator,
        coalesce(dna_monthly.resolutions, 0) as denominator,
        cast(null as decimal(14,2)) as target
    from spine_month
    cross join imd_quintile_domain
    left join dna_monthly
        on dna_monthly.month_start = spine_month.month_start
        and dna_monthly.imd_quintile = imd_quintile_domain.imd_quintile
),

-- ============================================================ spine assembly

-- Every family on the common shape. The pack is dense by construction:
-- each family cross-joined its spine months with its specialty domain
-- before its aggregate was left-joined on, so this union never loses a
-- quiet month.
assembled as (
    select month_start, specialty, metric, numerator, denominator, target, 'pct'  as shape from ae_rows
    union all
    select month_start, specialty, metric, numerator, denominator, target, 'pct'  as shape from cancer_2ww_rows
    union all
    select month_start, specialty, metric, numerator, denominator, target, 'pct'  as shape from fds_rows
    union all
    select month_start, specialty, metric, numerator, denominator, target, 'pct'  as shape from cancer_62day_rows
    union all
    select month_start, specialty, metric, numerator, denominator, target, 'pct'  as shape from dm01_rows
    union all
    select month_start, specialty, metric, numerator, denominator, target, 'pct'  as shape from readmission_rows
    union all
    select month_start, specialty, metric, numerator, denominator, target, 'pct'  as shape from mortality_rows
    union all
    select month_start, specialty, metric, numerator, denominator, target, 'mean' as shape from dtoc_rows
    union all
    select month_start, specialty, metric, numerator, denominator, target, 'pct'  as shape from fft_rows
    union all
    select month_start, specialty, metric, numerator, denominator, target, 'pct'  as shape from occupancy_rows
    union all
    select month_start, specialty, metric, numerator, denominator, target, 'pct'  as shape from theatre_rows
    union all
    select month_start, specialty, metric, numerator, denominator, target, 'sum'  as shape from income_rows
    union all
    select month_start, specialty, metric, numerator, denominator, target, 'sum'  as shape from bed_cost_rows
    union all
    select month_start, specialty, metric, numerator, denominator, target, 'pct'  as shape from dna_rows
)

-- ============================================================ presentation

-- The one place anything is rounded. A pct-shaped metric reads
-- 100 x numerator / denominator; a mean reads numerator / denominator; a
-- sum-shaped (money) metric's value is its numerator. value is NULL when
-- the denominator is 0 — a quiet cell, not a zero rate.
select
    month_start as month,
    specialty,
    metric,
    cast(numerator as decimal(18,4)) as numerator,
    cast(denominator as decimal(18,4)) as denominator,
    cast(round(
        case
            when denominator = 0 then null
            when shape = 'pct'  then 100 * cast(numerator as decimal(28,10)) / denominator
            when shape = 'mean' then cast(numerator as decimal(28,10)) / denominator
            else numerator
        end,
    2) as decimal(14,2)) as value,
    target
from assembled
order by month, metric, specialty
