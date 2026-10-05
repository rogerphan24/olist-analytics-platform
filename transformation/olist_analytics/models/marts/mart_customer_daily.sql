{{ config(materialized='table') }}

-- Reaggregate this person/day grain for arbitrary reporting periods.
with orders as (
    select o.*, c.customer_unique_id,
        date(o.order_purchase_timestamp) as purchase_date
    from {{ ref('fact_orders') }} as o
    left join {{ ref('dim_customers') }} as c using (customer_id)
),
first_observed as (
    select customer_unique_id,
        min(if(order_status = 'delivered', purchase_date, null))
            as first_observed_delivered_purchase_date
    from orders
    group by customer_unique_id
)
select o.purchase_date_key, o.purchase_date, o.customer_unique_id,
    f.first_observed_delivered_purchase_date,
    count(*) as orders_placed,
    countif(o.order_status = 'delivered') as delivered_orders,
    sum(if(o.order_status = 'delivered', o.order_total_value, null))
        as delivered_total_order_value,
    countif(o.order_status = 'delivered' and o.order_total_value is not null)
        as delivered_orders_with_total_value
from orders as o
left join first_observed as f using (customer_unique_id)
group by 1, 2, 3, 4
