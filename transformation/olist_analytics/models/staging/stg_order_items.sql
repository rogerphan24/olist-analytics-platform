{{config(materialized='view')}}

SELECT
    NULLIF(trim(order_id, ''),'') as order_id,
    CAST(NULLIF(trim(order_item_id, ''),'') as int) as order_item_id,
    NULLIF(trim(product_id, ''),'') as product_id,
    NULLIF(trim(seller_id, ''),'') as seller_id,
    CAST(NULLIF(trim(shipping_limit_date, ''),'') as datetime) as shipping_limit_date,
    CAST(NULLIF(trim(price, ''),'') as NUMERIC) as price,
    CAST(NULLIF(trim(freight_value, ''),'') as NUMERIC) as freight_value

FROM {{ source('olist', 'order_items') }} 