{% test mart_rules(model, rules) %}
select * from {{ model }}
where
{% for rule in rules %}
    not coalesce(({{ rule }}), false) {% if not loop.last %} or {% endif %}
{% endfor %}
{% endtest %}
