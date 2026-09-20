{{config(materialized='view')}}

SELECT
    NULLIF(TRIM(customer_id), '') AS customer_id,
    NULLIF(TRIM(customer_unique_id), '') AS customer_unique_id,
    NULLIF(TRIM(customer_zip_code_prefix), '') AS customer_zip_code_prefix,
    NULLIF(LOWER(TRIM(customer_city)), '') AS customer_city,
    NULLIF(UPPER(TRIM(customer_state)), '') AS customer_state
FROM {{ source('olist', 'customers') }}
