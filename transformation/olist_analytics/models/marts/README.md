# Reporting marts

All models are dbt-managed tables in `olist-analytics-508208.olist_dbt_dev`.
Only dates with qualifying source rows are emitted; no artificial calendar zero-fill.

| Model | Grain | Purpose |
|---|---|---|
| mart_daily_sales | Purchase date | Orders, delivered sales, freight share, customer/product/seller counts, item price |
| mart_product_sales_daily | Purchase date + product | Delivered product sales and item-price coverage |
| mart_seller_sales_daily | Purchase date + seller | Delivered seller sales and distinct products |
| mart_category_sales_daily | Purchase date + source category + translation status | Category sales; preserves missing and unmapped categories |
| mart_delivery_daily | Purchase date, delivered orders only | Duration, punctuality, lateness, missing/invalid date coverage |
| mart_payments_daily | Purchase date + order status + payment type | Recorded payments, payment mix, declared credit-card installments |
| mart_order_quality_daily | Purchase date + order status | Missing items/payments and payment-to-order reconciliation |
| mart_reviews_daily | Purchase date + order status | Review-record-weighted scores and order review coverage |
| mart_customer_daily | Purchase date + customer_unique_id | Reusable person/day counts for custom periods |
| mart_customer_periods | Period type + period start | Daily/monthly/yearly/dataset distinct and repeat customers |

## Interpretation

- Purchase date is the default everywhere. Payment dates are unavailable. Reviews and delivery
  are outcomes of purchase cohorts, not events occurring on that reporting date.
- Final recorded status is not an historical as-of status. Delivered does not establish net revenue.
- Monetary values are BRL. Missing money stays NULL. Zero-filled counts mean no matching records,
  not an inferred monetary value.
- Payment types can be NULL; this is an explicit missing-type group, not a dropped row.
- Payment-method share denominator is ALL methods within the same purchase date and order status.
  Across dates/statuses, recompute shares from summed payment values. Do not add or average shares.
- Credit-card installments average is payment-record weighted, restricted to values >= 1.
  Payment value is never multiplied by installment count.
- Review scores are weighted per review record, not per order. All-status review coverage includes
  orders with no reviews. Filter numerator and denominator to the same status population.
- For delivered payment value, filter mart_payments_daily.order_status = 'delivered'.
- Category, product and seller order counts are not additive across groups.
  Neither are distinct customer/product/seller counts across dates.
- Recompute averages/rates from their stored totals and eligible counts; never average averages.
- Customer periods: select exactly one period_type (day, month, year, dataset). Calendar months
  and years can be partially covered by this historical dataset. dataset is observed history,
  not lifetime. First-observed customers are not necessarily new to the business.
- For arbitrary date ranges, group mart_customer_daily by customer_unique_id first, then count
  people with delivered_orders > 0 or >= 2; do not sum period-level distinct counts.
- Category English names may be missing. Preserve the source category and translation status.
- Invalid negative delivery durations are counted and excluded from average duration.
  Missing punctuality is excluded from both on-time and late denominators.
- Payment reconciliation includes only orders with payment records, no missing payment amounts,
  and a known order total. Counts of exclusions can overlap except eligible/excluded totals.
  Absolute differences greater than BRL 0.01 are findings to investigate, not automatic test failures.
- No refund, profit, commission, actual shipping-cost or confirmed settlement measures are inferred.

## Build and test (PowerShell)

From the repository root, after activating the project's existing environment:

```powershell
& ".\.venv\Scripts\dbt.exe" test --project-dir ".\transformation\olist_analytics" --select "path:models/marts/facts" "path:models/marts/dimensions" --indirect-selection buildable
# Stop if the prerequisite tests fail.
& ".\.venv\Scripts\dbt.exe" build --project-dir ".\transformation\olist_analytics" --select mart_daily_sales mart_product_sales_daily mart_seller_sales_daily mart_delivery_daily mart_payments_daily mart_order_quality_daily mart_reviews_daily mart_customer_daily mart_customer_periods mart_category_sales_daily
```

The mart selector does not rebuild facts or dimensions and does not remove their key declarations.
Use the existing fact-layer workflow separately if upstream models need rebuilding.

## Validation

- Required keys/counts and date relationships.
- Composite uniqueness including nullable payment/category grouping keys.
- Ratios with NULL-aware zero-denominator handling.
- Reconciliation from existing fact/dimension records, in both directions.
- Customer periods independently reconciled from order-level records.
- Delivery, category, seller and product totals compared with daily sales.
- Payment discrepancies surfaced as metrics instead of requiring exact payment equality.

Tests validate the current snapshot; they do not establish freshness or business completeness.
Definitions and coverage are maintained in docs/metric_dictionary.md.

## Verified checkpoint: 2026-10-05

- Prerequisite fact/dimension tests: PASS=109, WARN=0, ERROR=0.
- Explicit mart-only build: 10 tables + 146 tests; PASS=156, WARN=0, ERROR=0.
- Read-only metadata check confirmed all ten mart tables in the development dataset.
- Upstream declarations remained intact: 8 primary keys and 20 foreign keys.
- Facts, dimensions, staging and orchestration were not changed.

| Mart | Verified rows |
|---|---:|
| mart_daily_sales | 634 |
| mart_product_sales_daily | 92,587 |
| mart_seller_sales_daily | 68,019 |
| mart_category_sales_daily | 18,808 |
| mart_delivery_daily | 612 |
| mart_payments_daily | 4,240 |
| mart_order_quality_daily | 2,155 |
| mart_reviews_daily | 2,155 |
| mart_customer_daily | 98,480 |
| mart_customer_periods | 663 |

These counts describe this tested snapshot, not fixed future row-count thresholds.
