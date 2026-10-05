-- Recompute expected metrics from the authoritative fact/dimension inputs.
with expected as (
with review_totals as (
select o.purchase_date_key,o.order_status,
count(*) as review_record_count,count(distinct r.order_id) as reviewed_orders,
countif(review_score between 1 and 5) as valid_score_records,
sum(if(review_score between 1 and 5,review_score,null)) as total_review_score,
countif(review_score in (1,2)) as low_score_reviews,
countif(review_score in (4,5)) as high_score_reviews,
countif(nullif(trim(review_comment_message),'') is not null) as written_reviews
from {{ ref('fact_order_reviews') }} r
left join {{ ref('fact_orders') }} o using(order_id)
group by 1,2
),
orders as (
select purchase_date_key,order_status,count(*) as orders_placed
from {{ ref('fact_orders') }} group by 1,2
)
select o.*,coalesce(r.review_record_count,0) as review_record_count,
coalesce(r.reviewed_orders,0) as reviewed_orders,
coalesce(r.valid_score_records,0) as valid_score_records,r.total_review_score,
coalesce(r.low_score_reviews,0) as low_score_reviews,
coalesce(r.high_score_reviews,0) as high_score_reviews,
coalesce(r.written_reviews,0) as written_reviews
from orders o left join review_totals r using(purchase_date_key,order_status)
), actual as (
select purchase_date_key, order_status, orders_placed, review_record_count, reviewed_orders, valid_score_records, total_review_score, low_score_reviews, high_score_reviews, written_reviews from {{ ref('mart_reviews_daily') }}
), missing_or_different as (
select purchase_date_key, order_status, orders_placed, review_record_count, reviewed_orders, valid_score_records, total_review_score, low_score_reviews, high_score_reviews, written_reviews from expected
except distinct
select * from actual
), unexpected as (
select * from actual
except distinct
select purchase_date_key, order_status, orders_placed, review_record_count, reviewed_orders, valid_score_records, total_review_score, low_score_reviews, high_score_reviews, written_reviews from expected
)
select * from missing_or_different
union all
select * from unexpected
