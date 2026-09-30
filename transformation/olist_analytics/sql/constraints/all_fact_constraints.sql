-- Canonical constraint script for all four facts.
-- Execute only after fact and dimension tests succeed.
-- NOT ENFORCED: data integrity remains the responsibility of dbt tests.
-- Existing declarations are skipped. build_facts.ps1 verifies exact definitions
-- using fresh table metadata before and after execution.

DECLARE foreign_key_ddl STRING;

FOR definition IN (
    SELECT * FROM UNNEST([
        STRUCT('dim_products' AS table_name, 'product_id' AS key_columns),
        STRUCT('dim_sellers', 'seller_id'),
        STRUCT('dim_customers', 'customer_id'),
        STRUCT('dim_date', 'date_key'),
        STRUCT('fact_orders', 'order_id'),
        STRUCT('fact_order_items', 'order_id, order_item_id'),
        STRUCT('fact_order_payments', 'order_id, payment_sequential'),
        STRUCT('fact_order_reviews', 'review_id, order_id')
    ])
) DO
    IF NOT EXISTS (
        SELECT 1
        FROM `olist-analytics-508208.olist_dbt_dev.INFORMATION_SCHEMA.TABLE_CONSTRAINTS`
        WHERE table_name = definition.table_name AND constraint_type = 'PRIMARY KEY'
    ) THEN
        EXECUTE IMMEDIATE FORMAT(
            'ALTER TABLE `olist-analytics-508208.olist_dbt_dev.%s` ADD PRIMARY KEY (%s) NOT ENFORCED',
            definition.table_name, definition.key_columns
        );
    END IF;
END FOR;

-- Batch foreign keys per table to avoid BigQuery table-update rate limits.
FOR fact_table IN (
    SELECT table_name,
        ARRAY_AGG(STRUCT(fk_name, fact_column, dimension_table, dimension_column)) AS relationships
    FROM UNNEST([
        STRUCT('fact_order_items' AS table_name, 'fk_order_items_product' AS fk_name, 'product_id' AS fact_column, 'dim_products' AS dimension_table, 'product_id' AS dimension_column),
        STRUCT('fact_order_items', 'fk_order_items_seller', 'seller_id', 'dim_sellers', 'seller_id'),
        STRUCT('fact_order_items', 'fk_order_items_customer', 'customer_id', 'dim_customers', 'customer_id'),
        STRUCT('fact_order_items', 'fk_order_items_purchase_date', 'purchase_date_key', 'dim_date', 'date_key'),
        STRUCT('fact_order_items', 'fk_order_items_shipping_date', 'shipping_limit_date_key', 'dim_date', 'date_key'),
        STRUCT('fact_order_items', 'fk_order_items_order', 'order_id', 'fact_orders', 'order_id'),
        STRUCT('fact_orders', 'fk_orders_customer', 'customer_id', 'dim_customers', 'customer_id'),
        STRUCT('fact_orders', 'fk_orders_purchase_date', 'purchase_date_key', 'dim_date', 'date_key'),
        STRUCT('fact_orders', 'fk_orders_approved_date', 'approved_date_key', 'dim_date', 'date_key'),
        STRUCT('fact_orders', 'fk_orders_carrier_delivery_date', 'carrier_delivery_date_key', 'dim_date', 'date_key'),
        STRUCT('fact_orders', 'fk_orders_customer_delivery_date', 'customer_delivery_date_key', 'dim_date', 'date_key'),
        STRUCT('fact_orders', 'fk_orders_estimated_delivery_date', 'estimated_delivery_date_key', 'dim_date', 'date_key'),
        STRUCT('fact_order_payments', 'fk_payments_order', 'order_id', 'fact_orders', 'order_id'),
        STRUCT('fact_order_payments', 'fk_payments_customer', 'customer_id', 'dim_customers', 'customer_id'),
        STRUCT('fact_order_payments', 'fk_payments_purchase_date', 'purchase_date_key', 'dim_date', 'date_key'),
        STRUCT('fact_order_reviews', 'fk_reviews_order', 'order_id', 'fact_orders', 'order_id'),
        STRUCT('fact_order_reviews', 'fk_reviews_customer', 'customer_id', 'dim_customers', 'customer_id'),
        STRUCT('fact_order_reviews', 'fk_reviews_purchase_date', 'purchase_date_key', 'dim_date', 'date_key'),
        STRUCT('fact_order_reviews', 'fk_reviews_creation_date', 'review_creation_date_key', 'dim_date', 'date_key'),
        STRUCT('fact_order_reviews', 'fk_reviews_answer_date', 'review_answer_date_key', 'dim_date', 'date_key')
    ])
    GROUP BY table_name
) DO
    SET foreign_key_ddl = (
        SELECT STRING_AGG(FORMAT(
            'ADD CONSTRAINT %s FOREIGN KEY (%s) REFERENCES `olist-analytics-508208.olist_dbt_dev.%s` (%s) NOT ENFORCED',
            relationship.fk_name, relationship.fact_column,
            relationship.dimension_table, relationship.dimension_column
        ), ', ')
        FROM UNNEST(fact_table.relationships) AS relationship
        LEFT JOIN (
            SELECT constraint_name,
                REGEXP_REPLACE(constraint_name, r'^[^.]+\.', '') AS fk_name
            FROM `olist-analytics-508208.olist_dbt_dev.INFORMATION_SCHEMA.TABLE_CONSTRAINTS`
            WHERE table_name = fact_table.table_name
              AND constraint_type = 'FOREIGN KEY'
        ) AS existing
          ON relationship.fk_name = existing.fk_name
        WHERE existing.constraint_name IS NULL
    );
    IF foreign_key_ddl IS NOT NULL THEN
        EXECUTE IMMEDIATE FORMAT(
            'ALTER TABLE `olist-analytics-508208.olist_dbt_dev.%s` %s',
            fact_table.table_name, foreign_key_ddl
        );
    END IF;
END FOR;

SELECT table_name, constraint_name, constraint_type, enforced
FROM `olist-analytics-508208.olist_dbt_dev.INFORMATION_SCHEMA.TABLE_CONSTRAINTS`
WHERE table_name IN ('dim_products', 'dim_sellers', 'dim_customers', 'dim_date',
                     'fact_orders', 'fact_order_items', 'fact_order_payments', 'fact_order_reviews')
ORDER BY table_name, constraint_type, constraint_name;
