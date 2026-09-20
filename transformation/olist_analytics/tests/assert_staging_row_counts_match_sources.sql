-- Staging is row-preserving: do not silently deduplicate or drop source records.
{% set tables = ['customers', 'orders', 'order_items', 'order_payments',
                 'products', 'sellers', 'order_reviews', 'geolocation',
                 'product_category_translation'] %}
{% for table in tables %}
select '{{ table }}' as source_table, source_count, staging_count
from (select count(*) as source_count from {{ source('olist', table) }}) as raw
cross join (select count(*) as staging_count from {{ ref('stg_' ~ table) }}) as staged
where source_count != staging_count
{% if not loop.last %}union all{% endif %}
{% endfor %}
