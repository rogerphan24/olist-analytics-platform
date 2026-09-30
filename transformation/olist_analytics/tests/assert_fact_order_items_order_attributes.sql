select f.order_id, f.order_item_id
from {{ ref('fact_order_items') }} as f
join {{ ref('stg_order_items') }} as i using (order_id, order_item_id)
join {{ ref('stg_orders') }} as o on f.order_id = o.order_id
where f.customer_id is distinct from o.customer_id
   or f.order_status is distinct from o.order_status
   or f.product_id is distinct from i.product_id
   or f.seller_id is distinct from i.seller_id
   or f.order_purchase_timestamp is distinct from o.order_purchase_timestamp
   or f.shipping_limit_date is distinct from i.shipping_limit_date
   or f.purchase_date_key is distinct from cast(format_date('%Y%m%d', date(o.order_purchase_timestamp)) as int64)
   or f.shipping_limit_date_key is distinct from cast(format_date('%Y%m%d', date(i.shipping_limit_date)) as int64)
