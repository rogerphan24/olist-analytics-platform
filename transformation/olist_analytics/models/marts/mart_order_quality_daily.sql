{{ config(materialized='table') }}

-- Aggregate payments before joining orders; preserve incomplete payment totals.
with payments as (
    select order_id,
        count(*) as payment_records,
        countif(payment_value is null) as missing_values,
        sum(payment_value) as recorded_payment_value
    from {{ ref('fact_order_payments') }}
    group by order_id
),
orders as (
    select o.*,
        coalesce(p.payment_records, 0) as payment_records,
        coalesce(p.missing_values, 0) as missing_payment_values,
        p.recorded_payment_value,
        p.payment_records > 0 and p.missing_values = 0
            and o.order_total_value is not null as reconciliation_eligible,
        p.recorded_payment_value - o.order_total_value as payment_difference
    from {{ ref('fact_orders') }} as o
    left join payments as p using (order_id)
)
select purchase_date_key, order_status,
    count(*) as orders_placed,
    countif(item_count = 0) as orders_without_items,
    countif(payment_records = 0) as orders_without_payment_records,
    countif(payment_records > 0) as orders_with_payment_records,
    countif(missing_payment_values > 0) as orders_with_missing_payment_values,
    countif(order_total_value is null) as orders_missing_order_total,
    countif(reconciliation_eligible) as reconciliation_eligible_orders,
    count(*) - countif(reconciliation_eligible) as reconciliation_excluded_orders,
    countif(reconciliation_eligible and abs(payment_difference) > 0.01)
        as orders_with_payment_difference,
    sum(if(reconciliation_eligible, payment_difference, null))
        as net_payment_difference,
    sum(if(reconciliation_eligible, abs(payment_difference), null))
        as absolute_payment_difference,
    max(if(reconciliation_eligible, abs(payment_difference), null))
        as maximum_absolute_payment_difference
from orders
group by 1, 2
