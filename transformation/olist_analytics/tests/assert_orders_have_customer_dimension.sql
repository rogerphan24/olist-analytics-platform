select o.order_id, o.customer_id
from {{ ref('stg_orders') }} as o
left join {{ ref('dim_customers') }} as d using (customer_id)
where d.customer_id is null
