-- Recompute expected metrics from the authoritative fact/dimension inputs.
with expected as (
with source as (
select o.*,c.customer_unique_id,
min(if(order_status='delivered',date(order_purchase_timestamp),null))
over(partition by c.customer_unique_id) as first_date
from {{ ref('fact_orders') }} o
left join {{ ref('dim_customers') }} c using(customer_id)
)
select purchase_date_key,date(order_purchase_timestamp) as purchase_date,customer_unique_id,
min(first_date) as first_observed_delivered_purchase_date,
count(*) as orders_placed,countif(order_status='delivered') as delivered_orders,
sum(if(order_status='delivered',order_total_value,null)) as delivered_total_order_value,
countif(order_status='delivered' and order_total_value is not null) as delivered_orders_with_total_value
from source group by 1,2,3
), actual as (
select purchase_date_key, purchase_date, customer_unique_id, first_observed_delivered_purchase_date, orders_placed, delivered_orders, delivered_total_order_value, delivered_orders_with_total_value from {{ ref('mart_customer_daily') }}
), missing_or_different as (
select purchase_date_key, purchase_date, customer_unique_id, first_observed_delivered_purchase_date, orders_placed, delivered_orders, delivered_total_order_value, delivered_orders_with_total_value from expected
except distinct
select * from actual
), unexpected as (
select * from actual
except distinct
select purchase_date_key, purchase_date, customer_unique_id, first_observed_delivered_purchase_date, orders_placed, delivered_orders, delivered_total_order_value, delivered_orders_with_total_value from expected
)
select * from missing_or_different
union all
select * from unexpected
