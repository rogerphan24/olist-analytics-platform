with item_totals as (
    select
        order_id,
        count(*) as item_count,
        sum(price) as merchandise_value,
        sum(freight_value) as freight_value
    from {{ ref('stg_order_items') }}
    group by order_id
),

expected_orders as (
    select
        o.order_id,
        o.customer_id,
        o.order_status,
        coalesce(i.item_count, 0) as item_count,
        i.merchandise_value,
        i.freight_value,
        i.merchandise_value + i.freight_value as order_total_value
    from {{ ref('stg_orders') }} as o
    left join item_totals as i
        on o.order_id = i.order_id
)

select
    coalesce(e.order_id, f.order_id) as order_id
from expected_orders as e
full outer join {{ ref('fact_orders') }} as f
    on e.order_id = f.order_id
where e.order_id is null
   or f.order_id is null
   or f.customer_id is distinct from e.customer_id
   or f.order_status is distinct from e.order_status
   or f.item_count is distinct from e.item_count
   or f.merchandise_value is distinct from e.merchandise_value
   or f.freight_value is distinct from e.freight_value
   or f.order_total_value is distinct from e.order_total_value