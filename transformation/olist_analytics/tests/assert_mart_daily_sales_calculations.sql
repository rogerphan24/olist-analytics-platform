with expected as (

    select
        *,

        safe_divide(
            delivered_orders, orders_placed
        ) as expected_delivered_order_share,

        safe_divide(
            canceled_orders, orders_placed
        ) as expected_cancellation_rate,

        safe_divide(
            unavailable_orders, orders_placed
        ) as expected_unavailable_order_rate,

        safe_divide(
            delivered_total_order_value,
            delivered_orders_with_total_value
        ) as expected_average_delivered_order_value,

        safe_divide(
            delivered_item_quantity, delivered_orders
        ) as expected_average_items_per_delivered_order,

        safe_divide(
            delivered_orders_with_total_value, delivered_orders
        ) as expected_delivered_order_total_coverage

    from {{ ref('mart_daily_sales') }}

)

select purchase_date_key
from expected
where
    -- Each row represents a date with at least one order.
    orders_placed <= 0

    -- Counts must respect their populations.
    or delivered_orders < 0
    or canceled_orders < 0
    or unavailable_orders < 0
    or delivered_orders + canceled_orders + unavailable_orders > orders_placed

    or delivered_orders_with_total_value < 0
    or delivered_orders_with_total_value > delivered_orders

    or delivered_orders_missing_total_value < 0
    or delivered_orders_with_total_value
        + delivered_orders_missing_total_value != delivered_orders

    or delivered_orders_missing_merchandise_value
        not between 0 and delivered_orders
    or delivered_orders_missing_freight_value
        not between 0 and delivered_orders

    or delivered_item_quantity < 0

    or purchasing_customers not between 1 and orders_placed
    or delivered_purchasing_customers not between 0 and delivered_orders
    or delivered_purchasing_customers > purchasing_customers

    -- Null-safe comparisons also check zero-denominator handling.
    {% set metrics = [
        'delivered_order_share',
        'cancellation_rate',
        'unavailable_order_rate',
        'average_delivered_order_value',
        'average_items_per_delivered_order',
        'delivered_order_total_coverage'
    ] %}

    {% for metric in metrics %}
    or {{ metric }} is distinct from expected_{{ metric }}
    {% endfor %}