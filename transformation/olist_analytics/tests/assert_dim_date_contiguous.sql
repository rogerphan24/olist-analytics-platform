-- Uniqueness is checked separately; this also fails for an empty calendar.
select min(calendar_date) as first_date, max(calendar_date) as last_date,
       count(*) as actual_days
from {{ ref('dim_date') }}
having count(*) = 0
    or count(*) != date_diff(max(calendar_date), min(calendar_date), day) + 1
    or extract(dayofyear from min(calendar_date)) != 1
    or format_date('%m-%d', max(calendar_date)) != '12-31'
