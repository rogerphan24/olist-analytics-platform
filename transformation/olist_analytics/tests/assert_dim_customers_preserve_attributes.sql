select d.customer_id
from {{ ref('dim_customers') }} as d
join {{ ref('stg_customers') }} as s using (customer_id)
where d.customer_unique_id is distinct from s.customer_unique_id
   or d.customer_zip_code_prefix is distinct from s.customer_zip_code_prefix
   or d.customer_city is distinct from s.customer_city
   or d.customer_state is distinct from s.customer_state
