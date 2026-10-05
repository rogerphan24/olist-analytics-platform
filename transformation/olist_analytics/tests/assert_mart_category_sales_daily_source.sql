-- Recompute expected metrics from the authoritative fact/dimension inputs.
with expected as (
select i.purchase_date_key,p.product_category_name,p.product_category_name_english,p.category_translation_status,
count(distinct i.order_id) as delivered_orders,count(distinct i.product_id) as products_sold,
count(distinct i.seller_id) as selling_sellers,sum(item_quantity) as delivered_item_quantity,
sum(item_price) as delivered_merchandise_value,sum(freight_value) as delivered_freight_value,
sum(item_total_value) as delivered_total_item_value,
sum(if(item_price is not null,item_quantity,0)) as item_quantity_with_known_price,
countif(item_price is null) as items_missing_price,countif(freight_value is null) as items_missing_freight_value,
countif(item_total_value is null) as items_missing_total_value
from {{ ref('fact_order_items') }} i
left join {{ ref('dim_products') }} p using(product_id)
where i.order_status='delivered' group by 1,2,3,4
), actual as (
select purchase_date_key, product_category_name, product_category_name_english, category_translation_status, delivered_orders, products_sold, selling_sellers, delivered_item_quantity, delivered_merchandise_value, delivered_freight_value, delivered_total_item_value, item_quantity_with_known_price, items_missing_price, items_missing_freight_value, items_missing_total_value from {{ ref('mart_category_sales_daily') }}
), missing_or_different as (
select purchase_date_key, product_category_name, product_category_name_english, category_translation_status, delivered_orders, products_sold, selling_sellers, delivered_item_quantity, delivered_merchandise_value, delivered_freight_value, delivered_total_item_value, item_quantity_with_known_price, items_missing_price, items_missing_freight_value, items_missing_total_value from expected
except distinct
select * from actual
), unexpected as (
select * from actual
except distinct
select purchase_date_key, product_category_name, product_category_name_english, category_translation_status, delivered_orders, products_sold, selling_sellers, delivered_item_quantity, delivered_merchandise_value, delivered_freight_value, delivered_total_item_value, item_quantity_with_known_price, items_missing_price, items_missing_freight_value, items_missing_total_value from expected
)
select * from missing_or_different
union all
select * from unexpected
