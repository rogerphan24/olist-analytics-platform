{{ config(materialized='table') }}

-- Group source items, not product-level distinct order counts.
with totals as (
    select i.purchase_date_key,
        p.product_category_name,
        p.product_category_name_english,
        p.category_translation_status,
        count(distinct i.order_id) as delivered_orders,
        count(distinct i.product_id) as products_sold,
        count(distinct i.seller_id) as selling_sellers,
        sum(i.item_quantity) as delivered_item_quantity,
        sum(i.item_price) as delivered_merchandise_value,
        sum(i.freight_value) as delivered_freight_value,
        sum(i.item_total_value) as delivered_total_item_value,
        sum(if(i.item_price is not null, i.item_quantity, 0)) as item_quantity_with_known_price,
        countif(i.item_price is null) as items_missing_price,
        countif(i.freight_value is null) as items_missing_freight_value,
        countif(i.item_total_value is null) as items_missing_total_value
    from {{ ref('fact_order_items') }} as i
    left join {{ ref('dim_products') }} as p using (product_id)
    where i.order_status = 'delivered'
    group by 1, 2, 3, 4
)
select t.*, d.calendar_date as purchase_date,
    safe_divide(delivered_merchandise_value, item_quantity_with_known_price)
        as average_delivered_item_price
from totals as t
left join {{ ref('dim_date') }} as d on t.purchase_date_key = d.date_key
