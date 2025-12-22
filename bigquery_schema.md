# BigQuery Analytics Schema

## Overview
Read-only analytics tables for canteen order metrics and reporting.
Data is exported from Firestore to BigQuery for historical analysis and dashboards.

**Data Flow:** Firestore → BigQuery Export → Analytics Tables

**Update Frequency:** TODO: Define export schedule (hourly, daily, real-time streaming?)

---

## Table 1: orders_analytics

Stores all order records for historical analysis and metrics.

```sql
CREATE TABLE canteen_analytics.orders_analytics (
  -- Primary identifiers
  order_id STRING NOT NULL,                   -- Firestore order document ID
  user_id STRING NOT NULL,                    -- User who placed the order
  user_name STRING,                           -- Denormalized user name for reporting
  
  -- Order details
  slot_id STRING,                             -- Assigned pickup slot ID
  estimated_pickup_time TIMESTAMP,            -- When user was told to pickup
  
  -- Order items
  items_count INT64,                          -- Number of distinct items in order
  total_items INT64,                          -- Total quantity (sum of all item quantities)
  items_json STRING,                          -- JSON array of items (for detailed analysis)
  total_amount FLOAT64,                       -- Total order value (for display, not payment)
  
  -- Order lifecycle timestamps
  status STRING,                              -- Current status: pending, confirmed, preparing, ready, completed, cancelled
  placed_at TIMESTAMP NOT NULL,               -- When order was created
  confirmed_at TIMESTAMP,                     -- When canteen confirmed the order
  ready_at TIMESTAMP,                         -- When order was marked ready
  completed_at TIMESTAMP,                     -- When order was picked up
  
  -- Derived fields (calculated during export)
  wait_time_minutes INT64,                    -- Time from placed_at to ready_at (in minutes)
  pickup_delay_minutes INT64,                 -- Time from ready_at to completed_at (in minutes)
  slot_delay_minutes INT64,                   -- How late was pickup vs estimated_pickup_time
  
  -- Operational metadata
  pickup_verified BOOLEAN,                    -- Whether RFID verification was done
  cancellation_reason STRING,                 -- Reason if cancelled
  
  -- Date partitioning (for query performance)
  order_date DATE,                            -- Date extracted from placed_at (for partitioning)
  
  -- Audit fields
  exported_at TIMESTAMP,                      -- When this record was exported to BigQuery
  
  -- TODO: Add fields for promotional campaigns or discounts if added later
  -- TODO: Add user_role field if analytics need to segment by student/staff
)
PARTITION BY order_date
CLUSTER BY status, user_id;
```

### Field Explanations

| Field | Purpose | Calculation Logic |
|-------|---------|-------------------|
| `items_count` | Number of distinct items | COUNT of items array |
| `total_items` | Total quantity across all items | SUM of item.quantity |
| `items_json` | Full items array as JSON string | JSON.stringify(items) - for drill-down analysis |
| `wait_time_minutes` | Order preparation time | TIMESTAMP_DIFF(ready_at, placed_at, MINUTE) |
| `pickup_delay_minutes` | How long order sat ready | TIMESTAMP_DIFF(completed_at, ready_at, MINUTE) |
| `slot_delay_minutes` | Pickup punctuality | TIMESTAMP_DIFF(completed_at, estimated_pickup_time, MINUTE) |
| `order_date` | Partition key | DATE(placed_at) |

### TODO: Derived Field Logic

- **wait_time_minutes**: Should be NULL if order is not yet ready? Or calculate from current time?
- **pickup_delay_minutes**: Should be NULL for uncompleted orders? Or calculate from current time?
- **slot_delay_minutes**: Negative values = early pickup, positive = late pickup. Should we clamp to 0?

---

## Table 2: slots_analytics

Stores slot capacity and utilization metrics.

```sql
CREATE TABLE canteen_analytics.slots_analytics (
  -- Primary identifiers
  slot_id STRING NOT NULL,                    -- Firestore slot document ID
  
  -- Slot timing
  slot_date DATE NOT NULL,                    -- Date of the slot (YYYY-MM-DD)
  start_time TIMESTAMP NOT NULL,              -- Slot start time
  end_time TIMESTAMP NOT NULL,                -- Slot end time
  slot_duration_minutes INT64,                -- Duration of slot in minutes
  
  -- Capacity metrics
  max_capacity INT64 NOT NULL,                -- Maximum orders slot can handle
  current_count INT64 NOT NULL,               -- Actual orders assigned to slot
  utilization_percent FLOAT64,                -- (current_count / max_capacity) * 100
  
  -- Status tracking
  status STRING,                              -- open, full, closed
  auto_closed_at TIMESTAMP,                   -- When slot auto-closed due to capacity
  manually_closed_by STRING,                  -- Admin user ID if manually closed
  
  -- Operational metadata
  created_at TIMESTAMP,                       -- When slot was created
  
  -- Derived fields
  orders_completed_count INT64,               -- How many orders were actually picked up
  orders_cancelled_count INT64,               -- How many orders were cancelled
  completion_rate_percent FLOAT64,            -- (completed / current_count) * 100
  
  -- Audit fields
  exported_at TIMESTAMP,                      -- When exported to BigQuery
  
  -- TODO: Add peak_time flag if slot falls in lunch/dinner rush hours
  -- TODO: Add day_of_week for weekly pattern analysis
)
PARTITION BY slot_date
CLUSTER BY status, slot_date;
```

### Field Explanations

| Field | Purpose | Calculation Logic |
|-------|---------|-------------------|
| `slot_duration_minutes` | Length of slot | TIMESTAMP_DIFF(end_time, start_time, MINUTE) |
| `utilization_percent` | How full the slot was | (current_count / max_capacity) * 100 |
| `orders_completed_count` | Successful pickups | COUNT(orders WHERE slotId = slot_id AND status = 'completed') |
| `orders_cancelled_count` | Cancelled orders in slot | COUNT(orders WHERE slotId = slot_id AND status = 'cancelled') |
| `completion_rate_percent` | Success rate | (orders_completed_count / current_count) * 100 |

### TODO: Derived Field Logic

- **completion_rate_percent**: Should we exclude cancelled orders from denominator?
- **orders_completed_count**: Should this be calculated at export time or updated periodically?
- Should we track "no-show" orders (ready but never completed)?

---

## Table 3: daily_summary (Optional)

Pre-aggregated daily metrics for fast dashboard loading.

```sql
CREATE TABLE canteen_analytics.daily_summary (
  -- Date
  summary_date DATE NOT NULL,                 -- Date of the summary
  
  -- Order volume metrics
  total_orders INT64,                         -- Total orders placed
  completed_orders INT64,                     -- Successfully completed orders
  cancelled_orders INT64,                     -- Cancelled orders
  completion_rate_percent FLOAT64,            -- (completed / total) * 100
  
  -- Revenue metrics (display only, no payment)
  total_revenue FLOAT64,                      -- Sum of all order amounts
  avg_order_value FLOAT64,                    -- Average order amount
  
  -- Timing metrics
  avg_wait_time_minutes FLOAT64,              -- Average preparation time
  avg_pickup_delay_minutes FLOAT64,           -- Average time order sat ready
  
  -- Slot metrics
  total_slots INT64,                          -- Number of slots created
  slots_filled INT64,                         -- Slots that reached capacity
  avg_slot_utilization_percent FLOAT64,       -- Average utilization across all slots
  
  -- User metrics
  unique_users INT64,                         -- Distinct users who placed orders
  new_users INT64,                            -- Users who placed first order (TODO: requires user history)
  
  -- Peak hour metrics
  peak_hour_start TIME,                       -- Hour with most orders (TODO: define calculation)
  peak_hour_orders INT64,                     -- Order count in peak hour
  
  -- Quality metrics
  orders_with_rfid_verification INT64,        -- Orders verified with RFID
  rfid_verification_rate_percent FLOAT64,     -- (verified / completed) * 100
  
  -- Audit
  calculated_at TIMESTAMP,                    -- When summary was computed
  
  -- TODO: Add day_of_week, is_holiday flags for pattern analysis
)
PARTITION BY summary_date;
```

---

## Analytics Queries Examples

### Query 1: Daily Order Volume

```sql
SELECT 
  order_date,
  COUNT(*) as total_orders,
  COUNTIF(status = 'completed') as completed_orders,
  COUNTIF(status = 'cancelled') as cancelled_orders,
  ROUND(AVG(wait_time_minutes), 2) as avg_wait_time
FROM canteen_analytics.orders_analytics
WHERE order_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY order_date
ORDER BY order_date DESC;
```

### Query 2: Slot Utilization Report

```sql
SELECT 
  slot_date,
  COUNT(*) as total_slots,
  AVG(utilization_percent) as avg_utilization,
  COUNTIF(status = 'full') as slots_filled,
  COUNTIF(status = 'closed' AND manually_closed_by IS NOT NULL) as manually_closed
FROM canteen_analytics.slots_analytics
WHERE slot_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
GROUP BY slot_date
ORDER BY slot_date DESC;
```

### Query 3: Peak Hours Analysis

```sql
SELECT 
  EXTRACT(HOUR FROM placed_at) as hour_of_day,
  COUNT(*) as orders_count,
  AVG(wait_time_minutes) as avg_wait_time,
  AVG(total_amount) as avg_order_value
FROM canteen_analytics.orders_analytics
WHERE order_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND status != 'cancelled'
GROUP BY hour_of_day
ORDER BY orders_count DESC;
```

### Query 4: User Ordering Patterns

```sql
SELECT 
  user_id,
  user_name,
  COUNT(*) as total_orders,
  COUNTIF(status = 'completed') as completed_orders,
  AVG(total_amount) as avg_spend,
  AVG(wait_time_minutes) as avg_wait_time
FROM canteen_analytics.orders_analytics
WHERE order_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY user_id, user_name
HAVING total_orders >= 5  -- Frequent users
ORDER BY total_orders DESC;
```

### Query 5: Cancellation Analysis

```sql
SELECT 
  cancellation_reason,
  COUNT(*) as cancellation_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM canteen_analytics.orders_analytics
WHERE status = 'cancelled'
  AND order_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY cancellation_reason
ORDER BY cancellation_count DESC;
```

---

## Data Export Strategy

### Option 1: Firestore BigQuery Export (Recommended for Hackathon)

```
Firebase Console → Firestore → Export Collections
- Select: orders, orderSlots
- Destination: BigQuery dataset
- Schedule: Daily at 2:00 AM
```

**Pros:**
- Native Firebase integration
- Automatic schema mapping
- No code required

**Cons:**
- Data is raw (needs transformation for derived fields)
- Delayed (not real-time)

### Option 2: Cloud Function Export (For Real-time)

```javascript
// Trigger on order completion
exports.exportToAnalytics = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    if (change.after.data().status === 'completed') {
      // Calculate derived fields
      // Insert to BigQuery
    }
  });
```

**Pros:**
- Real-time analytics
- Can compute derived fields

**Cons:**
- More complex
- Higher cost for high volume

### Recommended Approach for Hackathon

Use **Option 1** (native export) for simplicity. Create BigQuery views to compute derived fields:

```sql
CREATE VIEW canteen_analytics.orders_with_metrics AS
SELECT 
  *,
  TIMESTAMP_DIFF(ready_at, placed_at, MINUTE) as wait_time_minutes,
  TIMESTAMP_DIFF(completed_at, ready_at, MINUTE) as pickup_delay_minutes,
  TIMESTAMP_DIFF(completed_at, estimated_pickup_time, MINUTE) as slot_delay_minutes
FROM canteen_analytics.orders_analytics;
```

---

## Performance Optimization

1. **Partitioning**: Both tables partitioned by date for query performance
2. **Clustering**: Clustered by frequently filtered columns (status, user_id)
3. **Pre-aggregation**: Use `daily_summary` table for dashboard to avoid scanning all rows
4. **Query caching**: BigQuery caches results for 24 hours by default

---

## Cost Estimation (TODO)

- Firestore → BigQuery export: Free (native feature)
- BigQuery storage: ~$0.02 per GB per month
- BigQuery queries: $5 per TB scanned

**Estimated for 1000 orders/day:**
- 365,000 orders/year × ~1KB per row = ~365MB
- Storage cost: ~$0.01/month
- Query cost: Minimal with partitioning and clustering

---

## Security & Access Control

```sql
-- Grant read-only access to analytics team
GRANT `roles/bigquery.dataViewer` 
ON SCHEMA canteen_analytics 
TO 'group:analytics-team@college.edu';

-- Admin access for data engineers
GRANT `roles/bigquery.admin`
ON SCHEMA canteen_analytics
TO 'group:data-engineers@college.edu';
```

**TODO:** Define specific user roles and access patterns

---

## Monitoring & Alerts (TODO)

Define alerts for:
- Daily order volume drops below threshold
- Average wait time exceeds X minutes
- Cancellation rate exceeds Y%
- Slot utilization drops below Z%

---

## Assumptions

1. Data is exported from Firestore, not written directly to BigQuery
2. Analytics are for reporting only, not operational decisions
3. Historical data is immutable (append-only, no updates)
4. Derived fields can be calculated during export or via views
5. Real-time dashboards will query Firestore; BigQuery is for historical analysis

---

## Schema Version

**Version:** 1.0  
**Last Updated:** 2025-12-21  
**Status:** Draft - Hackathon Ready

**TODO for Production:**
- Add schema versioning fields
- Add data quality validation rules
- Add retention policies (how long to keep data)
- Add backup and disaster recovery strategy
