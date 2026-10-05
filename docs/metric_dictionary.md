# Olist Metric Dictionary

## 1. Shared reporting conventions

- Currency: Brazilian real (BRL).
- Source datetimes have no confirmed timezone. Use recorded dates without
  assuming or converting a timezone.
- Default reporting date: Order purchase date, using purchase_date_key.
- Delivery-date and review-date reporting must be explicitly labeled.
- Order status represents the status in the available dataset, not the status
  known at a historical reporting date.
- "Delivered" means order_status = 'delivered'.
- "Canceled" means order_status = 'canceled'.
- "Unavailable" means order_status = 'unavailable'.
- Missing amounts are unknown, not zero.
- SUM and AVG exclude NULL values. Report missing-value counts alongside
  monetary and operational metrics.
- Use SAFE_DIVIDE for ratios. Return NULL when the denominator is zero.
- Store rates as decimals; display them as percentages.
- Round monetary results for display, not before aggregation.
- Recalculate ratios and averages from their numerators and denominators.
  Do not average daily averages or daily rates.
- Recalculate distinct counts for each reporting period.
  Do not sum daily distinct customer, seller, or product counts.
- Merchandise value is not Olist company revenue, profit, or seller payout.
- The dataset does not establish refunds, commissions, actual logistics costs,
  or payment settlement. Do not infer these metrics.

## 2. Fact grains and safe joins

| Fact table | Grain |
|---|---|
| fact_orders | One row per order_id |
| fact_order_items | One row per order_id + order_item_id |
| fact_order_payments | One row per order_id + payment_sequential |
| fact_order_reviews | One row per review_id + order_id |

- Join facts to dimensions using tested many-to-one relationships.
- Never join raw item, payment, and review rows together to calculate totals.
  This can multiply rows and inflate metrics.
- Aggregate child facts to one row per order before combining them with
  fact_orders.
- Count people with dim_customers.customer_unique_id, not customer_id.
- customer_id identifies an order-linked customer record, not a unique person.
- Order-level payment and review values are not attributable to individual
  products or sellers without an explicit allocation rule.

## 3. Order and sales metrics

### Orders placed

- Source: fact_orders.
- Population: All statuses.
- Calculation: COUNT(*).
- Reporting date: Purchase date.
- Meaning: Order placement activity, not completed sales.

### Delivered orders

- Source: fact_orders.
- Population: Delivered orders.
- Calculation: COUNT(*).
- Reporting date: Purchase date.
- Meaning: Orders placed in the period that are recorded as delivered.
- This is not the number of delivery events occurring during the period.

### Delivered-order share

- Source: fact_orders.
- Numerator: Delivered orders.
- Denominator: Orders placed.
- Calculation: SAFE_DIVIDE(delivered orders, orders placed).
- Meaning: Delivered share of the purchase cohort in the available snapshot.

### Canceled orders

- Source: fact_orders.
- Population: Canceled orders.
- Calculation: COUNT(*).
- Reporting date: Purchase date.
- Do not include unavailable orders in this count.

### Cancellation rate

- Numerator: Canceled orders.
- Denominator: Orders placed.
- Calculation: SAFE_DIVIDE(canceled orders, orders placed).

### Unavailable orders

- Source: fact_orders.
- Population: Unavailable orders.
- Calculation: COUNT(*).
- Reporting date: Purchase date.

### Unavailable-order rate

- Numerator: Unavailable orders.
- Denominator: Orders placed.
- Calculation: SAFE_DIVIDE(unavailable orders, orders placed).

### Delivered merchandise value

- Source: fact_orders.
- Population: Delivered orders.
- Calculation: SUM(merchandise_value).
- Reporting date: Purchase date.
- Includes: Item prices.
- Excludes: Freight.
- Missing values: Excluded from the sum, with missing-order count reported.
- Meaning: Recorded merchandise value, not platform revenue.

### Delivered freight value

- Source: fact_orders.
- Population: Delivered orders.
- Calculation: SUM(freight_value).
- Reporting date: Purchase date.
- Meaning: Recorded freight charges, not actual logistics costs.

### Delivered total order value

- Source: fact_orders.
- Population: Delivered orders.
- Calculation: SUM(order_total_value).
- Reporting date: Purchase date.
- Includes: Merchandise and freight.
- Missing values: Preserve NULL and report coverage.

### Average delivered order value, including freight

- Source: fact_orders.
- Population: Delivered orders with non-null order_total_value.
- Numerator: SUM(order_total_value).
- Denominator: COUNT(order_total_value).
- Calculation: SAFE_DIVIDE(numerator, denominator).
- Aggregation: Recalculate from total value and eligible order count.

### Average delivered merchandise value per order

- Source: fact_orders.
- Population: Delivered orders with non-null merchandise_value.
- Calculation:
  SAFE_DIVIDE(SUM(merchandise_value), COUNT(merchandise_value)).
- Excludes freight.

### Delivered item quantity

- Source: fact_order_items.
- Population: Items belonging to delivered orders.
- Calculation: SUM(item_quantity).
- Reporting date: Purchase date.
- Each source item row represents one item unit.

### Average items per delivered order

- Source: fact_orders.
- Population: Delivered orders.
- Calculation: SAFE_DIVIDE(SUM(item_count), COUNT(*)).
- Orders without item rows contribute zero items and remain in the denominator.
- Report delivered orders without items separately as a data-quality issue.

### Average delivered item price

- Source: fact_order_items.
- Population: Delivered-order items with non-null item_price.
- Calculation:
  SAFE_DIVIDE(SUM(item_price), SUM(item_quantity)).
- Apply the same non-null item_price filter to both numerator and denominator.
- Excludes freight.

### Freight share of delivered order value

- Source: fact_orders.
- Population: Delivered orders with non-null freight_value and order_total_value.
- Calculation:
  SAFE_DIVIDE(SUM(freight_value), SUM(order_total_value)).
- Uses the same eligible population for both sums.
- Meaning: Share of recorded order value attributable to freight.

## 4. Customer metrics

### Purchasing customers

- Source: fact_orders joined to dim_customers on customer_id.
- Population: All order statuses.
- Calculation: COUNT(DISTINCT customer_unique_id).
- Reporting date: Purchase date.
- Meaning: Distinct people with at least one order placed in the period.
- Non-additive across reporting periods.

### Delivered purchasing customers

- Source: fact_orders joined to dim_customers on customer_id.
- Population: Delivered orders.
- Calculation: COUNT(DISTINCT customer_unique_id).
- Meaning: Distinct people with at least one delivered order purchased
  in the period.

### Delivered orders per purchasing customer

- Numerator: Delivered orders.
- Denominator: Delivered purchasing customers.
- Calculation: SAFE_DIVIDE(numerator, denominator).

### Repeat delivered purchasing customers within period

- Source: fact_orders joined to dim_customers.
- Population: Delivered orders purchased within the selected period.
- Calculation: Count customer_unique_id values with at least two distinct
  order_id values in that period.
- Meaning: Repeat purchasing within the selected period, not lifetime loyalty.

### Repeat delivered purchasing customer rate within period

- Numerator: Repeat delivered purchasing customers within period.
- Denominator: Delivered purchasing customers in the same period.
- Calculation: SAFE_DIVIDE(numerator, denominator).
- Recompute for each selected period; do not sum daily counts.

### First-observed delivered purchasing customers

- Source: All available delivered orders joined to dim_customers.
- Calculation:
  1. Find each customer's earliest delivered-order purchase date across
     the entire available dataset.
  2. Count customers whose earliest date falls within the reporting period.
- Meaning: First observed in this dataset, not necessarily genuinely new
  to Olist.
- Calculate first purchase before applying the reporting-period filter.

## 5. Product and seller metrics

### Products sold

- Source: fact_order_items.
- Population: Delivered-order items.
- Calculation: COUNT(DISTINCT product_id).
- Reporting date: Purchase date.
- Non-additive across periods.

### Selling sellers

- Source: fact_order_items.
- Population: Delivered-order items.
- Calculation: COUNT(DISTINCT seller_id).
- Reporting date: Purchase date.
- Means sellers with observed delivered sales, not all registered sellers.

### Product/category/seller merchandise value

- Source: fact_order_items joined to the relevant dimension.
- Population: Delivered-order items.
- Calculation: SUM(item_price), grouped by product, category, or seller.
- Missing and unmapped categories remain explicit groups, not dropped rows.
- Do not use whole-order merchandise_value after joining to item rows.

### Orders containing a product/category/seller

- Source: fact_order_items joined to the relevant dimension.
- Population: Delivered-order items.
- Calculation: COUNT(DISTINCT order_id) within each group.
- Non-additive across groups: One order can contain multiple products,
  categories, or sellers.

## 6. Payment metrics

### Recorded payment value

- Source: fact_order_payments.
- Population: All payment records unless an order-status filter is stated.
- Calculation: SUM(payment_value).
- Reporting date: Associated order purchase date.
- No actual payment transaction date is available.
- This is not confirmed settlement, net cash received, or recognized revenue.
- Do not multiply payment_value by payment_installments.

### Recorded payment value for delivered orders

- Source: fact_order_payments joined many-to-one to fact_orders.
- Population: Payments associated with delivered orders.
- Calculation: SUM(payment_value).
- Reporting date: Order purchase date.
- Keep separate from merchandise and freight totals.

### Payment record count

- Source: fact_order_payments.
- Calculation: COUNT(*).
- Multiple payment records can belong to one order.
- payment_sequential is not a count of installments paid.

### Orders with payment records

- Source: fact_order_payments.
- Calculation: COUNT(DISTINCT order_id).
- This means a payment record exists, not proof of successful settlement.

### Payment-method value share

- Source: fact_order_payments.
- Numerator: SUM(payment_value) for a payment_type.
- Denominator: SUM(payment_value) across all payment types in the same scope.
- Calculation: SAFE_DIVIDE(numerator, denominator).
- Keep missing or unspecified payment types as explicit groups.
- Use identical date and order-status filters for numerator and denominator.

### Average declared credit-card installments

- Source: fact_order_payments.
- Population: payment_type = 'credit_card' and payment_installments >= 1.
- Calculation: AVG(payment_installments).
- Grain: Payment-record weighted, not order weighted or value weighted.
- Exclude and separately count missing or non-positive installment values.

## 7. Delivery metrics

### Delivery duration coverage

- Source: fact_orders.
- Population: Delivered orders.
- Numerator: Delivered orders with non-null delivery_days >= 0.
- Denominator: Delivered orders.
- Calculation: SAFE_DIVIDE(numerator, denominator).
- Separately count missing and negative delivery durations.

### Average delivery days

- Source: fact_orders.
- Population: Delivered orders with non-null delivery_days >= 0.
- Calculation: AVG(delivery_days).
- Reporting date: Purchase date.
- Unit: Calendar-day difference between purchase and customer delivery dates.
- Not elapsed hours divided by 24.

### On-time delivered orders

- Source: fact_orders.
- Population: Delivered orders with non-null is_delivered_late.
- Calculation: Count orders where is_delivered_late = FALSE.
- Delivery on the estimated delivery date counts as on time.

### Late delivered orders

- Source: fact_orders.
- Population: Delivered orders with non-null is_delivered_late.
- Calculation: Count orders where is_delivered_late = TRUE.

### On-time delivery rate

- Numerator: On-time delivered orders.
- Denominator: Delivered orders with non-null is_delivered_late.
- Calculation: SAFE_DIVIDE(numerator, denominator).
- Missing actual or estimated delivery dates are not assumed on time.

### Late delivery rate

- Numerator: Late delivered orders.
- Denominator: Delivered orders with non-null is_delivered_late.
- Calculation: SAFE_DIVIDE(numerator, denominator).
- On-time and late rates sum to 100% for this eligible population.

### Delivery punctuality coverage

- Numerator: Delivered orders with non-null is_delivered_late.
- Denominator: Delivered orders.
- Calculation: SAFE_DIVIDE(numerator, denominator).

### Average days late among late orders

- Source: fact_orders.
- Population: Delivered orders with delivery_delay_days > 0.
- Calculation: AVG(delivery_delay_days).
- Excludes on-time and early deliveries.

### Average signed delivery delay

- Source: fact_orders.
- Population: Delivered orders with non-null delivery_delay_days.
- Calculation: AVG(delivery_delay_days).
- Negative: Early delivery.
- Zero: Delivery on the estimated date.
- Positive: Late delivery.
- Early and late deliveries can offset each other; show late delivery rate
  alongside this metric.

## 8. Review metrics

### Review record count

- Source: fact_order_reviews.
- Calculation: COUNT(*).
- Grain: One review_id + order_id pair.
- Default reporting date: Associated order purchase date.
- For review activity reporting, use review_creation_date_key and explicitly
  label the date basis.

### Reviewed orders

- Source: fact_order_reviews.
- Calculation: COUNT(DISTINCT order_id).
- One order may have multiple review records.

### Order review coverage

- Numerator: Distinct orders with at least one review record.
- Denominator: Orders placed.
- Reporting date: Purchase date for both numerator and denominator.
- Apply the same status filter to both populations.
- Meaning: Review coverage, not survey response rate; invitation counts
  are unavailable.

### Average review score

- Source: fact_order_reviews.
- Population: Review records with scores between 1 and 5.
- Calculation: AVG(review_score).
- Weighting: Each review record has equal weight.
- Orders with multiple reviews contribute multiple records.
- Do not label this an order-weighted average.

### Low-score review share

- Numerator: Review records with review_score IN (1, 2).
- Denominator: Review records with review_score BETWEEN 1 AND 5.
- Calculation: SAFE_DIVIDE(numerator, denominator).
- This is not a formal complaint rate.

### High-score review share

- Numerator: Review records with review_score IN (4, 5).
- Denominator: Review records with review_score BETWEEN 1 AND 5.
- Calculation: SAFE_DIVIDE(numerator, denominator).

### Written-review share

- Numerator: Review records with a nonblank review_comment_message.
- Denominator: Review records.
- Calculation: SAFE_DIVIDE(numerator, denominator).
- A title without a message does not qualify.

## 9. Data-quality and reconciliation metrics

### Delivered orders missing monetary values

- Source: fact_orders.
- Population: Delivered orders.
- Report separate counts for:
  - merchandise_value IS NULL
  - freight_value IS NULL
  - order_total_value IS NULL
- These counts may overlap and must not be added together.

### Delivered order-total coverage

- Numerator: Delivered orders with non-null order_total_value.
- Denominator: Delivered orders.
- Calculation: SAFE_DIVIDE(numerator, denominator).

### Orders without item records

- Source: fact_orders.
- Calculation: Count orders where item_count = 0.
- Report by order_status.
- Canceled or unavailable orders may legitimately lack item records.
- Delivered orders without items require investigation.

### Orders without payment records

- Source: fact_orders left joined to distinct payment order_id values.
- Calculation: Count orders with no matching payment record.
- Report by order_status.
- Do not automatically interpret these as unpaid orders.

### Payment-to-order value difference

- First aggregate fact_order_payments to one row per order.
- Compare SUM(payment_value) with fact_orders.order_total_value.
- Eligible orders:
  - At least one payment record.
  - No missing payment_value among their payment records.
  - Non-null order_total_value.
- Per-order difference:
  recorded_payment_value - order_total_value.
- Flag absolute differences greater than BRL 0.01 for investigation.
- Also report orders excluded because of missing records or amounts.
- A difference is a reconciliation finding, not automatic proof of an error.
- Do not use only the net difference across orders; positive and negative
  differences can cancel out.

### Duplicate primary-key count

- Calculate duplicate groups using each table's declared primary key.
- Expected result: Zero duplicate key groups.
- Composite fact keys must be tested as complete combinations.

### Orphan foreign-key count

- Calculate non-null fact keys without a corresponding dimension or
  parent fact key.
- Expected result: Zero.
- Check required-key NULL values separately.
- BigQuery key declarations do not replace these tests.

### Missing required purchase dates

- Source: fact_orders.
- Calculation: Count orders with missing purchase timestamp or purchase_date_key.
- Expected result: Zero.
- Missing dates must not silently disappear from date-based reporting.

## 10. First reporting mart: mart_daily_sales

### Grain

One row per purchase date.

### Initial metrics

- Orders placed
- Delivered orders
- Delivered-order share
- Canceled orders
- Cancellation rate
- Unavailable orders
- Unavailable-order rate
- Delivered merchandise value
- Delivered freight value
- Delivered total order value
- Average delivered order value, including freight
- Delivered item quantity
- Average items per delivered order
- Purchasing customers
- Delivered purchasing customers
- Delivered orders missing each monetary value
- Delivered order-total coverage

### Implementation rules

- Start from fact_orders.
- Join dim_customers many-to-one for customer_unique_id.
- Use dim_date for reporting dates and calendar attributes.
- Do not directly join item, payment, or review rows into this daily aggregate.
- Retain monetary sums and eligible counts needed to recalculate averages.
- Daily distinct customer counts cannot produce accurate monthly distinct
  customer counts; recalculate those from order-level data.
- Introduce payment, delivery, review, and product/seller reporting marts
  separately, using their documented grains and populations.

## 11. Implemented reporting layer

| Metric group | Primary mart |
|---|---|
| Orders/sales, merchandise AOV, item price, freight share, distinct products/sellers | mart_daily_sales |
| Product sales | mart_product_sales_daily |
| Seller sales | mart_seller_sales_daily |
| Category sales and category-level distinct order counts | mart_category_sales_daily |
| Delivery measures and date coverage | mart_delivery_daily |
| Payment measures by purchase date/status/type | mart_payments_daily |
| Review measures by purchase date/status | mart_reviews_daily |
| Arbitrary-period customer inputs | mart_customer_daily |
| Customer measures for day/month/year/full observed dataset | mart_customer_periods |
| Missing items/payments and complete-case payment reconciliation | mart_order_quality_daily |

- Select exactly one period_type in mart_customer_periods. Month/year rows use
  calendar boundaries but can represent partially observed periods. The dataset
  period is available historical coverage, not lifetime history.
- Payment-method shares are within purchase date and order status. Recompute
  from summed values when combining dates or statuses; never sum stored shares.
- For orders with payment records across methods, use mart_order_quality_daily.
  Do not sum distinct order counts from payment-type groups.
- NULL payment types and missing/unmapped source categories remain explicit groups.
- Key duplication, orphan keys, required dates, source reconciliation and ratio
  correctness are dbt test assertions rather than extra business metric tables.
- See transformation/olist_analytics/models/marts/README.md for grains,
  aggregation caveats and the explicit mart-only build command.
