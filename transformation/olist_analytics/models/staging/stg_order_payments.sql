{{config(materialized='view')}}

SELECT
    NULLIF(TRIM(order_id),'') as order_id,
    CAST(NULLIF(TRIM(payment_sequential),'') as int) as payment_sequential,
    NULLIF(LOWER(TRIM(payment_type)),'') as payment_type,
    CAST(NULLIF(TRIM(payment_installments),'') as int) as payment_installments,
    CAST(NULLIF(TRIM(payment_value),'') as NUMERIC) as payment_value

FROM {{ source('olist', 'order_payments') }}