-- Recompute expected metrics from the authoritative fact/dimension inputs.
with expected as (
select purchase_date_key,
count(*) as delivered_orders,
countif(delivery_days >= 0) as orders_with_valid_delivery_duration,
countif(delivery_days is null) as orders_missing_delivery_duration,
countif(delivery_days < 0) as orders_with_negative_delivery_duration,
sum(if(delivery_days >= 0,delivery_days,null)) as total_valid_delivery_days,
countif(is_delivered_late is not null) as orders_with_known_punctuality,
countif(is_delivered_late is null) as orders_missing_punctuality,
countif(is_delivered_late = false) as on_time_delivered_orders,
countif(is_delivered_late = true) as late_delivered_orders,
countif(delivery_delay_days is not null) as orders_with_known_delivery_delay,
sum(delivery_delay_days) as total_signed_delivery_delay_days,
countif(delivery_delay_days > 0) as orders_with_positive_delivery_delay,
sum(if(delivery_delay_days > 0,delivery_delay_days,null)) as total_days_late
from {{ ref('fact_orders') }} where order_status='delivered' group by 1
), actual as (
select purchase_date_key, delivered_orders, orders_with_valid_delivery_duration, orders_missing_delivery_duration, orders_with_negative_delivery_duration, total_valid_delivery_days, orders_with_known_punctuality, orders_missing_punctuality, on_time_delivered_orders, late_delivered_orders, orders_with_known_delivery_delay, total_signed_delivery_delay_days, orders_with_positive_delivery_delay, total_days_late from {{ ref('mart_delivery_daily') }}
), missing_or_different as (
select purchase_date_key, delivered_orders, orders_with_valid_delivery_duration, orders_missing_delivery_duration, orders_with_negative_delivery_duration, total_valid_delivery_days, orders_with_known_punctuality, orders_missing_punctuality, on_time_delivered_orders, late_delivered_orders, orders_with_known_delivery_delay, total_signed_delivery_delay_days, orders_with_positive_delivery_delay, total_days_late from expected
except distinct
select * from actual
), unexpected as (
select * from actual
except distinct
select purchase_date_key, delivered_orders, orders_with_valid_delivery_duration, orders_missing_delivery_duration, orders_with_negative_delivery_duration, total_valid_delivery_days, orders_with_known_punctuality, orders_missing_punctuality, on_time_delivered_orders, late_delivered_orders, orders_with_known_delivery_delay, total_signed_delivery_delay_days, orders_with_positive_delivery_delay, total_days_late from expected
)
select * from missing_or_different
union all
select * from unexpected
