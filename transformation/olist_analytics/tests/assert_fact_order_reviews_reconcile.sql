with expected as (
    select r.*, o.customer_id,
        cast(format_date('%Y%m%d', date(o.order_purchase_timestamp)) as int64) as purchase_date_key,
        cast(format_date('%Y%m%d', date(r.review_creation_date)) as int64) as review_creation_date_key,
        cast(format_date('%Y%m%d', date(r.review_answer_timestamp)) as int64) as review_answer_date_key
    from {{ ref('stg_order_reviews') }} as r
    left join {{ ref('stg_orders') }} as o using (order_id)
)
select coalesce(e.review_id, f.review_id) as review_id,
       coalesce(e.order_id, f.order_id) as order_id
from expected as e
full outer join {{ ref('fact_order_reviews') }} as f
    on e.review_id = f.review_id and e.order_id = f.order_id
where e.order_id is null or f.order_id is null
{% for column in ['customer_id', 'purchase_date_key', 'review_creation_date_key',
                  'review_answer_date_key', 'review_score', 'review_comment_title',
                  'review_comment_message', 'review_creation_date', 'review_answer_timestamp'] %}
   or f.{{ column }} is distinct from e.{{ column }}
{% endfor %}
   or f.review_count is distinct from 1
