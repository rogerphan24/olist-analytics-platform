{{ config(materialized='table') }}

-- Purchase date is not a payment event date. Shares are within date/status.
with totals as (
    select
        o.purchase_date_key,
        o.order_status,
        p.payment_type,
        count(*) as payment_record_count,
        count(distinct p.order_id) as orders_with_payment_records,
        sum(p.payment_value) as recorded_payment_value,
        countif(p.payment_value is null) as payments_missing_value,
        countif(p.payment_type = 'credit_card' and p.payment_installments >= 1)
            as credit_card_records_with_valid_installments,
        sum(if(p.payment_type = 'credit_card' and p.payment_installments >= 1,
            p.payment_installments, null)) as total_credit_card_installments,
        countif(p.payment_type = 'credit_card'
            and (p.payment_installments is null or p.payment_installments < 1))
            as credit_card_records_with_invalid_installments
    from {{ ref('fact_order_payments') }} as p
    left join {{ ref('fact_orders') }} as o using (order_id)
    group by 1, 2, 3
)
select
    t.*,
    d.calendar_date as purchase_date,
    safe_divide(recorded_payment_value,
        sum(recorded_payment_value) over (partition by t.purchase_date_key, order_status))
        as payment_method_value_share,
    safe_divide(total_credit_card_installments,
        credit_card_records_with_valid_installments) as average_credit_card_installments
from totals as t
left join {{ ref('dim_date') }} as d on t.purchase_date_key = d.date_key
