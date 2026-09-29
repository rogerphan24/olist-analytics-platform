select
    coalesce(s.order_id, f.order_id) as order_id,
    coalesce(s.order_item_id, f.order_item_id) as order_item_id
from {{ ref('stg_order_items') }} as s
full outer join {{ ref('fact_order_items') }} as f
    on s.order_id = f.order_id
    and s.order_item_id = f.order_item_id
where s.order_id is null
   or f.order_id is null
   or f.item_price is distinct from s.price
   or f.freight_value is distinct from s.freight_value
   or f.item_total_value is distinct from (s.price + s.freight_value)
   or f.item_quantity is distinct from 1