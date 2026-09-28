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

expected_dates as (
    select calendar_date
    from (
        select
            date_trunc(min(calendar_date), year) as start_date,
            last_day(max(calendar_date), year) as end_date
        from order_dates
    )
    cross join unnest(
        generate_date_array(start_date, end_date)
    ) as calendar_date
)

select e.calendar_date
from expected_dates as e
left join {{ ref('dim_date') }} as d
    on e.calendar_date = d.calendar_date
where d.calendar_date is null
