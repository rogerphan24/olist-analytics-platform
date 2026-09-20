{{config(materialized='view')}}

SELECT
    NULLIF(trim(order_id), '') as order_id,
    NULLIF(trim(customer_id), '') as customer_id,
    nullif(lower(trim(order_status)), '') as order_status,
    CAST(NULLIF(trim(order_purchase_timestamp), '') as DATETIME) as order_purchase_timestamp,
    CAST(NULLIF(trim(order_approved_at), '') as DATETIME) as order_approved_at,
    CAST(NULLIF(trim(order_delivered_carrier_date), '') as DATETIME) as order_delivered_carrier_date,
    CAST(NULLIF(trim(order_delivered_customer_date), '') as DATETIME) as order_delivered_customer_date,
    CAST(NULLIF(trim(order_estimated_delivery_date), '') as DATETIME) as order_estimated_delivery_date

FROM {{source('olist','orders')}}
