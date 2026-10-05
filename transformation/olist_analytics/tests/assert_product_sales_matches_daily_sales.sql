with product_totals as (

    select
        purchase_date_key,
        sum(delivered_item_quantity) as delivered_item_quantity,
        sum(delivered_merchandise_value) as delivered_merchandise_value,
        sum(delivered_freight_value) as delivered_freight_value,
        sum(delivered_total_item_value) as delivered_total_order_value

    from {{ ref('mart_product_sales_daily') }}

    group by purchase_date_key

),

daily_sales as (

    select *
    from {{ ref('mart_daily_sales') }}
    where delivered_orders > 0

)

select
    coalesce(p.purchase_date_key, d.purchase_date_key)
        as purchase_date_key

from product_totals as p

full outer join daily_sales as d
    on p.purchase_date_key = d.purchase_date_key

where
    p.purchase_date_key is null
    or d.purchase_date_key is null
    or p.delivered_item_quantity
        is distinct from d.delivered_item_quantity
    or p.delivered_merchandise_value
        is distinct from d.delivered_merchandise_value
    or p.delivered_freight_value
        is distinct from d.delivered_freight_value
    or p.delivered_total_order_value
        is distinct from d.delivered_total_order_value