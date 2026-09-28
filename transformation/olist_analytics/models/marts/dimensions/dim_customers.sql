{{ config(materialized='table') }}

-- One row per source customer record, not per distinct person.
-- Preserve the location associated with customer_id rather than assigning
-- a person's latest location to all of their historical orders.
select
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
from {{ ref('stg_customers') }}
