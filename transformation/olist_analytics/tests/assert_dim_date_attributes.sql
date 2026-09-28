select *
from {{ ref('dim_date') }}
where date_key is distinct from cast(format_date('%Y%m%d', calendar_date) as int64)
   or calendar_year is distinct from extract(year from calendar_date)
   or calendar_quarter is distinct from extract(quarter from calendar_date)
   or month_number is distinct from extract(month from calendar_date)
   or month_name is distinct from format_date('%B', calendar_date)
   or month_start_date is distinct from date_trunc(calendar_date, month)
   or day_of_month is distinct from extract(day from calendar_date)
   or day_of_week_number is distinct from (mod(extract(dayofweek from calendar_date) + 5, 7) + 1)
   or day_name is distinct from format_date('%A', calendar_date)
   or is_weekend is distinct from (extract(dayofweek from calendar_date) in (1, 7))
   or iso_year is distinct from extract(isoyear from calendar_date)
   or iso_week is distinct from extract(isoweek from calendar_date)
