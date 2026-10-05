{{ config(materialized='table') }}

with delivered_items as (

    select
        purchase_date_key,
        product_id,
        order_id,
        item_quantity,
        item_price,
        freight_value,
        item_total_value

    from {{ ref('fact_order_items') }}

    where order_status = 'delivered'

),

daily_product_totals as (

    select
        purchase_date_key,
        product_id,

        count(distinct order_id) as delivered_orders,
        sum(item_quantity) as delivered_item_quantity,

        sum(item_price) as delivered_merchandise_value,
        sum(freight_value) as delivered_freight_value,
        sum(item_total_value) as delivered_total_item_value,

        sum(
            case when item_price is not null
                then item_quantity
                else 0
            end
        ) as item_quantity_with_known_price,

        countif(item_price is null) as items_missing_price,
        countif(freight_value is null) as items_missing_freight_value,
        countif(item_total_value is null) as items_missing_total_value

    from delivered_items

    group by
        purchase_date_key,
        product_id

)

select
    t.purchase_date_key,
    d.calendar_date as purchase_date,
    d.calendar_year,
    d.calendar_quarter,
    d.month_number,
    d.month_start_date,

    t.product_id,

    t.delivered_orders,
    t.delivered_item_quantity,
    t.delivered_merchandise_value,
    t.delivered_freight_value,
    t.delivered_total_item_value,

    t.item_quantity_with_known_price,

    safe_divide(
        t.delivered_merchandise_value,
        t.item_quantity_with_known_price
    ) as average_delivered_item_price,

    t.items_missing_price,
    t.items_missing_freight_value,
    t.items_missing_total_value

from daily_product_totals as t

left join {{ ref('dim_date') }} as d
    on t.purchase_date_key = d.date_key