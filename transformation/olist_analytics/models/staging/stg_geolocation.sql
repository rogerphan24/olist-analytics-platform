{{ config(materialized='view') }}

-- Multiple observations per ZIP prefix are retained, including exact duplicates.
-- A unique ZIP lookup belongs in a downstream model, not this staging view.
select
    nullif(trim(geolocation_zip_code_prefix), '') as geolocation_zip_code_prefix,
    cast(nullif(trim(geolocation_lat), '') as float64) as geolocation_lat,
    cast(nullif(trim(geolocation_lng), '') as float64) as geolocation_lng,
    nullif(lower(trim(geolocation_city)), '') as geolocation_city,
    nullif(upper(trim(geolocation_state)), '') as geolocation_state
from {{ source('olist', 'geolocation') }}
