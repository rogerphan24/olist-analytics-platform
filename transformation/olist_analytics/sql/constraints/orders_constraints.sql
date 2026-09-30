-- Run after the tables are built and their dbt tests pass.
-- Existing declarations are skipped, not altered or repaired.

-- 1. Required primary keys.
FOR key_definition IN (
    SELECT *
    FROM UNNEST([
        STRUCT('dim_customers' AS table_name, 'customer_id' AS key_column),
        STRUCT('dim_date', 'date_key'),
        STRUCT('fact_orders', 'order_id')
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
            key_definition.key_column
        );
    END IF;
END FOR;

-- 2. Customer and date relationships.
FOR relationship IN (
    SELECT *
    FROM UNNEST([
        STRUCT(
            'fk_orders_customer' AS fk_name,
            'customer_id' AS fact_column,
            'dim_customers' AS dimension_table,
            'customer_id' AS dimension_column
        ),
        STRUCT(
            'fk_orders_purchase_date',
            'purchase_date_key',
            'dim_date',
            'date_key'
        ),
        STRUCT(
            'fk_orders_approved_date',
            'approved_date_key',
            'dim_date',
            'date_key'
        ),
        STRUCT(
            'fk_orders_carrier_delivery_date',
            'carrier_delivery_date_key',
            'dim_date',
            'date_key'
        ),
        STRUCT(
            'fk_orders_customer_delivery_date',
            'customer_delivery_date_key',
            'dim_date',
            'date_key'
        ),
        STRUCT(
            'fk_orders_estimated_delivery_date',
            'estimated_delivery_date_key',
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
        WHERE table_name = 'fact_orders'
          AND constraint_type = 'FOREIGN KEY'
          AND (
              constraint_name = relationship.fk_name
              OR constraint_name = CONCAT(
                  'fact_orders.',
                  relationship.fk_name
              )
          )
    ) THEN
        EXECUTE IMMEDIATE FORMAT(
            'ALTER TABLE `olist-analytics-508208.olist_dbt_dev.fact_orders` ADD CONSTRAINT %s FOREIGN KEY (%s) REFERENCES `olist-analytics-508208.olist_dbt_dev.%s` (%s) NOT ENFORCED',
            relationship.fk_name,
            relationship.fact_column,
            relationship.dimension_table,
            relationship.dimension_column
        );
    END IF;
END FOR;

-- 3. Verify the fact table's constraints.
SELECT
    table_name,
    constraint_name,
    constraint_type,
    enforced
FROM
    `olist-analytics-508208.olist_dbt_dev.INFORMATION_SCHEMA.TABLE_CONSTRAINTS`
WHERE table_name = 'fact_orders'
ORDER BY constraint_type, constraint_name;