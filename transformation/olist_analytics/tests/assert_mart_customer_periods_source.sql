-- Recompute expected metrics from the authoritative fact/dimension inputs.
with expected as (
with orders as (
select o.*,c.customer_unique_id,date(o.order_purchase_timestamp) as purchase_date,
min(if(o.order_status='delivered',date(o.order_purchase_timestamp),null))
over(partition by c.customer_unique_id) as first_date,
min(date(o.order_purchase_timestamp)) over() as dataset_start,
max(date(o.order_purchase_timestamp)) over() as dataset_end
from {{ ref('fact_orders') }} o
left join {{ ref('dim_customers') }} c using(customer_id)
),
expanded as (
select *,
case period_type when 'day' then purchase_date when 'month' then date_trunc(purchase_date,month)
when 'year' then date_trunc(purchase_date,year) else dataset_start end as period_start,
case period_type when 'day' then purchase_date when 'month' then last_day(purchase_date,month)
when 'year' then last_day(purchase_date,year) else dataset_end end as period_end
from orders cross join unnest(['day','month','year','dataset']) period_type
),
people as (
select period_type,period_start,period_end,customer_unique_id,count(*) as orders_placed,
countif(order_status='delivered') as delivered_orders,min(first_date) as first_date
from expanded group by 1,2,3,4
)
select period_type,period_start,period_end,sum(orders_placed) as orders_placed,
sum(delivered_orders) as delivered_orders,count(*) as purchasing_customers,
countif(delivered_orders>0) as delivered_purchasing_customers,
countif(delivered_orders>=2) as repeat_delivered_purchasing_customers,
countif(first_date between period_start and period_end) as first_observed_delivered_purchasing_customers
from people group by 1,2,3
), actual as (
select period_type, period_start, period_end, orders_placed, delivered_orders, purchasing_customers, delivered_purchasing_customers, repeat_delivered_purchasing_customers, first_observed_delivered_purchasing_customers from {{ ref('mart_customer_periods') }}
), missing_or_different as (
select period_type, period_start, period_end, orders_placed, delivered_orders, purchasing_customers, delivered_purchasing_customers, repeat_delivered_purchasing_customers, first_observed_delivered_purchasing_customers from expected
except distinct
select * from actual
), unexpected as (
select * from actual
except distinct
select period_type, period_start, period_end, orders_placed, delivered_orders, purchasing_customers, delivered_purchasing_customers, repeat_delivered_purchasing_customers, first_observed_delivered_purchasing_customers from expected
)
select * from missing_or_different
union all
select * from unexpected
