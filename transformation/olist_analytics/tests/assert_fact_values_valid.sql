select 'fact_order_items' as model_name, order_id
from {{ ref('fact_order_items') }}
where order_item_id < 1 or item_price is null or item_price < 0
   or freight_value is null or freight_value < 0 or item_quantity is distinct from 1
union all
select 'fact_order_payments', order_id
from {{ ref('fact_order_payments') }}
where payment_sequential < 1 or payment_installments < 0 or payment_value < 0
union all
select 'fact_orders', order_id
from {{ ref('fact_orders') }}
where item_count < 0 or order_count is distinct from 1
   or (item_count = 0 and (merchandise_value is not null or freight_value is not null or order_total_value is not null))
   or (item_count > 0 and (merchandise_value is null or freight_value is null or order_total_value is null))
   or merchandise_value < 0 or freight_value < 0 or order_total_value < 0
