# Olist staging layer

## Scope

Nine row-preserving BigQuery views sourced from
`olist-analytics-508208.olist_raw`, built into
`olist-analytics-508208.olist_dbt_dev` using the existing dev profile.
This step covers staging only.

| View | Grain / tested key |
| --- | --- |
| stg_customers | Customer record / customer_id |
| stg_orders | Order / order_id |
| stg_order_items | Order item / order_id + order_item_id |
| stg_order_payments | Payment sequence / order_id + payment_sequential |
| stg_products | Product / product_id |
| stg_sellers | Seller / seller_id |
| stg_order_reviews | Review/order pair / review_id + order_id |
| stg_geolocation | Source location observation; no unique ZIP key |
| stg_product_category_translation | Portuguese category / product_category_name |

## Transformation rules

- Trim identifiers and text; convert blank strings to null.
- Keep ZIP prefixes as strings, including leading zeros.
- Standardize cities and categories to lowercase and states to uppercase.
- Preserve accents and review text; no translation or entity resolution.
- Use INT64 for counts, NUMERIC for money and measurements, FLOAT64 for coordinates.
- Use DATETIME for timezone-unspecified source dates. Order date columns previously
  used TIMESTAMP; they now retain the recorded clock time without assuming UTC.
- Use strict casts: invalid nonblank numeric/date values fail validation.
- Correct product_name_lenght and product_description_lenght to
  product_name_length and product_description_length.
- Preserve all source rows, including repeated geolocation observations and
  multiple reviews per order. A ZIP lookup or review consolidation is future work.
- Preserve missing product attributes and optional review text.

## Validation on 2026-09-20

Live BigQuery build: 9 views succeeded.
59 staging tests were executed across the build and two final targeted checks:
58 passed, 1 warned, 0 failed, 0 errors.
The four generated dbt example tests and two example models were excluded.

Coverage includes required fields, single/composite keys, relationships,
review scores, numeric ranges, coordinates, ZIP/state formats, order datetime
completeness, and raw-to-staging row-count reconciliation for all nine sources.

Commands, from the repository root in PowerShell:

```powershell
& ".\.venv\Scripts\dbt.exe" build --project-dir ".\transformation\olist_analytics" --select "path:models/staging"
```

With all current tests present, the expected summary is:
`PASS=67 WARN=1 ERROR=0 TOTAL=68` (9 models plus 59 tests).
Counts can change when tests or source data change.

## Known source limitations

- Products: 32,951 rows and unique product IDs. 610 products have no category.
  Two products have missing weight; zero weight exists. These source values
  remain visible rather than being imputed or dropped.
- Category coverage: 13 products lack a translation across two categories:
  `portateis_cozinha_e_preparadores_de_alimentos` (10) and `pc_gamer` (3).
  The products-to-translation relationship test explicitly warns.
  Use a left join downstream and decide on a labelled fallback then.
- Reviews: 99,224 rows, 98,410 distinct review IDs, and no duplicated
  review/order pairs. 58,274 rows have no comment message.
  Do not assume review_id or order_id alone is unique.
- Geolocation: 1,000,163 rows across 19,015 ZIP prefixes.
  Direct joins on ZIP prefix can multiply customer/seller rows.
  Build an explicit one-row-per-ZIP model before such joins.
- This historical dataset has no ingestion timestamp in the provided schemas;
  no freshness SLA is asserted.

## Evidence and maintenance

Schemas and aggregate profiles were read directly from the five remaining raw
tables in project olist-analytics-508208, location asia-southeast1.
Executable quality checks are the adjacent YAML files and SQL under ../../tests.
Build evidence is in the local ignored logs/dbt.log; dbt overwrites
target/run_results.json on subsequent invocations.

The staging completion also corrected the payments not-null test typo,
the item-model TRIM expressions, and customer location casing.
No source rows were deleted and no downstream marts, automation, analytics,
or data-science components were created.
