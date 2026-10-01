with expected as (

    select
        o.purchase_date_key,

        count(*) as orders_placed,
        countif(o.order_status = 'delivered') as delivered_orders,
        countif(o.order_status = 'canceled') as canceled_orders,
        countif(o.order_status = 'unavailable') as unavailable_orders,

        sum(if(
            o.order_status = 'delivered',
            o.merchandise_value, null
        )) as delivered_merchandise_value,

        sum(if(
            o.order_status = 'delivered',
            o.freight_value, null
        )) as delivered_freight_value,

        sum(if(
            o.order_status = 'delivered',
            o.order_total_value, null
        )) as delivered_total_order_value,

        countif(
            o.order_status = 'delivered'
            and o.order_total_value is not null
        ) as delivered_orders_with_total_value,

        sum(if(
            o.order_status = 'delivered',
            o.item_count, 0
        )) as delivered_item_quantity,

        count(distinct c.customer_unique_id) as purchasing_customers,

        count(distinct if(
            o.order_status = 'delivered',
            c.customer_unique_id, null
        )) as delivered_purchasing_customers,

        countif(
            o.order_status = 'delivered'
            and o.merchandise_value is null
        ) as delivered_orders_missing_merchandise_value,

        countif(
            o.order_status = 'delivered'
            and o.freight_value is null
        ) as delivered_orders_missing_freight_value,

        countif(
            o.order_status = 'delivered'
            and o.order_total_value is null
        ) as delivered_orders_missing_total_value

    from {{ ref('fact_orders') }} as o

    left join {{ ref('dim_customers') }} as c
        on o.customer_id = c.customer_id

    group by o.purchase_date_key

),

actual as (

    select *
    from {{ ref('mart_daily_sales') }}

)

select
    coalesce(e.purchase_date_key, a.purchase_date_key) as purchase_date_key

from expected as e

full outer join actual as a
    on e.purchase_date_key = a.purchase_date_key

where
    e.purchase_date_key is null
    or a.purchase_date_key is null

    {% set metrics = [
        'orders_placed',
        'delivered_orders',
        'canceled_orders',
        'unavailable_orders',
        'delivered_merchandise_value',
        'delivered_freight_value',
        'delivered_total_order_value',
        'delivered_orders_with_total_value',
        'delivered_item_quantity',
        'purchasing_customers',
        'delivered_purchasing_customers',
        'delivered_orders_missing_merchandise_value',
        'delivered_orders_missing_freight_value',
        'delivered_orders_missing_total_value'
    ] %}

    {% for metric in metrics %}
    or e.{{ metric }} is distinct from a.{{ metric }}
    {% endfor %}