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

        countif(o.order_status = 'delivered' and o.merchandise_value is not null)
            as delivered_orders_with_merchandise_value,
        sum(if(o.order_status = 'delivered' and o.freight_value is not null
            and o.order_total_value is not null, o.freight_value, null))
            as freight_value_for_share,
        sum(if(o.order_status = 'delivered' and o.freight_value is not null
            and o.order_total_value is not null, o.order_total_value, null))
            as order_value_for_freight_share,

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

),

daily_items as (
    select purchase_date_key,
        count(distinct product_id) as products_sold,
        count(distinct seller_id) as selling_sellers,
        sum(item_price) as known_item_price_total,
        sum(if(item_price is not null, item_quantity, 0))
            as item_quantity_with_known_price
    from {{ ref('fact_order_items') }}
    where order_status = 'delivered'
    group by purchase_date_key
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

    t.delivered_orders_with_merchandise_value,
    safe_divide(t.delivered_merchandise_value,
        t.delivered_orders_with_merchandise_value)
        as average_delivered_merchandise_value_per_order,
    t.freight_value_for_share,
    t.order_value_for_freight_share,
    safe_divide(t.freight_value_for_share, t.order_value_for_freight_share)
        as freight_share_of_delivered_order_value,
    coalesce(i.products_sold, 0) as products_sold,
    coalesce(i.selling_sellers, 0) as selling_sellers,
    i.known_item_price_total,
    coalesce(i.item_quantity_with_known_price, 0) as item_quantity_with_known_price,
    safe_divide(i.known_item_price_total, i.item_quantity_with_known_price)
        as average_delivered_item_price,

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

left join daily_items as i
    on t.purchase_date_key = i.purchase_date_key

left join {{ ref('dim_date') }} as d
    on t.purchase_date_key = d.date_key
