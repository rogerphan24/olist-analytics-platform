select
    s.seller_id
from {{ ref('stg_sellers') }} as s
left join {{ ref('dim_sellers') }} as d
    on s.seller_id = d.seller_id
where d.seller_id is null