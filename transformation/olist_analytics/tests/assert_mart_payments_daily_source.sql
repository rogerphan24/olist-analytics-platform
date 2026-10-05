-- Recompute expected metrics from the authoritative fact/dimension inputs.
with expected as (
select o.purchase_date_key, o.order_status, p.payment_type,
count(*) as payment_record_count, count(distinct p.order_id) as orders_with_payment_records,
sum(payment_value) as recorded_payment_value,
countif(payment_value is null) as payments_missing_value,
countif(payment_type = 'credit_card' and payment_installments >= 1) as credit_card_records_with_valid_installments,
sum(if(payment_type = 'credit_card' and payment_installments >= 1,payment_installments,null)) as total_credit_card_installments,
countif(payment_type = 'credit_card' and (payment_installments is null or payment_installments < 1)) as credit_card_records_with_invalid_installments,
safe_divide(sum(payment_value), sum(sum(payment_value)) over(partition by o.purchase_date_key,o.order_status)) as payment_method_value_share
from {{ ref('fact_order_payments') }} p
left join {{ ref('fact_orders') }} o using(order_id)
group by 1,2,3
), actual as (
select purchase_date_key, order_status, payment_type, payment_record_count, orders_with_payment_records, recorded_payment_value, payments_missing_value, credit_card_records_with_valid_installments, total_credit_card_installments, credit_card_records_with_invalid_installments, payment_method_value_share from {{ ref('mart_payments_daily') }}
), missing_or_different as (
select purchase_date_key, order_status, payment_type, payment_record_count, orders_with_payment_records, recorded_payment_value, payments_missing_value, credit_card_records_with_valid_installments, total_credit_card_installments, credit_card_records_with_invalid_installments, payment_method_value_share from expected
except distinct
select * from actual
), unexpected as (
select * from actual
except distinct
select purchase_date_key, order_status, payment_type, payment_record_count, orders_with_payment_records, recorded_payment_value, payments_missing_value, credit_card_records_with_valid_installments, total_credit_card_installments, credit_card_records_with_invalid_installments, payment_method_value_share from expected
)
select * from missing_or_different
union all
select * from unexpected
