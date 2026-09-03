

-- ---------- 1. charts: value only ----------

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '01a066fa-6ff7-7eb9-9ef2-b9e9598db643',
    'Total Refunded Amount',
    'Refunds & Reversals/Refund Overview/KPI/Total Refunded Amount',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(r.total_refunded_amount, 0)), 0), 2) AS total_refunded_amount
    FROM public.fact_order_refunds r
    JOIN public.fact_order_headers o ON o.id = r.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL
           OR COALESCE(r.processed_at, r.created_at)::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL
           OR COALESCE(r.processed_at, r.created_at)::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Total amount refunded for the selected period vs the prior period.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '01a066fa-6ff7-7ba7-9847-1e9656ffb4ec',
    'Refund Rate by Value',
    'Refunds & Reversals/Refund Overview/KPI/Refund Rate by Value',
    $$
    WITH refund_totals AS (
        SELECT COALESCE(SUM(COALESCE(r.total_refunded_amount, 0)), 0) AS refunded
        FROM public.fact_order_refunds r
        JOIN public.fact_order_headers o ON o.id = r.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (:currentStartDate::date IS NULL
               OR COALESCE(r.processed_at, r.created_at)::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL
               OR COALESCE(r.processed_at, r.created_at)::date <= :currentEndDate::date)
    ),
    gross_totals AS (
        SELECT COALESCE(SUM(COALESCE(li.original_total_amount,
                                     li.original_unit_price * li.quantity, 0)), 0) AS gross
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT ROUND(100 * rt.refunded / NULLIF(g.gross, 0), 2) AS refund_rate_by_value
    FROM refund_totals rt
    CROSS JOIN gross_totals g
    $$,
    NULL,
    'KPI',
    60,
    'Refunded amount as a percentage of gross line item value for the selected period vs the prior period.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '01a066fa-6ff7-779b-b163-30d3b2d9b9a3',
    'Refunded Orders',
    'Refunds & Reversals/Refund Overview/KPI/Refunded Orders',
    $$
    SELECT COUNT(DISTINCT r.order_id) AS refunded_orders
    FROM public.fact_order_refunds r
    JOIN public.fact_order_headers o ON o.id = r.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL
           OR COALESCE(r.processed_at, r.created_at)::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL
           OR COALESCE(r.processed_at, r.created_at)::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Distinct orders with at least one refund for the selected period vs the prior period.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '01a066fa-6ff8-75e4-b052-4331c8373233',
    'Refunded Order Rate',
    'Refunds & Reversals/Refund Overview/KPI/Refunded Order Rate',
    $$
    WITH refund_orders AS (
        SELECT COUNT(DISTINCT r.order_id) AS refunded_orders
        FROM public.fact_order_refunds r
        JOIN public.fact_order_headers o ON o.id = r.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (:currentStartDate::date IS NULL
               OR COALESCE(r.processed_at, r.created_at)::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL
               OR COALESCE(r.processed_at, r.created_at)::date <= :currentEndDate::date)
    ),
    order_totals AS (
        SELECT COUNT(*) AS orders
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT ROUND(100 * ro.refunded_orders::numeric / NULLIF(ot.orders, 0), 2) AS refunded_order_rate
    FROM refund_orders ro
    CROSS JOIN order_totals ot
    $$,
    NULL,
    'KPI',
    60,
    'Refunded orders as a percentage of all orders for the selected period vs the prior period.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '01a066fa-6ff8-7869-b41d-eb2439424a3a',
    'Average Refund Value',
    'Refunds & Reversals/Refund Overview/KPI/Average Refund Value',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(r.total_refunded_amount, 0)), 0)
                 / NULLIF(COUNT(*), 0), 2) AS average_refund_value
    FROM public.fact_order_refunds r
    JOIN public.fact_order_headers o ON o.id = r.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL
           OR COALESCE(r.processed_at, r.created_at)::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL
           OR COALESCE(r.processed_at, r.created_at)::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Average value per refund record for the selected period vs the prior period.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '01a066fa-6ff9-721a-8e17-a93b81d336ba',
    'Refunded Shipping Amount',
    'Refunds & Reversals/Revenue Impact/KPI/Refunded Shipping Amount',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(o.total_refunded_shipping_amount, 0)), 0), 2)
           AS refunded_shipping_amount
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Shipping charges refunded for the selected period vs the prior period.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '01a066fa-6ff9-7542-bbb9-e50a18158b6f',
    'Refund Transaction Amount',
    'Refunds & Reversals/Revenue Impact/KPI/Refund Transaction Amount',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(t.amount, 0)), 0), 2) AS refund_transaction_amount
    FROM public.fact_order_transactions t
    JOIN public.fact_order_headers o ON o.id = t.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND t.test = FALSE
      AND t.kind = 'REFUND'
      AND t.status = 'SUCCESS'
      AND (:currentStartDate::date IS NULL OR t.processed_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR t.processed_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Successful refund transaction amounts for the selected period vs the prior period.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '01a066fa-6ff9-7147-992f-3d975fca9ce8',
    'Refunded Discount Value',
    'Refunds & Reversals/Revenue Impact/KPI/Refunded Discount Value',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(li.total_discount_amount, 0)
                     * (li.quantity - COALESCE(li.refundable_quantity, li.quantity))::numeric
                     / NULLIF(li.quantity, 0)), 0), 2) AS refunded_discount_value
    FROM public.fact_order_line_items li
    JOIN public.fact_order_headers o ON o.id = li.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Discount value attributable to refunded units for the selected period vs the prior period.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '01a066fa-6ffa-7632-a446-e4fc1f993b31',
    'Partially Refunded Orders',
    'Refunds & Reversals/Order Refund Analysis/KPI/Partially Refunded Orders',
    $$
    SELECT COUNT(*) AS partially_refunded_orders
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND o.financialstatus = 'PARTIALLY_REFUNDED'
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Orders partially refunded for the selected period vs the prior period.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '01a066fa-6ffa-7467-adeb-0e666c6caa81',
    'Fully Refunded Orders',
    'Refunds & Reversals/Order Refund Analysis/KPI/Fully Refunded Orders',
    $$
    SELECT COUNT(*) AS fully_refunded_orders
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND o.financialstatus = 'REFUNDED'
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Orders fully refunded for the selected period vs the prior period.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '01a066fa-6ffa-7326-a708-d273d7f8774b',
    'Refund Removed Quantity',
    'Refunds & Reversals/Product Refund Analysis/KPI/Refund Removed Quantity',
    $$
    SELECT COALESCE(SUM(li.quantity - COALESCE(li.current_quantity, li.quantity)), 0)
           AS refund_removed_quantity
    FROM public.fact_order_line_items li
    JOIN public.fact_order_headers o ON o.id = li.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Line item units removed by refunds for the selected period vs the prior period.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '01a066fa-6ffa-76c9-9153-bc94543087a3',
    'Refundable Quantity',
    'Refunds & Reversals/Product Refund Analysis/KPI/Refundable Quantity',
    $$
    SELECT COALESCE(SUM(COALESCE(li.refundable_quantity, 0)), 0) AS refundable_quantity
    FROM public.fact_order_line_items li
    JOIN public.fact_order_headers o ON o.id = li.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Line item units still eligible for refund for the selected period vs the prior period.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
);

-- ---------- 2. chart signals: divergence ----------

INSERT INTO vizkit.chart_signal (id, chart_id, name, query)
VALUES (
    '019fff82-e31b-7e01-8f71-4a2b3c4d1001',
    '01a066fa-6ff7-7eb9-9ef2-b9e9598db643',
    'total_refunded_amount',
    $$
    WITH refund_totals AS (
        SELECT COALESCE(SUM(amount) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(amount) FILTER (WHERE is_prior),   0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL
                     OR COALESCE(r.processed_at, r.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL
                     OR COALESCE(r.processed_at, r.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(r.processed_at, r.created_at)::date
                    BETWEEN :priorStartDate::date AND :priorEndDate::date)                      AS is_prior,
                   COALESCE(r.total_refunded_amount, 0) AS amount
            FROM public.fact_order_refunds r
            JOIN public.fact_order_headers o ON o.id = r.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
    )
    SELECT ROUND(rt.prv_value, 2) AS previous_value,
           ROUND(100 * (rt.cur_value - rt.prv_value)
                 / NULLIF(ABS(rt.prv_value), 0), 2) AS divergence
    FROM refund_totals rt
    $$
),
(
    '019fff82-e31b-7e02-8f72-4a2b3c4d1002',
    '01a066fa-6ff7-7ba7-9847-1e9656ffb4ec',
    'refund_rate_by_value',
    $$
    WITH refund_totals AS (
        SELECT COALESCE(SUM(amount) FILTER (WHERE is_current), 0) AS cur_refunded,
               COALESCE(SUM(amount) FILTER (WHERE is_prior),   0) AS prv_refunded
        FROM (
            SELECT ((:currentStartDate::date IS NULL
                     OR COALESCE(r.processed_at, r.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL
                     OR COALESCE(r.processed_at, r.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(r.processed_at, r.created_at)::date
                    BETWEEN :priorStartDate::date AND :priorEndDate::date)                      AS is_prior,
                   COALESCE(r.total_refunded_amount, 0) AS amount
            FROM public.fact_order_refunds r
            JOIN public.fact_order_headers o ON o.id = r.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    gross_totals AS (
        SELECT COALESCE(SUM(COALESCE(li.original_total_amount,
                                     li.original_unit_price * li.quantity, 0))
                        FILTER (WHERE t.is_current), 0) AS cur_gross,
               COALESCE(SUM(COALESCE(li.original_total_amount,
                                     li.original_unit_price * li.quantity, 0))
                        FILTER (WHERE t.is_prior),   0) AS prv_gross
        FROM (
            SELECT o.id,
                   ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        JOIN public.fact_order_line_items li ON li.order_id = t.id
        WHERE t.is_current OR t.is_prior
    ),
    computed AS (
        SELECT ROUND(100 * rt.cur_refunded / NULLIF(g.cur_gross, 0), 2) AS cur_rate,
               ROUND(100 * rt.prv_refunded / NULLIF(g.prv_gross, 0), 2) AS prv_rate
        FROM refund_totals rt
        CROSS JOIN gross_totals g
    )
    SELECT c.prv_rate AS previous_value,
           ROUND(100 * (c.cur_rate - c.prv_rate)
                 / NULLIF(ABS(c.prv_rate), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fff82-e31b-7e03-8f73-4a2b3c4d1003',
    '01a066fa-6ff7-779b-b163-30d3b2d9b9a3',
    'refunded_orders',
    $$
    WITH refund_totals AS (
        SELECT COUNT(DISTINCT order_id) FILTER (WHERE is_current) AS cur_value,
               COUNT(DISTINCT order_id) FILTER (WHERE is_prior)   AS prv_value
        FROM (
            SELECT r.order_id,
                   ((:currentStartDate::date IS NULL
                     OR COALESCE(r.processed_at, r.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL
                     OR COALESCE(r.processed_at, r.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(r.processed_at, r.created_at)::date
                    BETWEEN :priorStartDate::date AND :priorEndDate::date)                      AS is_prior
            FROM public.fact_order_refunds r
            JOIN public.fact_order_headers o ON o.id = r.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
    )
    SELECT rt.prv_value AS previous_value,
           ROUND(100.0 * (rt.cur_value - rt.prv_value)
                 / NULLIF(ABS(rt.prv_value), 0), 2) AS divergence
    FROM refund_totals rt
    $$
),
(
    '019fff82-e31b-7e04-8f74-4a2b3c4d1004',
    '01a066fa-6ff8-75e4-b052-4331c8373233',
    'refunded_order_rate',
    $$
    WITH refund_totals AS (
        SELECT COUNT(DISTINCT order_id) FILTER (WHERE is_current) AS cur_refunded_orders,
               COUNT(DISTINCT order_id) FILTER (WHERE is_prior)   AS prv_refunded_orders
        FROM (
            SELECT r.order_id,
                   ((:currentStartDate::date IS NULL
                     OR COALESCE(r.processed_at, r.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL
                     OR COALESCE(r.processed_at, r.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(r.processed_at, r.created_at)::date
                    BETWEEN :priorStartDate::date AND :priorEndDate::date)                      AS is_prior
            FROM public.fact_order_refunds r
            JOIN public.fact_order_headers o ON o.id = r.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    order_totals AS (
        SELECT COUNT(*) FILTER (WHERE is_current) AS cur_orders,
               COUNT(*) FILTER (WHERE is_prior)   AS prv_orders
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    computed AS (
        SELECT ROUND(100 * rt.cur_refunded_orders::numeric
                     / NULLIF(ot.cur_orders, 0), 2) AS cur_rate,
               ROUND(100 * rt.prv_refunded_orders::numeric
                     / NULLIF(ot.prv_orders, 0), 2) AS prv_rate
        FROM refund_totals rt
        CROSS JOIN order_totals ot
    )
    SELECT c.prv_rate AS previous_value,
           ROUND(100 * (c.cur_rate - c.prv_rate)
                 / NULLIF(ABS(c.prv_rate), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fff82-e31b-7e05-8f75-4a2b3c4d1005',
    '01a066fa-6ff8-7869-b41d-eb2439424a3a',
    'average_refund_value',
    $$
    WITH refund_totals AS (
        SELECT COALESCE(SUM(amount) FILTER (WHERE is_current), 0) AS cur_refunded,
               COALESCE(SUM(amount) FILTER (WHERE is_prior),   0) AS prv_refunded,
               COUNT(*) FILTER (WHERE is_current) AS cur_count,
               COUNT(*) FILTER (WHERE is_prior)   AS prv_count
        FROM (
            SELECT ((:currentStartDate::date IS NULL
                     OR COALESCE(r.processed_at, r.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL
                     OR COALESCE(r.processed_at, r.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(r.processed_at, r.created_at)::date
                    BETWEEN :priorStartDate::date AND :priorEndDate::date)                      AS is_prior,
                   COALESCE(r.total_refunded_amount, 0) AS amount
            FROM public.fact_order_refunds r
            JOIN public.fact_order_headers o ON o.id = r.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    computed AS (
        SELECT ROUND(rt.cur_refunded / NULLIF(rt.cur_count, 0), 2) AS cur_avg,
               ROUND(rt.prv_refunded / NULLIF(rt.prv_count, 0), 2) AS prv_avg
        FROM refund_totals rt
    )
    SELECT c.prv_avg AS previous_value,
           ROUND(100 * (c.cur_avg - c.prv_avg)
                 / NULLIF(ABS(c.prv_avg), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fff82-e31b-7e06-8f76-4a2b3c4d1006',
    '01a066fa-6ff9-721a-8e17-a93b81d336ba',
    'refunded_shipping_amount',
    $$
    WITH shipping_totals AS (
        SELECT COALESCE(SUM(refunded_shipping) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(refunded_shipping) FILTER (WHERE is_prior),   0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(o.total_refunded_shipping_amount, 0) AS refunded_shipping
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
    )
    SELECT ROUND(s.prv_value, 2) AS previous_value,
           ROUND(100 * (s.cur_value - s.prv_value)
                 / NULLIF(ABS(s.prv_value), 0), 2) AS divergence
    FROM shipping_totals s
    $$
),
(
    '019fff82-e31b-7e07-8f77-4a2b3c4d1007',
    '01a066fa-6ff9-7542-bbb9-e50a18158b6f',
    'refund_transaction_amount',
    $$
    WITH txn_totals AS (
        SELECT COALESCE(SUM(amount) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(amount) FILTER (WHERE is_prior),   0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR t.processed_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR t.processed_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND t.processed_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(t.amount, 0) AS amount
            FROM public.fact_order_transactions t
            JOIN public.fact_order_headers o ON o.id = t.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND t.test = FALSE
              AND t.kind = 'REFUND'
              AND t.status = 'SUCCESS'
        ) x
        WHERE x.is_current OR x.is_prior
    )
    SELECT ROUND(x.prv_value, 2) AS previous_value,
           ROUND(100 * (x.cur_value - x.prv_value)
                 / NULLIF(ABS(x.prv_value), 0), 2) AS divergence
    FROM txn_totals x
    $$
),
(
    '019fff82-e31b-7e08-8f78-4a2b3c4d1008',
    '01a066fa-6ff9-7147-992f-3d975fca9ce8',
    'refunded_discount_value',
    $$
    WITH discount_totals AS (
        SELECT COALESCE(SUM(COALESCE(li.total_discount_amount, 0)
                 * (li.quantity - COALESCE(li.refundable_quantity, li.quantity))::numeric
                 / NULLIF(li.quantity, 0)) FILTER (WHERE t.is_current), 0) AS cur_value,
               COALESCE(SUM(COALESCE(li.total_discount_amount, 0)
                 * (li.quantity - COALESCE(li.refundable_quantity, li.quantity))::numeric
                 / NULLIF(li.quantity, 0)) FILTER (WHERE t.is_prior),   0) AS prv_value
        FROM (
            SELECT o.id,
                   ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        JOIN public.fact_order_line_items li ON li.order_id = t.id
        WHERE t.is_current OR t.is_prior
    )
    SELECT ROUND(d.prv_value, 2) AS previous_value,
           ROUND(100 * (d.cur_value - d.prv_value)
                 / NULLIF(ABS(d.prv_value), 0), 2) AS divergence
    FROM discount_totals d
    $$
),
(
    '019fff82-e31b-7e09-8f79-4a2b3c4d1009',
    '01a066fa-6ffa-7632-a446-e4fc1f993b31',
    'partially_refunded_orders',
    $$
    WITH totals AS (
        SELECT COUNT(*) FILTER (WHERE is_current) AS cur_value,
               COUNT(*) FILTER (WHERE is_prior)   AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.financialstatus = 'PARTIALLY_REFUNDED'
        ) t
        WHERE t.is_current OR t.is_prior
    )
    SELECT t.prv_value AS previous_value,
           ROUND(100.0 * (t.cur_value - t.prv_value)
                 / NULLIF(ABS(t.prv_value), 0), 2) AS divergence
    FROM totals t
    $$
),
(
    '019fff82-e31b-7e0a-8f7a-4a2b3c4d100a',
    '01a066fa-6ffa-7467-adeb-0e666c6caa81',
    'fully_refunded_orders',
    $$
    WITH totals AS (
        SELECT COUNT(*) FILTER (WHERE is_current) AS cur_value,
               COUNT(*) FILTER (WHERE is_prior)   AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.financialstatus = 'REFUNDED'
        ) t
        WHERE t.is_current OR t.is_prior
    )
    SELECT t.prv_value AS previous_value,
           ROUND(100.0 * (t.cur_value - t.prv_value)
                 / NULLIF(ABS(t.prv_value), 0), 2) AS divergence
    FROM totals t
    $$
),
(
    '019fff82-e31b-7e0b-8f7b-4a2b3c4d100b',
    '01a066fa-6ffa-7326-a708-d273d7f8774b',
    'refund_removed_quantity',
    $$
    WITH totals AS (
        SELECT COALESCE(SUM(removed_units) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(removed_units) FILTER (WHERE is_prior),   0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   li.quantity - COALESCE(li.current_quantity, li.quantity) AS removed_units
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
    )
    SELECT t.prv_value AS previous_value,
           ROUND(100.0 * (t.cur_value - t.prv_value)
                 / NULLIF(ABS(t.prv_value), 0), 2) AS divergence
    FROM totals t
    $$
),
(
    '019fff82-e31b-7e0c-8f7c-4a2b3c4d100c',
    '01a066fa-6ffa-76c9-9153-bc94543087a3',
    'refundable_quantity',
    $$
    WITH totals AS (
        SELECT COALESCE(SUM(refundable_units) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(refundable_units) FILTER (WHERE is_prior),   0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(li.refundable_quantity, 0) AS refundable_units
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
    )
    SELECT t.prv_value AS previous_value,
           ROUND(100.0 * (t.cur_value - t.prv_value)
                 / NULLIF(ABS(t.prv_value), 0), 2) AS divergence
    FROM totals t
    $$
);
