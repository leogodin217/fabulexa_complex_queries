-- Monthly seat bill per company — the reference (clean) form, beginner tier.
-- Conventions: ../CONVENTIONS.md (stages 1, 2 and 8). Runs against datasets/saas-billing/warehouse.duckdb.
-- The same CTEs as the advanced reference, cut after the seat and add-on
-- stages. The `materialized` hints stop DuckDB re-planning a wide CTE once
-- per consumer; they change nothing about the result.

with

-- ---------------------------------------------------------------- calendar

-- One row per calendar month, straight from the warehouse calendar. Nothing
-- about the month spine is generated in the query: days_in_month is a row
-- count and next_month_start is the day after the month's last row.
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

-- Each day's month, keyed the way the facts key their dates (date_key), so a
-- fact lands in its billing month without any date arithmetic.
calendar_day as (
    select
        dim_date.date_key,
        dim_date.date,
        calendar.month_start
    from dim_date
    join calendar
        on calendar.year = dim_date.year
        and calendar.month = dim_date.month
),

-- The extract ends in the month of the last lifecycle transition. Read from
-- the data so the query never carries a hardcoded end date.
extract_end as (
    select max(calendar_day.month_start) as last_month
    from fact_lifecycle_interval as lifecycle
    join calendar_day
        on calendar_day.date_key = lifecycle.started_date_key
),

-- ---------------------------------------------------------------- accounts

-- One row per account with its plan terms and its billing span: from the
-- month it was provisioned through its churn month (the first dim_company
-- version in status 'churned'), or the end of the extract if it never
-- churned. The outer least() also clips a churn recorded after the extract.
account as (
    select
        dim_account.account_id,
        dim_account.company_id,
        dim_account.created_at,
        dim_account.addon_sso,
        dim_account.addon_support,
        dim_plan_terms.trial_days,
        dim_plan_terms.included_units_per_seat,
        dim_plan_terms.credit_validity_days,
        calendar_day.month_start as first_month,
        least(
            coalesce(
                (
                    select min(churn_day.month_start)
                    from dim_company
                    join calendar_day as churn_day
                        on churn_day.date = dim_company.valid_from
                    where
                        dim_company.company_id = dim_account.company_id
                        and dim_company.status = 'churned'
                ),
                extract_end.last_month
            ),
            extract_end.last_month
        ) as last_month
    from dim_account
    join dim_plan_terms
        on dim_plan_terms.tier = dim_account.plan
    join calendar_day
        on calendar_day.date_key = dim_account.created_date_key
    cross join extract_end
),

-- Every (account, month) the account is billed for. This is the spine every
-- later stage hangs off, so a month with no seats, no usage and no credits
-- still gets an invoice row.
billing_month as materialized (
    select
        account.account_id,
        calendar.month_start,
        calendar.next_month_start,
        calendar.days_in_month
    from account
    join calendar
        on calendar.month_start between account.first_month and account.last_month
),

-- The account's negotiated terms as of month end: the SCD-2 version whose
-- window contains the last instant of the month. valid_to is exclusive, so a
-- version whose valid_to equals next_month_start is still the one in force.
terms_as_of as materialized (
    select
        billing_month.account_id,
        billing_month.month_start,
        terms.seat_price,
        terms.pct_of_list_rate,
        terms.term_commit,
        terms.allowance_override
    from billing_month
    join dim_account_terms as terms
        on terms.account_id = billing_month.account_id
        and terms.valid_from < cast(billing_month.next_month_start as timestamp)
        and (
            terms.valid_to is null
            or terms.valid_to >= cast(billing_month.next_month_start as timestamp)
        )
),

-- ---------------------------------------------------------------- 1-2 seats

-- Prorated seats: for every seat interval in state active or using that
-- overlaps the month, the days that fall inside the month, summed and
-- divided by the days in the month. Rounded to 6 decimals — the one
-- intermediate rounding the conventions allow. An account with no live seat
-- this month has no row here; seat_charge fills in the zero.
billable_seats as (
    select
        billing_month.account_id,
        billing_month.month_start,
        cast(round(
            sum(date_diff(
                'day',
                greatest(seat.valid_from, billing_month.month_start),
                least(coalesce(seat.valid_to, billing_month.next_month_start), billing_month.next_month_start)
            )) / billing_month.days_in_month,
            6
        ) as decimal(12,6)) as seats
    from billing_month
    join dim_user
        on dim_user.account_id = billing_month.account_id
    join dim_user_status as seat
        on seat.user_id = dim_user.user_id
        and seat.status in ('active', 'using')
        and seat.valid_from < billing_month.next_month_start
        and (seat.valid_to is null or seat.valid_to > billing_month.month_start)
    group by billing_month.account_id, billing_month.month_start, billing_month.days_in_month
),

-- Seats × the seat price in force at month end. Carried at full precision;
-- every line is rounded once, in the final select.
seat_charge as materialized (
    select
        billing_month.account_id,
        billing_month.month_start,
        coalesce(billable_seats.seats, 0) as seats,
        cast(coalesce(billable_seats.seats, 0) * terms_as_of.seat_price as decimal(28,14)) as seat_charge
    from billing_month
    join terms_as_of
        on terms_as_of.account_id = billing_month.account_id
        and terms_as_of.month_start = billing_month.month_start
    left join billable_seats
        on billable_seats.account_id = billing_month.account_id
        and billable_seats.month_start = billing_month.month_start
),

-- ---------------------------------------------------------------- 8 add-ons

-- Flat monthly fees for the add-ons the account subscribes to. Never
-- prorated, never drawn from a commit. The fees are read from dim_sku by
-- name, not hardcoded.
addon_charge as (
    select
        billing_month.account_id,
        billing_month.month_start,
        cast(
            case when account.addon_sso = 'yes' then sso.flat_fee else 0 end
            + case when account.addon_support = 'yes' then support.flat_fee else 0 end
        as decimal(28,14)) as addon_charge
    from billing_month
    join account
        on account.account_id = billing_month.account_id
    cross join (select flat_fee from dim_sku where name = 'SSO') as sso
    cross join (select flat_fee from dim_sku where name = 'Premium Support') as support
)

-- ---------------------------------------------------------------- the bill

-- Each line is rounded exactly once, here. total_due is the sum of the
-- rounded lines, so the printed total always equals the printed lines.
select
    company_id,
    billing_month,
    seat_charge,
    addon_charge,
    cast(seat_charge + addon_charge as decimal(12,2)) as total_due
from (
    select
        account.company_id,
        seat_charge.month_start as billing_month,
        cast(round(seat_charge.seat_charge, 2) as decimal(12,2)) as seat_charge,
        cast(round(addon_charge.addon_charge, 2) as decimal(12,2)) as addon_charge
    from seat_charge
    join account
        on account.account_id = seat_charge.account_id
    join addon_charge
        on addon_charge.account_id = seat_charge.account_id
        and addon_charge.month_start = seat_charge.month_start
) as rounded_lines
order by company_id, billing_month
