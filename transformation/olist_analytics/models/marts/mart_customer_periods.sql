{{ config(materialized='table') }}

-- Never sum distinct customers across periods or period types.
with bounds as (
    select min(purchase_date) as dataset_start, max(purchase_date) as dataset_end
    from {{ ref('mart_customer_daily') }}
),
expanded as (
    select c.*, period_type,
        case period_type
            when 'day' then purchase_date
            when 'month' then date_trunc(purchase_date, month)
            when 'year' then date_trunc(purchase_date, year)
            else b.dataset_start end as period_start,
        case period_type
            when 'day' then purchase_date
            when 'month' then last_day(purchase_date, month)
            when 'year' then last_day(purchase_date, year)
            else b.dataset_end end as period_end
    from {{ ref('mart_customer_daily') }} as c
    cross join bounds as b
    cross join unnest(['day', 'month', 'year', 'dataset']) as period_type
),
customer_totals as (
    select period_type, period_start, period_end, customer_unique_id,
        sum(orders_placed) as orders_placed,
        sum(delivered_orders) as delivered_orders,
        min(first_observed_delivered_purchase_date) as first_delivered_date
    from expanded
    group by 1, 2, 3, 4
),
totals as (
    select period_type, period_start, period_end,
        sum(orders_placed) as orders_placed,
        sum(delivered_orders) as delivered_orders,
        count(*) as purchasing_customers,
        countif(delivered_orders > 0) as delivered_purchasing_customers,
        countif(delivered_orders >= 2) as repeat_delivered_purchasing_customers,
        countif(first_delivered_date between period_start and period_end)
            as first_observed_delivered_purchasing_customers
    from customer_totals
    group by 1, 2, 3
)
select *,
    safe_divide(delivered_orders, delivered_purchasing_customers)
        as delivered_orders_per_purchasing_customer,
    safe_divide(repeat_delivered_purchasing_customers, delivered_purchasing_customers)
        as repeat_delivered_purchasing_customer_rate
from totals
