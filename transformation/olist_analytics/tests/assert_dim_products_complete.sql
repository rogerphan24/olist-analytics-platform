select
    p.product_id
from {{ ref('stg_products') }} as p
left join {{ ref('dim_products') }} as d
    on p.product_id = d.product_id
where d.product_id is null