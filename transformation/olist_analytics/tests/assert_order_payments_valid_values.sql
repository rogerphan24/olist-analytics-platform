SELECT
    order_id,
    payment_sequential,
    payment_installments,
    payment_value
FROM {{ ref('stg_order_payments') }}

WHERE payment_sequential < 1
OR payment_installments < 0
OR payment_value < 0
