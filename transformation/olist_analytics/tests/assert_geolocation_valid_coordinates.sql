select *
from {{ ref('stg_geolocation') }}
where not (geolocation_lat between -90 and 90)
   or not (geolocation_lng between -180 and 180)
   or is_nan(geolocation_lat)
   or is_nan(geolocation_lng)
   or is_inf(geolocation_lat)
   or is_inf(geolocation_lng)
