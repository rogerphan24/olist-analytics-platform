select *
from {{ ref('stg_products') }}
where product_name_length < 0
   or product_description_length < 0
   or product_photos_qty < 0
   or product_weight_g < 0
   or product_length_cm < 0
   or product_height_cm < 0
   or product_width_cm < 0
