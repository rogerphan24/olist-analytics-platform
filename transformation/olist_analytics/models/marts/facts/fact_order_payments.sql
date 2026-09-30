{{ config(materialized='table') }}

-- Payment value is the amount for the record, not an installment amount.
-- The source has no payment timestamp; purchase_date_key is an order date.
select
    p.order_id,
    p.payment_sequential,
    o.customer_id,
    cast(format_date('%Y%m%d', date(o.order_purchase_timestamp)) as int64)
        as purchase_date_key,
    p.payment_type,
    p.payment_installments,
    p.payment_value,
    1 as payment_record_count
from {{ ref('stg_order_payments') }} as p
left join {{ ref('stg_orders') }} as o using (order_id)
