select s.customer_id
from {{ ref('stg_customers') }} as s
left join {{ ref('dim_customers') }} as d using (customer_id)
where d.customer_id is null
