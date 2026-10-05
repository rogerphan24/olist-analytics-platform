-- Recompute expected metrics from the authoritative fact/dimension inputs.
with expected as (
with per_order as (
select o.order_id,o.purchase_date_key,o.order_status,o.item_count,o.order_total_value,
count(p.order_id) as records,countif(p.order_id is not null and p.payment_value is null) as missing,
sum(p.payment_value)-o.order_total_value as delta
from {{ ref('fact_orders') }} o
left join {{ ref('fact_order_payments') }} p using(order_id)
group by 1,2,3,4,5
), classified as (
select *,records>0 and missing=0 and order_total_value is not null as eligible from per_order
)
select purchase_date_key,order_status,count(*) as orders_placed,
countif(item_count=0) as orders_without_items,countif(records=0) as orders_without_payment_records,
countif(records>0) as orders_with_payment_records,countif(missing>0) as orders_with_missing_payment_values,
countif(order_total_value is null) as orders_missing_order_total,
countif(eligible) as reconciliation_eligible_orders,countif(not eligible) as reconciliation_excluded_orders,
countif(eligible and abs(delta)>0.01) as orders_with_payment_difference,
sum(if(eligible,delta,null)) as net_payment_difference,
sum(if(eligible,abs(delta),null)) as absolute_payment_difference,
max(if(eligible,abs(delta),null)) as maximum_absolute_payment_difference
from classified group by 1,2
), actual as (
select purchase_date_key, order_status, orders_placed, orders_without_items, orders_without_payment_records, orders_with_payment_records, orders_with_missing_payment_values, orders_missing_order_total, reconciliation_eligible_orders, reconciliation_excluded_orders, orders_with_payment_difference, net_payment_difference, absolute_payment_difference, maximum_absolute_payment_difference from {{ ref('mart_order_quality_daily') }}
), missing_or_different as (
select purchase_date_key, order_status, orders_placed, orders_without_items, orders_without_payment_records, orders_with_payment_records, orders_with_missing_payment_values, orders_missing_order_total, reconciliation_eligible_orders, reconciliation_excluded_orders, orders_with_payment_difference, net_payment_difference, absolute_payment_difference, maximum_absolute_payment_difference from expected
except distinct
select * from actual
), unexpected as (
select * from actual
except distinct
select purchase_date_key, order_status, orders_placed, orders_without_items, orders_without_payment_records, orders_with_payment_records, orders_with_missing_payment_values, orders_missing_order_total, reconciliation_eligible_orders, reconciliation_excluded_orders, orders_with_payment_difference, net_payment_difference, absolute_payment_difference, maximum_absolute_payment_difference from expected
)
select * from missing_or_different
union all
select * from unexpected
