-- Run after building the tables and passing their dbt tests.
-- Existing primary keys and named foreign keys are skipped.
-- Existing definitions are not altered or repaired.

-- 1. Dimension and fact primary keys.
FOR key_definition IN (
    SELECT *
    FROM UNNEST([
        STRUCT('dim_products' AS table_name, 'product_id' AS key_columns),
        STRUCT('dim_sellers', 'seller_id'),
        STRUCT('dim_customers', 'customer_id'),
        STRUCT('dim_date', 'date_key'),
        STRUCT('fact_order_items', 'order_id, order_item_id')
    ])
)
DO
    IF NOT EXISTS (
        SELECT 1
        FROM
            `olist-analytics-508208.olist_dbt_dev.INFORMATION_SCHEMA.TABLE_CONSTRAINTS`
        WHERE table_name = key_definition.table_name
          AND constraint_type = 'PRIMARY KEY'
    ) THEN
        EXECUTE IMMEDIATE FORMAT(
            'ALTER TABLE `olist-analytics-508208.olist_dbt_dev.%s` ADD PRIMARY KEY (%s) NOT ENFORCED',
            key_definition.table_name,
            key_definition.key_columns
        );
    END IF;
END FOR;

-- 2. Fact-to-dimension foreign keys.
FOR relationship IN (
    SELECT *
    FROM UNNEST([
        STRUCT(
            'fk_order_items_product' AS fk_name,
            'product_id' AS fact_column,
            'dim_products' AS dimension_table,
            'product_id' AS dimension_column
        ),
        STRUCT(
            'fk_order_items_seller',
            'seller_id',
            'dim_sellers',
            'seller_id'
        ),
        STRUCT(
            'fk_order_items_customer',
            'customer_id',
            'dim_customers',
            'customer_id'
        ),
        STRUCT(
            'fk_order_items_purchase_date',
            'purchase_date_key',
            'dim_date',
            'date_key'
        ),
        STRUCT(
            'fk_order_items_shipping_date',
            'shipping_limit_date_key',
            'dim_date',
            'date_key'
        )
    ])
)
DO
    IF NOT EXISTS (
        SELECT 1
        FROM
            `olist-analytics-508208.olist_dbt_dev.INFORMATION_SCHEMA.TABLE_CONSTRAINTS`
        WHERE table_name = 'fact_order_items'
          AND constraint_type = 'FOREIGN KEY'
          AND (
              constraint_name = relationship.fk_name
              OR constraint_name = CONCAT(
                  'fact_order_items.',
                  relationship.fk_name
              )
          )
    ) THEN
        EXECUTE IMMEDIATE FORMAT(
            'ALTER TABLE `olist-analytics-508208.olist_dbt_dev.fact_order_items` ADD CONSTRAINT %s FOREIGN KEY (%s) REFERENCES `olist-analytics-508208.olist_dbt_dev.%s` (%s) NOT ENFORCED',
            relationship.fk_name,
            relationship.fact_column,
            relationship.dimension_table,
            relationship.dimension_column
        );
    END IF;
END FOR;

-- 3. Display the resulting constraints.
SELECT
    table_name,
    constraint_name,
    constraint_type,
    enforced
FROM
    `olist-analytics-508208.olist_dbt_dev.INFORMATION_SCHEMA.TABLE_CONSTRAINTS`
WHERE table_name IN (
    'dim_products',
    'dim_sellers',
    'dim_customers',
    'dim_date',
    'fact_order_items'
)
ORDER BY table_name, constraint_type, constraint_name;