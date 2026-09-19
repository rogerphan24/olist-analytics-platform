{{config(materialized='view')}}

SELECT
    NULLIF(order_id, '') as order_id,
    NULLIF(customer_id, '') as customer_id,
    nullif(lower(trim(order_status)), '') as order_status,
    CAST(order_purchase_timestamp as TIMESTAMP) as order_purchase_timestamp,
    CAST(order_approved_at as TIMESTAMP) as order_approved_at,
    CAST(order_delivered_carrier_date as TIMESTAMP) as order_delivered_carrier_date,
    CAST(order_delivered_customer_date as TIMESTAMP) as order_delivered_customer_date,
    CAST(order_estimated_delivery_date as TIMESTAMP) as order_estimated_delivery_date

FROM {{source('olist','orders')}}