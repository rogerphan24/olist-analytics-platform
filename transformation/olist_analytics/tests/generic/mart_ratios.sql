{% test mart_ratios(model, ratios) %}
select * from {{ model }}
where
{% for name, parts in ratios.items() %}
    {{ name }} is distinct from safe_divide({{ parts[0] }}, {{ parts[1] }})
    {% if not loop.last %} or {% endif %}
{% endfor %}
{% endtest %}
