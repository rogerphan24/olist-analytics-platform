select d.seller_id
from {{ ref('dim_sellers') }} as d
join {{ ref('stg_sellers') }} as s using (seller_id)
where d.seller_zip_code_prefix is distinct from s.seller_zip_code_prefix
   or d.seller_city is distinct from s.seller_city
   or d.seller_state is distinct from s.seller_state
