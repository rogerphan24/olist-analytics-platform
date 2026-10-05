select purchase_date_key from {{ ref('mart_delivery_daily') }}
where delivered_orders <= 0
or orders_with_valid_delivery_duration+orders_missing_delivery_duration+orders_with_negative_delivery_duration != delivered_orders
or orders_with_known_punctuality+orders_missing_punctuality != delivered_orders
or on_time_delivered_orders+late_delivered_orders != orders_with_known_punctuality
or late_delivered_orders is distinct from orders_with_positive_delivery_delay
or orders_with_known_punctuality is distinct from orders_with_known_delivery_delay
or delivery_duration_coverage is distinct from safe_divide(orders_with_valid_delivery_duration, delivered_orders)
or average_delivery_days is distinct from safe_divide(total_valid_delivery_days, orders_with_valid_delivery_duration)
or delivery_punctuality_coverage is distinct from safe_divide(orders_with_known_punctuality, delivered_orders)
or on_time_delivery_rate is distinct from safe_divide(on_time_delivered_orders, orders_with_known_punctuality)
or late_delivery_rate is distinct from safe_divide(late_delivered_orders, orders_with_known_punctuality)
or average_signed_delivery_delay_days is distinct from safe_divide(total_signed_delivery_delay_days, orders_with_known_delivery_delay)
or average_days_late is distinct from safe_divide(total_days_late, orders_with_positive_delivery_delay)
union all
select purchase_date_key from {{ ref('mart_delivery_daily') }} group by 1 having count(*)>1
