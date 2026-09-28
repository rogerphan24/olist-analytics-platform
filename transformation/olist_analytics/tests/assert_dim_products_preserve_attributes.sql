select d.product_id
from {{ ref('dim_products') }} as d
join {{ ref('stg_products') }} as p using (product_id)
left join {{ ref('stg_product_category_translation') }} as t
    on p.product_category_name = t.product_category_name
where d.product_category_name is distinct from p.product_category_name
   or d.product_category_name_english is distinct from t.product_category_name_english
   or d.category_translation_status is distinct from (
       case when p.product_category_name is null then 'missing_category'
            when t.product_category_name_english is null then 'unmapped_category'
            else 'translated' end
   )
{% for field in ['product_name_length', 'product_description_length',
                 'product_photos_qty', 'product_weight_g', 'product_length_cm',
                 'product_height_cm', 'product_width_cm'] %}
   or d.{{ field }} is distinct from p.{{ field }}
{% endfor %}
