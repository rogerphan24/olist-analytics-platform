select i.order_id, i.order_item_id, i.product_id, i.seller_id
from {{ ref('stg_order_items') }} as i
left join {{ ref('dim_products') }} as p using (product_id)
left join {{ ref('dim_sellers') }} as s using (seller_id)
where p.product_id is null or s.seller_id is null
