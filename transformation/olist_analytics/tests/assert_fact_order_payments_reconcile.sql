with expected as (
    select p.*, o.customer_id,
        cast(format_date('%Y%m%d', date(o.order_purchase_timestamp)) as int64) as purchase_date_key
    from {{ ref('stg_order_payments') }} as p
    left join {{ ref('stg_orders') }} as o using (order_id)
)
select coalesce(e.order_id, f.order_id) as order_id,
       coalesce(e.payment_sequential, f.payment_sequential) as payment_sequential
from expected as e
full outer join {{ ref('fact_order_payments') }} as f
    on e.order_id = f.order_id and e.payment_sequential = f.payment_sequential
where e.order_id is null or f.order_id is null
{% for column in ['customer_id', 'purchase_date_key', 'payment_type', 'payment_installments', 'payment_value'] %}
   or f.{{ column }} is distinct from e.{{ column }}
{% endfor %}
   or f.payment_record_count is distinct from 1
