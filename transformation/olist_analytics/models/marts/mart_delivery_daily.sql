{{ config(materialized='table') }}

with delivered_orders as (

    select
        purchase_date_key,
        delivery_days,
        delivery_delay_days,
        is_delivered_late

    from {{ ref('fact_orders') }}

    where order_status = 'delivered'

),

daily_totals as (

    select
        purchase_date_key,

        count(*) as delivered_orders,

        -- Duration: exclude missing and negative values from averages.
        countif(delivery_days >= 0) as orders_with_valid_delivery_duration,
        countif(delivery_days is null) as orders_missing_delivery_duration,
        countif(delivery_days < 0) as orders_with_negative_delivery_duration,

        sum(
            case when delivery_days >= 0
                then delivery_days
            end
        ) as total_valid_delivery_days,

        -- Punctuality: missing values remain outside the denominator.
        countif(
            is_delivered_late is not null
        ) as orders_with_known_punctuality,

        countif(
            is_delivered_late is null
        ) as orders_missing_punctuality,

        countif(
            is_delivered_late = false
        ) as on_time_delivered_orders,

        countif(
            is_delivered_late = true
        ) as late_delivered_orders,

        -- Signed delay: negative means early, positive means late.
        countif(
            delivery_delay_days is not null
        ) as orders_with_known_delivery_delay,

        sum(delivery_delay_days) as total_signed_delivery_delay_days,

        -- Late-only duration excludes early and on-time deliveries.
        countif(
            delivery_delay_days > 0
        ) as orders_with_positive_delivery_delay,

        sum(
            case when delivery_delay_days > 0
                then delivery_delay_days
            end
        ) as total_days_late

    from delivered_orders

    group by purchase_date_key

)

select
    t.purchase_date_key,
    d.calendar_date as purchase_date,
    d.calendar_year,
    d.calendar_quarter,
    d.month_number,
    d.month_start_date,

    t.delivered_orders,

    t.orders_with_valid_delivery_duration,
    t.orders_missing_delivery_duration,
    t.orders_with_negative_delivery_duration,
    t.total_valid_delivery_days,

    safe_divide(
        t.orders_with_valid_delivery_duration,
        t.delivered_orders
    ) as delivery_duration_coverage,

    safe_divide(
        t.total_valid_delivery_days,
        t.orders_with_valid_delivery_duration
    ) as average_delivery_days,

    t.orders_with_known_punctuality,
    t.orders_missing_punctuality,
    t.on_time_delivered_orders,
    t.late_delivered_orders,

    safe_divide(
        t.orders_with_known_punctuality,
        t.delivered_orders
    ) as delivery_punctuality_coverage,

    safe_divide(
        t.on_time_delivered_orders,
        t.orders_with_known_punctuality
    ) as on_time_delivery_rate,

    safe_divide(
        t.late_delivered_orders,
        t.orders_with_known_punctuality
    ) as late_delivery_rate,

    t.orders_with_known_delivery_delay,
    t.total_signed_delivery_delay_days,

    safe_divide(
        t.total_signed_delivery_delay_days,
        t.orders_with_known_delivery_delay
    ) as average_signed_delivery_delay_days,

    t.orders_with_positive_delivery_delay,
    t.total_days_late,

    safe_divide(
        t.total_days_late,
        t.orders_with_positive_delivery_delay
    ) as average_days_late

from daily_totals as t

left join {{ ref('dim_date') }} as d
    on t.purchase_date_key = d.date_key