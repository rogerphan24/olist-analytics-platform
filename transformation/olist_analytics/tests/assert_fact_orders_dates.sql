-- Preserve source datetimes and validate derived calendar keys and intervals.
select f.order_id
from {{ ref('fact_orders') }} as f
join {{ ref('stg_orders') }} as s
    on f.order_id = s.order_id
where
    f.delivery_days is distinct from date_diff(
        date(s.order_delivered_customer_date),
        date(s.order_purchase_timestamp),
        day
    )
    or f.delivery_delay_days is distinct from date_diff(
        date(s.order_delivered_customer_date),
        date(s.order_estimated_delivery_date),
        day
    )
    or f.is_delivered_late is distinct from (
        date(s.order_delivered_customer_date)
        > date(s.order_estimated_delivery_date)
    )

{% set date_fields = [
    ('order_purchase_timestamp', 'purchase_date_key'),
    ('order_approved_at', 'approved_date_key'),
    ('order_delivered_carrier_date', 'carrier_delivery_date_key'),
    ('order_delivered_customer_date', 'customer_delivery_date_key'),
    ('order_estimated_delivery_date', 'estimated_delivery_date_key')
] %}

{% for source_column, key_column in date_fields %}
    or f.{{ source_column }} is distinct from s.{{ source_column }}
    or f.{{ key_column }} is distinct from cast(
        format_date('%Y%m%d', date(s.{{ source_column }}))
        as int64
    )
{% endfor %}
