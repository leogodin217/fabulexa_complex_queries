-- Monthly usage bill per company — the reference (clean) form, intermediate tier.
-- Conventions: ../CONVENTIONS.md (stages 1-8). Runs against datasets/saas-billing/warehouse.duckdb.
-- The same CTEs as the advanced reference, cut before the commit and credit
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

-- ---------------------------------------------------------------- 3-4 usage

-- Metered volume per account, SKU and month, with the free volume already
-- removed: sessions inside the account's trial window, and sessions on a SKU
-- while a free_usage promotion is running for it. Volume lives in the
-- event's JSON context, not in a column — cast at the boundary so every
-- later step stays decimal.
metered_usage as (
    select
        dim_user.account_id,
        calendar_day.month_start,
        usage_event.sku_id,
        cast(sum(cast(json_extract_string(usage_event.context, '$.volume') as decimal(14,2))) as decimal(18,6)) as volume
    from fact_usage_event as usage_event
    join calendar_day
        on calendar_day.date_key = usage_event.occurred_date_key
    join dim_user
        on dim_user.user_id = usage_event.user_id
    join dim_sku
        on dim_sku.sku_id = usage_event.sku_id
        and dim_sku.billing_model = 'metered'
    join account
        on account.account_id = dim_user.account_id
    where
        usage_event.occurred_at >= account.created_at + account.trial_days * interval 1 day
        and not exists (
            select 1
            from dim_promotion
            where
                dim_promotion.sku_id = usage_event.sku_id
                and dim_promotion.kind = 'free_usage'
                and dim_promotion.starts_at <= usage_event.occurred_at
                and (dim_promotion.ends_at is null or usage_event.occurred_at < dim_promotion.ends_at)
        )
    group by dim_user.account_id, calendar_day.month_start, usage_event.sku_id
),

-- ---------------------------------------------------------------- 5 allowance

-- The plan's included Core units per seat — or the account's negotiated
-- override, as of month end — times this month's billable seats comes off
-- Core volume, never below zero. Other SKUs pass through untouched. The join
-- to terms_as_of also drops usage outside the account's billed months (seats
-- still running while the company offboards), since it is built on
-- billing_month.
net_usage as materialized (
    select
        metered_usage.account_id,
        metered_usage.month_start,
        metered_usage.sku_id,
        cast(
            case
                when dim_sku.name = 'Core'
                then greatest(
                    0,
                    metered_usage.volume
                        - seat_charge.seats * coalesce(terms_as_of.allowance_override, account.included_units_per_seat)
                )
                else metered_usage.volume
            end
        as decimal(18,6)) as net_volume
    from metered_usage
    join dim_sku
        on dim_sku.sku_id = metered_usage.sku_id
    join account
        on account.account_id = metered_usage.account_id
    join terms_as_of
        on terms_as_of.account_id = metered_usage.account_id
        and terms_as_of.month_start = metered_usage.month_start
    join seat_charge
        on seat_charge.account_id = metered_usage.account_id
        and seat_charge.month_start = metered_usage.month_start
),

-- ---------------------------------------------------------------- 6-7 rating

-- The ladder in force for each (account, SKU, month), one row per band:
-- the account's own custom_tier bands when any are effective at month end,
-- else the SKU's published dim_rate_tier bands, else one open band at list
-- rate (Workflow — a SKU with no ladder at all). custom_tier windows are
-- dates, inclusive at both ends, so they are tested against the month's
-- last day; dim_rate_tier windows are timestamps and use the SCD-2 rule.
ladder as materialized (
    select
        net_usage.account_id,
        net_usage.month_start,
        net_usage.sku_id,
        custom_tier.from_units,
        custom_tier.to_units,
        cast(custom_tier.rate as decimal(10,6)) as rate,
        custom_tier.pct_of_list
    from net_usage
    join billing_month
        on billing_month.account_id = net_usage.account_id
        and billing_month.month_start = net_usage.month_start
    join custom_tier
        on custom_tier.account_id = net_usage.account_id
        and custom_tier.sku_id = net_usage.sku_id
        and custom_tier.effective_from <= billing_month.next_month_start - interval 1 day
        and (
            custom_tier.effective_to is null
            or custom_tier.effective_to >= billing_month.next_month_start - interval 1 day
        )

    union all

    select
        net_usage.account_id,
        net_usage.month_start,
        net_usage.sku_id,
        rate_tier.from_units,
        rate_tier.to_units,
        cast(rate_tier.rate as decimal(10,6)),
        null
    from net_usage
    join billing_month
        on billing_month.account_id = net_usage.account_id
        and billing_month.month_start = net_usage.month_start
    join dim_rate_tier as rate_tier
        on rate_tier.sku_id = net_usage.sku_id
        and rate_tier.effective_from < cast(billing_month.next_month_start as timestamp)
        and (
            rate_tier.effective_to is null
            or rate_tier.effective_to >= cast(billing_month.next_month_start as timestamp)
        )
    where not exists (
        select 1
        from custom_tier
        where
            custom_tier.account_id = net_usage.account_id
            and custom_tier.sku_id = net_usage.sku_id
            and custom_tier.effective_from <= billing_month.next_month_start - interval 1 day
            and (
                custom_tier.effective_to is null
                or custom_tier.effective_to >= billing_month.next_month_start - interval 1 day
            )
    )

    union all

    select
        net_usage.account_id,
        net_usage.month_start,
        net_usage.sku_id,
        0,
        null,
        cast(dim_sku.standard_rate as decimal(10,6)),
        null
    from net_usage
    join billing_month
        on billing_month.account_id = net_usage.account_id
        and billing_month.month_start = net_usage.month_start
    join dim_sku
        on dim_sku.sku_id = net_usage.sku_id
    where
        not exists (
            select 1
            from custom_tier
            where
                custom_tier.account_id = net_usage.account_id
                and custom_tier.sku_id = net_usage.sku_id
                and custom_tier.effective_from <= billing_month.next_month_start - interval 1 day
                and (
                    custom_tier.effective_to is null
                    or custom_tier.effective_to >= billing_month.next_month_start - interval 1 day
                )
        )
        and not exists (
            select 1
            from dim_rate_tier as rate_tier
            where
                rate_tier.sku_id = net_usage.sku_id
                and rate_tier.effective_from < cast(billing_month.next_month_start as timestamp)
                and (
                    rate_tier.effective_to is null
                    or rate_tier.effective_to >= cast(billing_month.next_month_start as timestamp)
                )
        )
),

-- Units in each band × the band's unit price, summed per (account, SKU,
-- month). Bands are continuous with an inclusive top, so a band holds
-- least(net_volume, to_units) − (from_units − 1) units; a null to_units is
-- open-ended. A custom band priced as pct_of_list is units × list × pct and
-- is not discounted again; every other band is multiplied by the account's
-- negotiated pct_of_list_rate (stage 7). Volume no band covers is not rated.
rated_usage as (
    select
        net_usage.account_id,
        net_usage.month_start,
        net_usage.sku_id,
        cast(sum(
            cast(
                greatest(
                    0,
                    least(net_usage.net_volume, coalesce(ladder.to_units, net_usage.net_volume))
                        - greatest(ladder.from_units - 1, 0)
                )
            as decimal(18,6))
            * cast(
                case
                    when ladder.pct_of_list is not null
                    then cast(dim_sku.standard_rate as decimal(10,6)) * ladder.pct_of_list * 0.01
                    else ladder.rate * terms_as_of.pct_of_list_rate * 0.01
                end
            as decimal(14,8))
        ) as decimal(28,14)) as amount
    from net_usage
    join ladder
        on ladder.account_id = net_usage.account_id
        and ladder.month_start = net_usage.month_start
        and ladder.sku_id = net_usage.sku_id
    join dim_sku
        on dim_sku.sku_id = net_usage.sku_id
    join terms_as_of
        on terms_as_of.account_id = net_usage.account_id
        and terms_as_of.month_start = net_usage.month_start
    group by net_usage.account_id, net_usage.month_start, net_usage.sku_id
),

-- Rated usage rolled up across SKUs to the invoice line.
usage_charge as materialized (
    select
        account_id,
        month_start,
        cast(sum(amount) as decimal(28,14)) as usage_charge
    from rated_usage
    group by account_id, month_start
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
    usage_charge,
    addon_charge,
    cast(seat_charge + usage_charge + addon_charge as decimal(12,2)) as total_due
from (
    select
        account.company_id,
        seat_charge.month_start as billing_month,
        cast(round(seat_charge.seat_charge, 2) as decimal(12,2)) as seat_charge,
        cast(round(coalesce(usage_charge.usage_charge, 0), 2) as decimal(12,2)) as usage_charge,
        cast(round(addon_charge.addon_charge, 2) as decimal(12,2)) as addon_charge
    from seat_charge
    join account
        on account.account_id = seat_charge.account_id
    left join usage_charge
        on usage_charge.account_id = seat_charge.account_id
        and usage_charge.month_start = seat_charge.month_start
    join addon_charge
        on addon_charge.account_id = seat_charge.account_id
        and addon_charge.month_start = seat_charge.month_start
) as rounded_lines
order by company_id, billing_month
