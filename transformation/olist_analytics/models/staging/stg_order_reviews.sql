{{ config(materialized='view') }}

-- Preserve review text and all source rows; review_id alone is not unique.
select
    nullif(trim(review_id), '') as review_id,
    nullif(trim(order_id), '') as order_id,
    cast(nullif(trim(review_score), '') as int64) as review_score,
    nullif(trim(review_comment_title), '') as review_comment_title,
    nullif(trim(review_comment_message), '') as review_comment_message,
    cast(nullif(trim(review_creation_date), '') as datetime) as review_creation_date,
    cast(nullif(trim(review_answer_timestamp), '') as datetime) as review_answer_timestamp
from {{ source('olist', 'order_reviews') }}
