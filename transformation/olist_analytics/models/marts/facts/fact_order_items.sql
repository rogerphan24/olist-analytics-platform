{{config(materialized='table')}}

SELECT
    i.order_id,
    i.order_item_id,
    i.product_id,
    i.seller_id,
    ord.customer_id,
    CAST(
        format_date('%Y%m%d', date(ord.order_purchase_timestamp))
        AS int64
    ) AS purchase_date_key,
    CAST(
        format_date('%Y%m%d', date(i.shipping_limit_date))
        AS int64
    ) AS shipping_limit_date_key,
    ord.order_purchase_timestamp,
    i.shipping_limit_date,
    ord.order_status,

    1 as item_quantity,
    i.price as item_price,
    i.freight_value,
    i.price + i.freight_value as item_total_value


FROM {{ref('stg_order_items')}} as i
LEFT JOIN {{ref('stg_orders')}} as ord
ON i.order_id = ord.order_id