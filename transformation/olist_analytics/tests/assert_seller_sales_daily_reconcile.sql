with expected as (

    select
        purchase_date_key,
        seller_id,

        count(distinct order_id) as delivered_orders,
        count(distinct product_id) as products_sold,
        sum(item_quantity) as delivered_item_quantity,

        sum(item_price) as delivered_merchandise_value,
        sum(freight_value) as delivered_freight_value,
        sum(item_total_value) as delivered_total_item_value,

        sum(if(
            item_price is not null, item_quantity, 0
        )) as item_quantity_with_known_price,

        safe_divide(
            sum(item_price),
            sum(if(item_price is not null, item_quantity, 0))
        ) as average_delivered_item_price,

        countif(item_price is null) as items_missing_price,
        countif(freight_value is null) as items_missing_freight_value,
        countif(item_total_value is null) as items_missing_total_value

    from {{ ref('fact_order_items') }}

    where order_status = 'delivered'

    group by purchase_date_key, seller_id

),

actual as (

    select *
    from {{ ref('mart_seller_sales_daily') }}

),

mismatches as (

    select
        coalesce(e.purchase_date_key, a.purchase_date_key)
            as purchase_date_key,
        coalesce(e.seller_id, a.seller_id) as seller_id,
        'source_mismatch' as failure_reason

    from expected as e

    full outer join actual as a
        on e.purchase_date_key = a.purchase_date_key
        and e.seller_id = a.seller_id

    where
        e.seller_id is null
        or a.seller_id is null

        {% set metrics = [
            'delivered_orders',
            'products_sold',
            'delivered_item_quantity',
            'delivered_merchandise_value',
            'delivered_freight_value',
            'delivered_total_item_value',
            'item_quantity_with_known_price',
            'average_delivered_item_price',
            'items_missing_price',
            'items_missing_freight_value',
            'items_missing_total_value'
        ] %}

        {% for metric in metrics %}
        or e.{{ metric }} is distinct from a.{{ metric }}
        {% endfor %}

),

duplicate_keys as (

    select
        purchase_date_key,
        seller_id,
        'duplicate_grain' as failure_reason

    from actual

    group by purchase_date_key, seller_id
    having count(*) > 1

)

select * from mismatches
union all
select * from duplicate_keys