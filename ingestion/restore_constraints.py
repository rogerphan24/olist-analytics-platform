import time
from pathlib import Path

from google.cloud import bigquery


PROJECT = "olist-analytics-508208"
DATASET = "olist_dbt_dev"
LOCATION = "asia-southeast1"
SQL_FILE = Path(
    "/opt/dbt/project/sql/constraints/all_fact_constraints.sql"
)

PRIMARY_KEYS = {
    "dim_products": ["product_id"],
    "dim_sellers": ["seller_id"],
    "dim_customers": ["customer_id"],
    "dim_date": ["date_key"],
    "fact_orders": ["order_id"],
    "fact_order_items": ["order_id", "order_item_id"],
    "fact_order_payments": ["order_id", "payment_sequential"],
    "fact_order_reviews": ["review_id", "order_id"],
}

# source table, constraint name, source column, target table, target column
FOREIGN_KEYS = [
    ("fact_order_items", "fk_order_items_product",
     "product_id", "dim_products", "product_id"),
    ("fact_order_items", "fk_order_items_seller",
     "seller_id", "dim_sellers", "seller_id"),
    ("fact_order_items", "fk_order_items_customer",
     "customer_id", "dim_customers", "customer_id"),
    ("fact_order_items", "fk_order_items_purchase_date",
     "purchase_date_key", "dim_date", "date_key"),
    ("fact_order_items", "fk_order_items_shipping_date",
     "shipping_limit_date_key", "dim_date", "date_key"),
    ("fact_order_items", "fk_order_items_order",
     "order_id", "fact_orders", "order_id"),
    ("fact_orders", "fk_orders_customer",
     "customer_id", "dim_customers", "customer_id"),
    ("fact_orders", "fk_orders_purchase_date",
     "purchase_date_key", "dim_date", "date_key"),
    ("fact_orders", "fk_orders_approved_date",
     "approved_date_key", "dim_date", "date_key"),
    ("fact_orders", "fk_orders_carrier_delivery_date",
     "carrier_delivery_date_key", "dim_date", "date_key"),
    ("fact_orders", "fk_orders_customer_delivery_date",
     "customer_delivery_date_key", "dim_date", "date_key"),
    ("fact_orders", "fk_orders_estimated_delivery_date",
     "estimated_delivery_date_key", "dim_date", "date_key"),
    ("fact_order_payments", "fk_payments_order",
     "order_id", "fact_orders", "order_id"),
    ("fact_order_payments", "fk_payments_customer",
     "customer_id", "dim_customers", "customer_id"),
    ("fact_order_payments", "fk_payments_purchase_date",
     "purchase_date_key", "dim_date", "date_key"),
    ("fact_order_reviews", "fk_reviews_order",
     "order_id", "fact_orders", "order_id"),
    ("fact_order_reviews", "fk_reviews_customer",
     "customer_id", "dim_customers", "customer_id"),
    ("fact_order_reviews", "fk_reviews_purchase_date",
     "purchase_date_key", "dim_date", "date_key"),
    ("fact_order_reviews", "fk_reviews_creation_date",
     "review_creation_date_key", "dim_date", "date_key"),
    ("fact_order_reviews", "fk_reviews_answer_date",
     "review_answer_date_key", "dim_date", "date_key"),
]


def verify(client, require_all):
    missing = []

    for table_name, expected_pk in PRIMARY_KEYS.items():
        table = client.get_table(
            f"{PROJECT}.{DATASET}.{table_name}"
        )
        constraints = table.to_api_repr().get("tableConstraints", {})

        actual_pk = constraints.get("primaryKey", {}).get("columns")
        if actual_pk is None:
            missing.append(f"{table_name}: primary key")
        elif actual_pk != expected_pk:
            raise RuntimeError(
                f"{table_name}: incorrect primary key {actual_pk}"
            )

        expected_fks = {
            name: (column, target, target_column)
            for source, name, column, target, target_column in FOREIGN_KEYS
            if source == table_name
        }
        actual_fks = {
            fk["name"].rsplit(".", 1)[-1]: fk
            for fk in constraints.get("foreignKeys", [])
        }

        unexpected = set(actual_fks) - set(expected_fks)
        if unexpected:
            raise RuntimeError(
                f"{table_name}: unexpected foreign keys {sorted(unexpected)}"
            )

        for name, (column, target, target_column) in expected_fks.items():
            actual = actual_fks.get(name)
            if actual is None:
                missing.append(f"{table_name}: {name}")
                continue

            expected_table = {
                "projectId": PROJECT,
                "datasetId": DATASET,
                "tableId": target,
            }
            expected_columns = [{
                "referencingColumn": column,
                "referencedColumn": target_column,
            }]

            if (
                actual["referencedTable"] != expected_table
                or actual["columnReferences"] != expected_columns
            ):
                raise RuntimeError(
                    f"{table_name}: incorrect foreign key {name}"
                )

    return not missing if require_all else True


def main():
    sql = SQL_FILE.read_text(encoding="utf-8-sig")
    client = bigquery.Client(project=PROJECT)

    # Reject conflicting definitions before applying the canonical SQL.
    verify(client, require_all=False)

    job = client.query(
        sql,
        location=LOCATION,
        job_config=bigquery.QueryJobConfig(
            maximum_bytes_billed=1_000_000_000
        ),
    )
    job.result()

    for attempt in range(4):
        if verify(client, require_all=True):
            print(
                "CONSTRAINTS VERIFIED: 8 primary keys and "
                f"20 foreign keys. Job: {job.job_id}",
                flush=True,
            )
            return

        if attempt < 3:
            time.sleep(2)

    raise RuntimeError(
        "Some constraints remain missing after metadata refresh."
    )


if __name__ == "__main__":
    main()