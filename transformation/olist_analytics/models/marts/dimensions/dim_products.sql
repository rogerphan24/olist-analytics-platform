{{ config(materialized='table') }}

with products as (
    SELECT * FROM {{ ref('stg_products') }}
),

category_translation as (
    SELECT * FROM {{ ref('stg_product_category_translation') }}
)


SELECT
    prod.product_id,
    prod.product_category_name,
    cat_trans.product_category_name_english,
    CASE WHEN prod.product_category_name IS NULL THEN 'missing_category'
         WHEN cat_trans.product_category_name_english IS NULL THEN 'unmapped_category'
         ELSE 'translated'
    END AS category_translation_status,
    prod.product_name_length,
    prod.product_description_length,
    prod.product_photos_qty,
    prod.product_weight_g,
    prod.product_length_cm,
    prod.product_height_cm,
    prod.product_width_cm
FROM products AS prod
LEFT JOIN category_translation AS cat_trans
    ON prod.product_category_name = cat_trans.product_category_name