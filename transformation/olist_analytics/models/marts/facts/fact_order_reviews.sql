{{ config(materialized='table') }}

-- Keep all review/order pairs; a review is not assigned to a product or seller.
select
    r.review_id,
    r.order_id,
    o.customer_id,
    cast(format_date('%Y%m%d', date(o.order_purchase_timestamp)) as int64)
        as purchase_date_key,
    cast(format_date('%Y%m%d', date(r.review_creation_date)) as int64)
        as review_creation_date_key,
    cast(format_date('%Y%m%d', date(r.review_answer_timestamp)) as int64)
        as review_answer_date_key,
    r.review_score,
    r.review_comment_title,
    r.review_comment_message,
    r.review_creation_date,
    r.review_answer_timestamp,
    1 as review_count
from {{ ref('stg_order_reviews') }} as r
left join {{ ref('stg_orders') }} as o using (order_id)
