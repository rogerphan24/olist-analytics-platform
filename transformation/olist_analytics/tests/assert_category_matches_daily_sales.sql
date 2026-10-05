with categories as (
select purchase_date_key,sum(delivered_item_quantity) as quantity,
sum(delivered_merchandise_value) as merchandise,sum(delivered_freight_value) as freight,
sum(delivered_total_item_value) as total_value
from {{ ref('mart_category_sales_daily') }} group by 1
)
select coalesce(c.purchase_date_key,s.purchase_date_key) as purchase_date_key
from categories c full outer join
(select * from {{ ref('mart_daily_sales') }} where delivered_orders>0) s using(purchase_date_key)
where c.purchase_date_key is null or s.purchase_date_key is null
or c.quantity is distinct from s.delivered_item_quantity
or c.merchandise is distinct from s.delivered_merchandise_value
or c.freight is distinct from s.delivered_freight_value
or c.total_value is distinct from s.delivered_total_order_value
