{{ config(materialized='table') }}


with orders as (

    select *
    from {{ ref('fact_orders') }}

),

customers as (

    select
        customer_id,
        customer_unique_id
    from {{ ref('dim_customers') }}

),

daily_totals as (

    select
        o.purchase_date_key,

        count(*) as orders_placed,
        countif(o.order_status = 'delivered') as delivered_orders,
        countif(o.order_status = 'canceled') as canceled_orders,
        countif(o.order_status = 'unavailable') as unavailable_orders,

        sum(
            case when o.order_status = 'delivered'
                then o.merchandise_value
            end
        ) as delivered_merchandise_value,

        sum(
            case when o.order_status = 'delivered'
                then o.freight_value
            end
        ) as delivered_freight_value,

        sum(
            case when o.order_status = 'delivered'
                then o.order_total_value
            end
        ) as delivered_total_order_value,

        countif(
            o.order_status = 'delivered'
            and o.order_total_value is not null
        ) as delivered_orders_with_total_value,

        sum(
            case when o.order_status = 'delivered'
                then o.item_count
                else 0
            end
        ) as delivered_item_quantity,

        count(distinct c.customer_unique_id) as purchasing_customers,

        count(distinct
            case when o.order_status = 'delivered'
                then c.customer_unique_id
            end
        ) as delivered_purchasing_customers,

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

    from orders as o

    left join customers as c
        on o.customer_id = c.customer_id

    group by o.purchase_date_key

)

select
    t.purchase_date_key,
    d.calendar_date as purchase_date,
    d.calendar_year,
    d.calendar_quarter,
    d.month_number,
    d.month_start_date,
    d.day_name,
    d.is_weekend,

    t.orders_placed,
    t.delivered_orders,
    t.canceled_orders,
    t.unavailable_orders,

    safe_divide(
        t.delivered_orders, t.orders_placed
    ) as delivered_order_share,

    safe_divide(
        t.canceled_orders, t.orders_placed
    ) as cancellation_rate,

    safe_divide(
        t.unavailable_orders, t.orders_placed
    ) as unavailable_order_rate,

    t.delivered_merchandise_value,
    t.delivered_freight_value,
    t.delivered_total_order_value,
    t.delivered_orders_with_total_value,

    safe_divide(
        t.delivered_total_order_value,
        t.delivered_orders_with_total_value
    ) as average_delivered_order_value,

    t.delivered_item_quantity,

    safe_divide(
        t.delivered_item_quantity, t.delivered_orders
    ) as average_items_per_delivered_order,

    t.purchasing_customers,
    t.delivered_purchasing_customers,

    t.delivered_orders_missing_merchandise_value,
    t.delivered_orders_missing_freight_value,
    t.delivered_orders_missing_total_value,

    safe_divide(
        t.delivered_orders_with_total_value,
        t.delivered_orders
    ) as delivered_order_total_coverage

from daily_totals as t

left join {{ ref('dim_date') }} as d
    on t.purchase_date_key = d.date_key