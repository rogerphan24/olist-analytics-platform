{% set locations = [('stg_customers', 'customer'), ('stg_sellers', 'seller'),
                    ('stg_geolocation', 'geolocation')] %}
{% for model, prefix in locations %}
select '{{ model }}' as model_name,
       {{ prefix }}_zip_code_prefix as zip_code_prefix,
       {{ prefix }}_state as state
from {{ ref(model) }}
where not regexp_contains({{ prefix }}_zip_code_prefix, r'^[0-9]{5}$')
   or {{ prefix }}_state not in (
       'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO',
       'MA', 'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI',
       'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO'
   )
{% if not loop.last %}union all{% endif %}
{% endfor %}
