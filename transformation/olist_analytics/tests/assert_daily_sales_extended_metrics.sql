with orders as (
select purchase_date_key,
countif(order_status='delivered' and merchandise_value is not null) as delivered_orders_with_merchandise_value,
sum(if(order_status='delivered',merchandise_value,null)) as merchandise,
sum(if(order_status='delivered' and freight_value is not null and order_total_value is not null,freight_value,null)) as freight_value_for_share,
sum(if(order_status='delivered' and freight_value is not null and order_total_value is not null,order_total_value,null)) as order_value_for_freight_share
from {{ ref('fact_orders') }} group by 1
), items as (
select purchase_date_key,count(distinct product_id) as products_sold,
count(distinct seller_id) as selling_sellers,sum(item_price) as known_item_price_total,
sum(if(item_price is not null,item_quantity,0)) as item_quantity_with_known_price
from {{ ref('fact_order_items') }} where order_status='delivered' group by 1
)
select coalesce(o.purchase_date_key,m.purchase_date_key) as purchase_date_key
from orders o
left join items i using(purchase_date_key)
full outer join {{ ref('mart_daily_sales') }} m on o.purchase_date_key=m.purchase_date_key
where o.purchase_date_key is null or m.purchase_date_key is null
or m.delivered_orders_with_merchandise_value is distinct from o.delivered_orders_with_merchandise_value
or m.average_delivered_merchandise_value_per_order is distinct from safe_divide(o.merchandise,o.delivered_orders_with_merchandise_value)
or m.freight_value_for_share is distinct from o.freight_value_for_share
or m.order_value_for_freight_share is distinct from o.order_value_for_freight_share
or m.freight_share_of_delivered_order_value is distinct from safe_divide(o.freight_value_for_share,o.order_value_for_freight_share)
or m.products_sold is distinct from coalesce(i.products_sold,0)
or m.selling_sellers is distinct from coalesce(i.selling_sellers,0)
or m.known_item_price_total is distinct from i.known_item_price_total
or m.item_quantity_with_known_price is distinct from coalesce(i.item_quantity_with_known_price,0)
or m.average_delivered_item_price is distinct from safe_divide(i.known_item_price_total,i.item_quantity_with_known_price)
