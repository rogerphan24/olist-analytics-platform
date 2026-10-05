{{ config(materialized='table') }}

-- One review aggregate per order prevents duplicated order denominators.
with reviews as (
    select order_id,
        count(*) as review_records,
        countif(review_score between 1 and 5) as valid_score_records,
        sum(if(review_score between 1 and 5, review_score, null)) as total_review_score,
        countif(review_score in (1, 2)) as low_score_reviews,
        countif(review_score in (4, 5)) as high_score_reviews,
        countif(nullif(trim(review_comment_message), '') is not null) as written_reviews
    from {{ ref('fact_order_reviews') }}
    group by order_id
),
totals as (
    select o.purchase_date_key, o.order_status,
        count(*) as orders_placed,
        countif(r.order_id is not null) as reviewed_orders,
        sum(coalesce(r.review_records, 0)) as review_record_count,
        sum(coalesce(r.valid_score_records, 0)) as valid_score_records,
        sum(r.total_review_score) as total_review_score,
        sum(coalesce(r.low_score_reviews, 0)) as low_score_reviews,
        sum(coalesce(r.high_score_reviews, 0)) as high_score_reviews,
        sum(coalesce(r.written_reviews, 0)) as written_reviews
    from {{ ref('fact_orders') }} as o
    left join reviews as r using (order_id)
    group by 1, 2
)
select t.*, d.calendar_date as purchase_date,
    review_record_count - valid_score_records as invalid_score_records,
    safe_divide(reviewed_orders, orders_placed) as order_review_coverage,
    safe_divide(total_review_score, valid_score_records) as average_review_score,
    safe_divide(low_score_reviews, valid_score_records) as low_score_review_share,
    safe_divide(high_score_reviews, valid_score_records) as high_score_review_share,
    safe_divide(written_reviews, review_record_count) as written_review_share
from totals as t
left join {{ ref('dim_date') }} as d on t.purchase_date_key = d.date_key
