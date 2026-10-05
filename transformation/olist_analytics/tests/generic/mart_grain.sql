{% test mart_grain(model, keys) %}
select {{ keys | join(', ') }}, count(*) as row_count
from {{ model }}
group by {{ keys | join(', ') }}
having count(*) > 1
{% endtest %}
