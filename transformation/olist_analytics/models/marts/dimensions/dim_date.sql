{{ config(materialized='table') }}

with order_dates as (
    select date(order_purchase_timestamp) as calendar_date
    from {{ ref('stg_orders') }}

    union all

    select date(order_approved_at)
    from {{ ref('stg_orders') }}

    union all

    select date(order_delivered_carrier_date)
    from {{ ref('stg_orders') }}

    union all

    select date(order_delivered_customer_date)
    from {{ ref('stg_orders') }}

    union all

    select date(order_estimated_delivery_date)
    from {{ ref('stg_orders') }}

    union all

    select date(shipping_limit_date)
    from {{ ref('stg_order_items') }}

    union all

    select date(review_creation_date)
    from {{ ref('stg_order_reviews') }}

    union all

    select date(review_answer_timestamp)
    from {{ ref('stg_order_reviews') }}
),

date_bounds as (
    select
        date_trunc(min(calendar_date), year) as start_date,
        last_day(max(calendar_date), year) as end_date
    from order_dates
),

date_spine as (
    select calendar_date
    from date_bounds
    cross join unnest(
        generate_date_array(start_date, end_date)
    ) as calendar_date
)

select
    cast(format_date('%Y%m%d', calendar_date) as int64) as date_key,
    calendar_date,
    extract(year from calendar_date) as calendar_year,
    extract(quarter from calendar_date) as calendar_quarter,
    extract(month from calendar_date) as month_number,
    format_date('%B', calendar_date) as month_name,
    date_trunc(calendar_date, month) as month_start_date,
    extract(day from calendar_date) as day_of_month,
    mod(extract(dayofweek from calendar_date) + 5, 7) + 1
        as day_of_week_number,
    format_date('%A', calendar_date) as day_name,
    extract(dayofweek from calendar_date) in (1, 7) as is_weekend,
    extract(isoyear from calendar_date) as iso_year,
    extract(isoweek from calendar_date) as iso_week
from date_spine
