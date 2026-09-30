# Build/test facts, then restore and verify their BigQuery key declarations.
# Dimensions must already exist. Fixed to the existing development dataset.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$dbtProject = Join-Path $repoRoot 'transformation\olist_analytics'
$dbtExe = Join-Path $repoRoot '.venv\Scripts\dbt.exe'
$pythonExe = Join-Path $repoRoot '.venv\Scripts\python.exe'
$constraintSql = Join-Path $dbtProject 'sql\constraints\all_fact_constraints.sql'

& $dbtExe test --project-dir $dbtProject --target dev --select 'path:models/marts/dimensions' --indirect-selection buildable
if ($LASTEXITCODE -ne 0) { throw 'Dimension validation failed; fact build stopped.' }

& $dbtExe build --project-dir $dbtProject --target dev --select 'path:models/marts/facts'
if ($LASTEXITCODE -ne 0) { throw 'Fact validation failed; constraints were not applied.' }

$previousEncoding = $OutputEncoding
try {
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $applySql = @'
import sys
import time
from google.cloud import bigquery
client = bigquery.Client(project="olist-analytics-508208")
primary_keys = {"dim_products":["product_id"],"dim_sellers":["seller_id"],"dim_customers":["customer_id"],"dim_date":["date_key"],"fact_orders":["order_id"],"fact_order_items":["order_id","order_item_id"],"fact_order_payments":["order_id","payment_sequential"],"fact_order_reviews":["review_id","order_id"]}
foreign_keys = [["fact_order_items","fk_order_items_product","product_id","dim_products","product_id"],["fact_order_items","fk_order_items_seller","seller_id","dim_sellers","seller_id"],["fact_order_items","fk_order_items_customer","customer_id","dim_customers","customer_id"],["fact_order_items","fk_order_items_purchase_date","purchase_date_key","dim_date","date_key"],["fact_order_items","fk_order_items_shipping_date","shipping_limit_date_key","dim_date","date_key"],["fact_order_items","fk_order_items_order","order_id","fact_orders","order_id"],["fact_orders","fk_orders_customer","customer_id","dim_customers","customer_id"],["fact_orders","fk_orders_purchase_date","purchase_date_key","dim_date","date_key"],["fact_orders","fk_orders_approved_date","approved_date_key","dim_date","date_key"],["fact_orders","fk_orders_carrier_delivery_date","carrier_delivery_date_key","dim_date","date_key"],["fact_orders","fk_orders_customer_delivery_date","customer_delivery_date_key","dim_date","date_key"],["fact_orders","fk_orders_estimated_delivery_date","estimated_delivery_date_key","dim_date","date_key"],["fact_order_payments","fk_payments_order","order_id","fact_orders","order_id"],["fact_order_payments","fk_payments_customer","customer_id","dim_customers","customer_id"],["fact_order_payments","fk_payments_purchase_date","purchase_date_key","dim_date","date_key"],["fact_order_reviews","fk_reviews_order","order_id","fact_orders","order_id"],["fact_order_reviews","fk_reviews_customer","customer_id","dim_customers","customer_id"],["fact_order_reviews","fk_reviews_purchase_date","purchase_date_key","dim_date","date_key"],["fact_order_reviews","fk_reviews_creation_date","review_creation_date_key","dim_date","date_key"],["fact_order_reviews","fk_reviews_answer_date","review_answer_date_key","dim_date","date_key"]]
def verify(require_all):
    total = 0
    for table_name, columns in primary_keys.items():
        metadata = client.get_table("olist-analytics-508208.olist_dbt_dev." + table_name).to_api_repr().get("tableConstraints", {})
        actual_pk = metadata.get("primaryKey", {}).get("columns")
        if actual_pk is not None and actual_pk != columns:
            raise RuntimeError(f"Incorrect primary key: {table_name}: {actual_pk}")
        if require_all and actual_pk is None:
            return False
        total += int(actual_pk is not None)
        actual_fks = {f["name"]: f for f in metadata.get("foreignKeys", [])}
        total += len(actual_fks)
        for source, name, column, target, target_column in foreign_keys:
            if source != table_name:
                continue
            actual = actual_fks.get(name)
            if actual is None:
                if require_all:
                    return False
                continue
            expected_table = {"projectId": "olist-analytics-508208", "datasetId": "olist_dbt_dev", "tableId": target}
            expected_columns = [{"referencingColumn": column, "referencedColumn": target_column}]
            if actual["referencedTable"] != expected_table or actual["columnReferences"] != expected_columns:
                raise RuntimeError(f"Incorrect foreign key: {source}.{name}")
    if require_all and total != 28:
        raise RuntimeError(f"Expected 28 constraints, found {total}")
    return True
verify(False)
job = client.query(sys.stdin.read(), location="asia-southeast1",
                   job_config=bigquery.QueryJobConfig(maximum_bytes_billed=1000000000))
list(job.result())
for attempt in range(4):
    if verify(True):
        print(f"Verified all 8 primary keys and 20 foreign keys; job {job.job_id}")
        break
    if attempt == 3:
        raise RuntimeError("Missing constraints after metadata refresh")
    time.sleep(2)
'@
    Get-Content -LiteralPath $constraintSql -Raw | & $pythonExe -c $applySql
    if ($LASTEXITCODE -ne 0) { throw 'Constraint application or verification failed.' }
}
finally {
    $OutputEncoding = $previousEncoding
}
