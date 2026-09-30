{{config(materialized='table')}}


WITH item_totals AS(
    SELECT
        order_id,
        COUNT(*) AS item_count,
        SUM(price) AS merchandise_value,
        SUM(freight_value) AS freight_value
    FROM {{ref('stg_order_items')}}
    GROUP BY order_id
)

select
    o.order_id,
    o.customer_id,
    o.order_status,

    cast(format_date(
        '%Y%m%d', date(o.order_purchase_timestamp)
    ) as int64) as purchase_date_key,

    cast(format_date(
        '%Y%m%d', date(o.order_approved_at)
    ) as int64) as approved_date_key,

    cast(format_date(
        '%Y%m%d', date(o.order_delivered_carrier_date)
    ) as int64) as carrier_delivery_date_key,

    cast(format_date(
        '%Y%m%d', date(o.order_delivered_customer_date)
    ) as int64) as customer_delivery_date_key,

    cast(format_date(
        '%Y%m%d', date(o.order_estimated_delivery_date)
    ) as int64) as estimated_delivery_date_key,

    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    1 as order_count,
    coalesce(i.item_count, 0) as item_count,
    i.merchandise_value,
    i.freight_value,
    i.merchandise_value + i.freight_value as order_total_value,

    date_diff(
        date(o.order_delivered_customer_date),
        date(o.order_purchase_timestamp),
        day
    ) as delivery_days,

    date_diff(
        date(o.order_delivered_customer_date),
        date(o.order_estimated_delivery_date),
        day
    ) as delivery_delay_days,

    date(o.order_delivered_customer_date)
        > date(o.order_estimated_delivery_date) as is_delivered_late

from {{ ref('stg_orders') }} as o
left join item_totals as i
    on o.order_id = i.order_id
