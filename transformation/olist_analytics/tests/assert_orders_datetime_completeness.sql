-- Force evaluation of every date cast, including optional lifecycle dates.
-- Every populated source date must remain populated after conversion.
{% set fields = ['order_purchase_timestamp', 'order_approved_at',
                 'order_delivered_carrier_date', 'order_delivered_customer_date',
                 'order_estimated_delivery_date'] %}
{% for field in fields %}
select '{{ field }}' as column_name, raw_count, staged_count
from (
    select countif(nullif(trim({{ field }}), '') is not null) as raw_count
    from {{ source('olist', 'orders') }}
) as raw
cross join (
    select count({{ field }}) as staged_count
    from {{ ref('stg_orders') }}
) as staged
where raw_count != staged_count
{% if not loop.last %}union all{% endif %}
{% endfor %}
