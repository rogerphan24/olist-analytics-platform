SELECT
    order_id,
    order_item_id,
    price,
    freight_value
FROM {{ ref('stg_order_items') }}

WHERE order_item_id < 1
    OR price < 0
    OR freight_value < 0

