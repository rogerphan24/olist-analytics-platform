select coalesce(d.purchase_date_key,s.purchase_date_key) as purchase_date_key
from {{ ref('mart_delivery_daily') }} d
full outer join (select * from {{ ref('mart_daily_sales') }} where delivered_orders>0) s using(purchase_date_key)
where d.purchase_date_key is null or s.purchase_date_key is null
or d.delivered_orders is distinct from s.delivered_orders
