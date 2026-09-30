# Olist fact layer

## Grain and measures

| Table | Row grain / primary key | Measures |
| --- | --- | --- |
| fact_orders | order_id | order_count, item_count, merchandise_value, freight_value, order_total_value, delivery_days, delivery_delay_days |
| fact_order_items | order_id + order_item_id | item_quantity, item_price, freight_value, item_total_value |
| fact_order_payments | order_id + payment_sequential | payment_value, payment_installments, payment_record_count |
| fact_order_reviews | review_id + order_id | review_score, review_count |

All four are dbt tables in olist-analytics-508208.olist_dbt_dev.
Keys and identifiers retain the staging types. Date keys use INT64 YYYYMMDD
and reference dim_date. Recorded datetimes use DATETIME without an inferred
timezone; money uses NUMERIC. SQL and adjacent YAML define each column.

## Analytical rules

- Orders are preserved even without item records: item_count is zero and
  merchandise/freight/total amounts remain NULL rather than becoming invented zeros.
- Order totals aggregate items before joining. Item totals and order totals
  describe the same amounts at different grains; never add them together.
- Payments preserve source amounts. Do not multiply payment_value by
  payment_installments. There is no payment timestamp in the source:
  purchase_date_key refers to the associated order.
- Payment totals are not forced to equal item plus freight totals. Any
  differences require separate business reconciliation, not silent adjustment.
- Reviews retain all review/order pairs and optional text. review_id alone is
  not unique. Reviews are order-level and are not attributed to every product
  or seller within the order.
- Delivery metrics count calendar days. Negative delay means early delivery.
  Missing delivery milestones retain NULL metrics; source anomalies are
  preserved, not clipped to zero.
- Status filters must be explicit before interpreting values as sales or revenue.
- customer_id joins to the source-record customer dimension. Use distinct
  customer_unique_id for distinct people.
- Child facts link to fact_orders for referential integrity, but these FK
  declarations do not make a raw items/payments/reviews join safe.
  Aggregate each child to the intended grain before combining measures.

## Build, test and constraints

From the repository root in PowerShell:

```powershell
& ".\scripts\build_facts.ps1"
```

The command:

1. Tests the existing dimension tables without rebuilding them.
2. Builds only the four fact models and runs their tests.
3. Applies sql/constraints/all_fact_constraints.sql within the dbt project.
4. Confirms 28 key declarations: 8 primary keys and 20 foreign keys.

It stops on dbt errors before applying constraints. This helper is scoped to
the existing dev profile/project/dataset; change both the helper and SQL before
using another environment. Dimensions and staging must already exist.

BigQuery constraints are NOT ENFORCED. Test results establish their validity.
The canonical SQL adds missing declarations. The helper checks existing key
columns and referenced tables through fresh table metadata before and after
applying the SQL. Rerunning it preserves matching definitions and stops on
mismatches instead of overwriting them.

The earlier order_items_constraints.sql and orders_constraints.sql are retained
as individual-table examples. Use all_fact_constraints.sql for the complete
layer. A plain dbt rebuild can remove declarations; use the helper to restore
them after validation. This is a local build helper, not an Airflow schedule.

## Validation

Initial full fact build on 2026-09-30:
4 fact tables built and 68 data tests passed; PASS=72 WARN=0 ERROR=0.
The build helper also passed all 41 dimension checks. Fresh table metadata
verified 8 primary keys and 20 foreign keys with their exact column mappings.
Foreign-key additions are batched per table to respect metadata update limits.

| Table | Verified rows |
| --- | ---: |
| fact_orders | 99,441 |
| fact_order_items | 112,650 |
| fact_order_payments | 103,886 |
| fact_order_reviews | 99,224 |

Checks include unique/non-null keys, dimension and order relationships,
row-level source reconciliation, source attribute preservation, date-key
mapping, delivery calculations, measure ranges, review scores and record counts.
The matching source reconciliation and uniqueness tests together ensure
joins have neither lost nor duplicated source records.

Build details remain in local ignored logs/dbt.log and target/run_results.json.
This step adds no marts, dashboards, orchestration service or predictive model.
