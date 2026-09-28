# Dimension design

## Scope and keys

These four dbt table models are rebuilt in the existing
`olist-analytics-508208.olist_dbt_dev` development dataset.
They use existing staging views. No fact models are part of this step.

| Dimension | Grain | Key |
| --- | --- | --- |
| dim_products | One source product with optional English category translation | product_id |
| dim_sellers | One source seller | seller_id |
| dim_customers | One source customer record, preserving its recorded location | customer_id |
| dim_date | One calendar day | date_key (YYYYMMDD); calendar_date is also unique |

Natural source keys are sufficient for these single-source, non-versioned
dimensions. There are no invented historical versions or surrogate SCD keys.
If attribute history becomes available, versioning needs an explicit new design.

## Customer identity

The checked source has 99,441 customer records representing 96,096 distinct
`customer_unique_id` values. Orders join through `customer_id`.
252 distinct customers have multiple recorded location combinations.

Accordingly, dim_customers preserves every customer_id and its own location.
It does not select a latest location, merge customer records, or add order
metrics. Use COUNT(DISTINCT customer_unique_id) for distinct customers;
COUNT(*) counts source customer records, not people.
This is not a slowly changing dimension and the data does not establish an
address's effective start or end date.

## Calendar

The date range covers full years across purchase, approval, carrier delivery,
customer delivery, estimated delivery, item shipping deadline, review creation,
and review answer dates. The checked source produces 2016-01-01 through
2020-12-31 (1,827 days).

Four item records have shipping deadlines in 2019 or later, with a maximum of
2020-04-09 22:35:08. These source anomalies extend the calendar; they are
preserved for later investigation and should not be interpreted as evidence
of sales occurring in 2020.

Weekday numbers are Monday=1 through Sunday=7. ISO weeks must be grouped
with iso_year, not calendar_year. No holiday or fiscal calendar is inferred.
The model fails its nonempty/continuity test if there are no usable source dates.

## Product and seller behaviour

Products use a left join to category translations. Missing categories and
unmapped translations are retained and labelled separately.
The known 13 unmapped products remain in the dimension; they are not a
dimension-test failure.

Seller locations remain at source seller grain. No direct geolocation join
is used, because that source has multiple observations per ZIP prefix and
would multiply dimension rows.

## Validation and reproduction

Validated in BigQuery on 2026-09-28 with dbt 1.12.4 / BigQuery adapter 1.12.0:
4 dimension tables built and 41 data tests passed.
Summary: PASS=45 WARN=0 ERROR=0 SKIP=0 TOTAL=45.

From the repository root in PowerShell:

```powershell
& ".\.venv\Scripts\dbt.exe" build --project-dir ".\transformation\olist_analytics" --select "path:models/marts/dimensions"
```

Checks cover unique/non-null keys, required fields, source relationships,
source-record completeness, exact attribute preservation, translation status,
customer coverage of orders, product/seller coverage of order items, calendar
continuity, date coverage, and derived calendar attributes.

The SQL tests are under ../../../tests and model tests are in the adjacent YAML.
Tests read staging sources but do not create or update any fact models.
