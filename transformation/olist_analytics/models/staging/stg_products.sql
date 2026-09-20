{{ config(materialized='view') }}

select
    nullif(trim(product_id), '') as product_id,
    nullif(lower(trim(product_category_name)), '') as product_category_name,
    cast(nullif(trim(product_name_lenght), '') as int64) as product_name_length,
    cast(nullif(trim(product_description_lenght), '') as int64) as product_description_length,
    cast(nullif(trim(product_photos_qty), '') as int64) as product_photos_qty,
    cast(nullif(trim(product_weight_g), '') as numeric) as product_weight_g,
    cast(nullif(trim(product_length_cm), '') as numeric) as product_length_cm,
    cast(nullif(trim(product_height_cm), '') as numeric) as product_height_cm,
    cast(nullif(trim(product_width_cm), '') as numeric) as product_width_cm
from {{ source('olist', 'products') }}
