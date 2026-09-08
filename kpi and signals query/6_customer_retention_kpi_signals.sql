- ---------- 1. charts: value only ----------

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '01a066fd-5a9f-79ea-8fec-483847f490c4',
    'Total Customers',
    'Customer Retention/Customer Overview/KPI/Total Customers',
    $$
    SELECT COUNT(DISTINCT o.customer_id) AS total_customers
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND o.customer_id IS NOT NULL
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Customers who placed at least one order in the selected period vs the prior period.',
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
    '01a066fd-5a9f-72e4-84f9-08c3bf3109ab',
    'New Customers',
    'Customer Retention/Customer Overview/KPI/New Customers',
    $$
    WITH shop_customers AS (
        SELECT DISTINCT o.customer_id AS id
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
    )
    SELECT COUNT(*) AS new_customers
    FROM public.dim_customers c
    JOIN shop_customers sc ON sc.id = c.id
    WHERE c.created_at IS NOT NULL
      AND (:currentStartDate::date IS NULL OR c.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR c.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Customer records created in the selected period vs the prior period.',
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
    '01a066fd-5a9f-7ec6-963a-0d793ace62dc',
    'Repeat Customers',
    'Customer Retention/Customer Overview/KPI/Repeat Customers',
    $$
    WITH per_customer AS (
        SELECT o.customer_id,
               COUNT(*) AS orders
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY o.customer_id
    )
    SELECT COUNT(*) FILTER (WHERE orders > 1) AS repeat_customers
    FROM per_customer
    $$,
    NULL,
    'KPI',
    60,
    'Customers with more than one order in the selected period vs the prior period.',
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
    '01a066fd-5aa0-739d-ac77-5d8170f3f6f9',
    'Repeat Customer Rate',
    'Customer Retention/Customer Overview/KPI/Repeat Customer Rate',
    $$
    WITH per_customer AS (
        SELECT o.customer_id,
               COUNT(*) AS orders
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY o.customer_id
    )
    SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE orders > 1)
                 / NULLIF(COUNT(*) FILTER (WHERE orders > 0), 0), 2) AS repeat_customer_rate
    FROM per_customer
    $$,
    NULL,
    'KPI',
    60,
    'Repeat customers as a percentage of active customers, for the selected period vs the prior period.',
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
    '01a066fd-5aa1-74a4-870f-ac665291efa3',
    'Customer Revenue',
    'Customer Retention/Customer Revenue & Value/KPI/Customer Revenue',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(o.current_total_price, 0)
                            - COALESCE(o.current_total_tax, 0)
                            - COALESCE(o.current_shipping_price, 0)), 0), 2) AS customer_revenue
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND o.customer_id IS NOT NULL
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Net sales from identified customers for the selected period vs the prior period.',
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
    '01a066fd-5aa2-7c97-8b4a-a20ef553a19e',
    'Average Customer Value',
    'Customer Retention/Customer Revenue & Value/KPI/Average Customer Value',
    $$
    WITH per_customer AS (
        SELECT o.customer_id,
               SUM(COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0)) AS rev
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY o.customer_id
    )
    SELECT ROUND(COALESCE(SUM(rev), 0) / NULLIF(COUNT(*), 0), 2) AS average_customer_value
    FROM per_customer
    $$,
    NULL,
    'KPI',
    60,
    'Net sales per active customer for the selected period vs the prior period.',
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
    '01a066fd-5aa2-792f-810b-2c2685ab05d8',
    'Average Orders per Customer',
    'Customer Retention/Customer Revenue & Value/KPI/Average Orders per Customer',
    $$
    WITH per_customer AS (
        SELECT o.customer_id,
               COUNT(*) AS orders
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY o.customer_id
    )
    SELECT ROUND(COALESCE(SUM(orders), 0)::numeric / NULLIF(COUNT(*), 0), 2)
           AS average_orders_per_customer
    FROM per_customer
    $$,
    NULL,
    'KPI',
    60,
    'Orders per active customer for the selected period vs the prior period.',
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
    '01a066fd-5aa2-7d36-8b0a-8ed60dfb75fb',
    'High Value Customers',
    'Customer Retention/Customer Revenue & Value/KPI/High Value Customers',
    $$
    WITH per_customer AS (
        SELECT o.customer_id,
               SUM(COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0)) AS rev
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY o.customer_id
    ),
    cut AS (
        SELECT percentile_cont(0.8) WITHIN GROUP (ORDER BY rev)::numeric AS vip_cut
        FROM per_customer
    )
    SELECT COUNT(*) AS high_value_customers
    FROM per_customer c
    CROSS JOIN cut a
    WHERE a.vip_cut IS NOT NULL
      AND c.rev >= a.vip_cut
    $$,
    NULL,
    'KPI',
    60,
    'Customers in the top revenue quintile for the selected period vs the prior period.',
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
    '01a066fd-5aa5-7fb2-89a1-2330a080b43c',
    'Refund-Risk Customers',
    'Customer Retention/Customer Risk & Refund Analysis/KPI/Refund-Risk Customers',
    $$
    WITH order_refunds AS (
        SELECT o.id,
               o.customer_id,
               COALESCE(SUM(r.total_refunded_amount), 0) AS refunded
        FROM public.fact_order_headers o
        LEFT JOIN public.fact_order_refunds r ON r.order_id = o.id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY o.id, o.customer_id
    ),
    per_customer AS (
        SELECT customer_id, SUM(refunded) AS refunded
        FROM order_refunds
        GROUP BY customer_id
    ),
    cut AS (
        SELECT percentile_cont(0.8) WITHIN GROUP (ORDER BY refunded)::numeric AS cut
        FROM per_customer
    )
    SELECT COUNT(*) AS refund_risk_customers
    FROM per_customer c
    CROSS JOIN cut x
    WHERE x.cut IS NOT NULL
      AND c.refunded > 0
      AND c.refunded >= x.cut
    $$,
    NULL,
    'KPI',
    60,
    'Customers in the top refund quintile with non-zero refunds, for the selected period vs the prior period.',
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
    '01a066fd-5aa6-7e8e-a0c8-0e3bc66fb417',
    'New Customer Revenue',
    'Customer Retention/Customer Geography & Segmentation/KPI/New Customer Revenue',
    $$
    WITH customer_order_ranks AS (
        SELECT o.created_at::date AS day,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales,
               ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.created_at ASC, o.id ASC) AS order_rank
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
    ),
    known AS (
        SELECT COALESCE(SUM(r.net_sales), 0) AS rev
        FROM customer_order_ranks r
        WHERE r.order_rank = 1
          AND (:currentStartDate::date IS NULL OR r.day >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR r.day <= :currentEndDate::date)
    ),
    guests AS (
        SELECT COALESCE(SUM(COALESCE(o.current_total_price, 0)
                          - COALESCE(o.current_total_tax, 0)
                          - COALESCE(o.current_shipping_price, 0)), 0) AS rev
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NULL
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT ROUND(k.rev + g.rev, 2) AS new_customer_revenue
    FROM known k
    CROSS JOIN guests g
    $$,
    NULL,
    'KPI',
    60,
    'Net sales from first-time customers, including guest checkouts, for the selected period vs the prior period.',
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
    '01a066fd-5aa6-76c8-8869-fce5d97f195c',
    'Repeat Customer Revenue',
    'Customer Retention/Customer Geography & Segmentation/KPI/Repeat Customer Revenue',
    $$
    WITH customer_order_ranks AS (
        SELECT o.created_at::date AS day,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales,
               ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.created_at ASC, o.id ASC) AS order_rank
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
    )
    SELECT ROUND(COALESCE(SUM(r.net_sales), 0), 2) AS repeat_customer_revenue
    FROM customer_order_ranks r
    WHERE r.order_rank > 1
      AND (:currentStartDate::date IS NULL OR r.day >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR r.day <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Net sales from returning customers for the selected period vs the prior period.',
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
    '01a066fd-5aa8-7ac3-a64a-da5dbb91eb1d',
    'Tax Exempt Customers',
    'Customer Retention/Customer Operations & Compliance/KPI/Tax Exempt Customers',
    $$
    WITH cur_window AS (
        SELECT DISTINCT o.customer_id
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT COUNT(*) FILTER (WHERE c.taxExempt) AS tax_exempt_customers
    FROM public.dim_customers c
    JOIN cur_window w ON w.customer_id = c.id
    WHERE c.seller_id = :shopId
    $$,
    NULL,
    'KPI',
    60,
    'Tax exempt customers active in the selected period vs the prior period.',
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
    '01a066fd-5aa8-7209-a3d7-fb5be4402c62',
    'Inactive Customers',
    'Customer Retention/Customer Operations & Compliance/KPI/Inactive Customers',
    $$
    WITH valid_orders AS (
        SELECT o.customer_id, o.created_at::date AS day
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
    ),
    anchor AS (
        SELECT COALESCE(:currentEndDate::date, (SELECT MAX(day) FROM valid_orders)) AS anchor
    ),
    last_order AS (
        SELECT v.customer_id, MAX(v.day) AS last_day
        FROM valid_orders v
        CROSS JOIN anchor a
        WHERE v.day <= a.anchor
        GROUP BY v.customer_id
    )
    SELECT COUNT(*) AS inactive_customers
    FROM last_order l
    CROSS JOIN anchor a
    WHERE a.anchor - l.last_day > 90
    $$,
    NULL,
    'KPI',
    60,
    'Customers with no order in the 90 days before the period end, vs the prior period.',
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
    '01a066fd-5aa8-7ca2-8650-760ff5d4c2b8',
    'Weak Address Customers',
    'Customer Retention/Customer Operations & Compliance/KPI/Weak Address Customers',
    $$
    WITH cur_window AS (
        SELECT DISTINCT o.customer_id
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT COUNT(DISTINCT ca.customer_id) AS weak_address_customers
    FROM public.dim_customer_addresses ca
    JOIN cur_window w ON w.customer_id = ca.customer_id
    WHERE ca.seller_id = :shopId
      AND (COALESCE(ca.coordinates_validated, FALSE) = FALSE
       OR COALESCE(LENGTH(TRIM(ca.address1)), 0) = 0
       OR COALESCE(LENGTH(TRIM(ca.city)), 0) = 0
       OR COALESCE(LENGTH(TRIM(ca.province)), 0) = 0
       OR COALESCE(LENGTH(TRIM(ca.country)), 0) = 0
       OR COALESCE(LENGTH(TRIM(ca.zip)), 0) = 0)
    $$,
    NULL,
    'KPI',
    60,
    'Active customers with incomplete or unvalidated addresses, vs the prior period.',
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
    '019fff9a-1dfc-7b01-8fb1-6a2b3c4d1001',
    '01a066fd-5a9f-79ea-8fec-483847f490c4',
    'total_customers',
    $$
    WITH per_customer AS (
        SELECT customer_id,
               COUNT(*) FILTER (WHERE is_current) AS cur_orders,
               COUNT(*) FILTER (WHERE is_prior)   AS prv_orders
        FROM (
            SELECT o.customer_id,
                   ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.customer_id IS NOT NULL
        ) t
        WHERE t.is_current OR t.is_prior
        GROUP BY customer_id
    ),
    totals AS (
        SELECT COUNT(*) FILTER (WHERE cur_orders > 0) AS cur_value,
               COUNT(*) FILTER (WHERE prv_orders > 0) AS prv_value
        FROM per_customer
    )
    SELECT t.prv_value AS previous_value,
           ROUND(100.0 * (t.cur_value - t.prv_value)
                 / NULLIF(ABS(t.prv_value), 0), 2) AS divergence
    FROM totals t
    $$
),
(
    '019fff9a-1dfc-7b02-8fb2-6a2b3c4d1002',
    '01a066fd-5a9f-72e4-84f9-08c3bf3109ab',
    'new_customers',
    $$
    WITH shop_customers AS (
        SELECT DISTINCT o.customer_id AS id
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
    ),
    news AS (
        SELECT COUNT(*) FILTER (WHERE is_current) AS cur_value,
               COUNT(*) FILTER (WHERE is_prior)   AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR c.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR c.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND c.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM public.dim_customers c
            JOIN shop_customers sc ON sc.id = c.id
            WHERE c.created_at IS NOT NULL
        ) n
        WHERE n.is_current OR n.is_prior
    )
    SELECT n.prv_value AS previous_value,
           ROUND(100.0 * (n.cur_value - n.prv_value)
                 / NULLIF(ABS(n.prv_value), 0), 2) AS divergence
    FROM news n
    $$
),
(
    '019fff9a-1dfc-7b03-8fb3-6a2b3c4d1003',
    '01a066fd-5a9f-7ec6-963a-0d793ace62dc',
    'repeat_customers',
    $$
    WITH per_customer AS (
        SELECT customer_id,
               COUNT(*) FILTER (WHERE is_current) AS cur_orders,
               COUNT(*) FILTER (WHERE is_prior)   AS prv_orders
        FROM (
            SELECT o.customer_id,
                   ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.customer_id IS NOT NULL
        ) t
        WHERE t.is_current OR t.is_prior
        GROUP BY customer_id
    ),
    repeats AS (
        SELECT COUNT(*) FILTER (WHERE cur_orders > 1) AS cur_value,
               COUNT(*) FILTER (WHERE prv_orders > 1) AS prv_value
        FROM per_customer
    )
    SELECT r.prv_value AS previous_value,
           ROUND(100.0 * (r.cur_value - r.prv_value)
                 / NULLIF(ABS(r.prv_value), 0), 2) AS divergence
    FROM repeats r
    $$
),
(
    '019fff9a-1dfc-7b04-8fb4-6a2b3c4d1004',
    '01a066fd-5aa0-739d-ac77-5d8170f3f6f9',
    'repeat_customer_rate',
    $$
    WITH per_customer AS (
        SELECT customer_id,
               COUNT(*) FILTER (WHERE is_current) AS cur_orders,
               COUNT(*) FILTER (WHERE is_prior)   AS prv_orders
        FROM (
            SELECT o.customer_id,
                   ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.customer_id IS NOT NULL
        ) t
        WHERE t.is_current OR t.is_prior
        GROUP BY customer_id
    ),
    computed AS (
        SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE cur_orders > 1)
                     / NULLIF(COUNT(*) FILTER (WHERE cur_orders > 0), 0), 2) AS cur_rate,
               ROUND(100.0 * COUNT(*) FILTER (WHERE prv_orders > 1)
                     / NULLIF(COUNT(*) FILTER (WHERE prv_orders > 0), 0), 2) AS prv_rate
        FROM per_customer
    )
    SELECT c.prv_rate AS previous_value,
           ROUND(100 * (c.cur_rate - c.prv_rate)
                 / NULLIF(ABS(c.prv_rate), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fff9a-1dfc-7b05-8fb5-6a2b3c4d1005',
    '01a066fd-5aa1-74a4-870f-ac665291efa3',
    'customer_revenue',
    $$
    WITH totals AS (
        SELECT COALESCE(SUM(net_sales) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior),   0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(o.current_total_price, 0)
                     - COALESCE(o.current_total_tax, 0)
                     - COALESCE(o.current_shipping_price, 0) AS net_sales
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.customer_id IS NOT NULL
        ) t
        WHERE t.is_current OR t.is_prior
    )
    SELECT ROUND(t.prv_value, 2) AS previous_value,
           ROUND(100 * (t.cur_value - t.prv_value)
                 / NULLIF(ABS(t.prv_value), 0), 2) AS divergence
    FROM totals t
    $$
),
(
    '019fff9a-1dfc-7b06-8fb6-6a2b3c4d1006',
    '01a066fd-5aa2-7c97-8b4a-a20ef553a19e',
    'average_customer_value',
    $$
    WITH scoped_orders AS (
        SELECT * FROM (
            SELECT o.customer_id,
                   ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(o.current_total_price, 0)
                     - COALESCE(o.current_total_tax, 0)
                     - COALESCE(o.current_shipping_price, 0) AS net_sales
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.customer_id IS NOT NULL
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    cur_agg AS (
        SELECT COALESCE(SUM(rev), 0) AS revenue, COUNT(*) AS customers
        FROM (SELECT customer_id, SUM(net_sales) AS rev FROM scoped_orders
              WHERE is_current GROUP BY customer_id) c
    ),
    prv_agg AS (
        SELECT COALESCE(SUM(rev), 0) AS revenue, COUNT(*) AS customers
        FROM (SELECT customer_id, SUM(net_sales) AS rev FROM scoped_orders
              WHERE is_prior GROUP BY customer_id) p
    ),
    computed AS (
        SELECT ROUND(ca.revenue / NULLIF(ca.customers, 0), 2) AS cur_acv,
               ROUND(pa.revenue / NULLIF(pa.customers, 0), 2) AS prv_acv
        FROM cur_agg ca
        CROSS JOIN prv_agg pa
    )
    SELECT c.prv_acv AS previous_value,
           ROUND(100 * (c.cur_acv - c.prv_acv)
                 / NULLIF(ABS(c.prv_acv), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fff9a-1dfc-7b07-8fb7-6a2b3c4d1007',
    '01a066fd-5aa2-792f-810b-2c2685ab05d8',
    'average_orders_per_customer',
    $$
    WITH scoped_orders AS (
        SELECT * FROM (
            SELECT o.customer_id,
                   ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.customer_id IS NOT NULL
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    cur_agg AS (
        SELECT COALESCE(SUM(orders), 0) AS orders, COUNT(*) AS customers
        FROM (SELECT customer_id, COUNT(*) AS orders FROM scoped_orders
              WHERE is_current GROUP BY customer_id) c
    ),
    prv_agg AS (
        SELECT COALESCE(SUM(orders), 0) AS orders, COUNT(*) AS customers
        FROM (SELECT customer_id, COUNT(*) AS orders FROM scoped_orders
              WHERE is_prior GROUP BY customer_id) p
    ),
    computed AS (
        SELECT ROUND(ca.orders::numeric / NULLIF(ca.customers, 0), 2) AS cur_aopc,
               ROUND(pa.orders::numeric / NULLIF(pa.customers, 0), 2) AS prv_aopc
        FROM cur_agg ca
        CROSS JOIN prv_agg pa
    )
    SELECT c.prv_aopc AS previous_value,
           ROUND(100 * (c.cur_aopc - c.prv_aopc)
                 / NULLIF(ABS(c.prv_aopc), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fff9a-1dfc-7b08-8fb8-6a2b3c4d1008',
    '01a066fd-5aa2-7d36-8b0a-8ed60dfb75fb',
    'high_value_customers',
    $$
    WITH scoped_orders AS (
        SELECT * FROM (
            SELECT o.customer_id,
                   ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(o.current_total_price, 0)
                     - COALESCE(o.current_total_tax, 0)
                     - COALESCE(o.current_shipping_price, 0) AS net_sales
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.customer_id IS NOT NULL
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    cur_customers AS (
        SELECT customer_id, SUM(net_sales) AS rev
        FROM scoped_orders WHERE is_current GROUP BY customer_id
    ),
    prv_customers AS (
        SELECT customer_id, SUM(net_sales) AS rev
        FROM scoped_orders WHERE is_prior GROUP BY customer_id
    ),
    cur_cut AS (
        SELECT percentile_cont(0.8) WITHIN GROUP (ORDER BY rev)::numeric AS vip_cut
        FROM cur_customers
    ),
    prv_cut AS (
        SELECT percentile_cont(0.8) WITHIN GROUP (ORDER BY rev)::numeric AS vip_cut
        FROM prv_customers
    ),
    cur_high AS (
        SELECT COUNT(*) AS n
        FROM cur_customers c CROSS JOIN cur_cut a
        WHERE a.vip_cut IS NOT NULL AND c.rev >= a.vip_cut
    ),
    prv_high AS (
        SELECT COUNT(*) AS n
        FROM prv_customers c CROSS JOIN prv_cut a
        WHERE a.vip_cut IS NOT NULL AND c.rev >= a.vip_cut
    )
    SELECT ph.n AS previous_value,
           ROUND(100.0 * (ch.n - ph.n)
                 / NULLIF(ABS(ph.n), 0), 2) AS divergence
    FROM cur_high ch
    CROSS JOIN prv_high ph
    $$
),
(
    '019fff9a-1dfc-7b09-8fb9-6a2b3c4d1009',
    '01a066fd-5aa5-7fb2-89a1-2330a080b43c',
    'refund_risk_customers',
    $$
    WITH scoped_orders AS (
        SELECT * FROM (
            SELECT o.id,
                   o.customer_id,
                   ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.customer_id IS NOT NULL
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    order_refunds AS (
        SELECT s.customer_id,
               s.is_current,
               s.is_prior,
               COALESCE(SUM(r.total_refunded_amount), 0) AS refunded
        FROM scoped_orders s
        LEFT JOIN public.fact_order_refunds r ON r.order_id = s.id
        GROUP BY s.id, s.customer_id, s.is_current, s.is_prior
    ),
    cur_customers AS (
        SELECT customer_id, SUM(refunded) AS refunded
        FROM order_refunds WHERE is_current GROUP BY customer_id
    ),
    prv_customers AS (
        SELECT customer_id, SUM(refunded) AS refunded
        FROM order_refunds WHERE is_prior GROUP BY customer_id
    ),
    cur_cut AS (
        SELECT percentile_cont(0.8) WITHIN GROUP (ORDER BY refunded)::numeric AS cut
        FROM cur_customers
    ),
    prv_cut AS (
        SELECT percentile_cont(0.8) WITHIN GROUP (ORDER BY refunded)::numeric AS cut
        FROM prv_customers
    ),
    cur_risk AS (
        SELECT COUNT(*) AS n
        FROM cur_customers c CROSS JOIN cur_cut x
        WHERE x.cut IS NOT NULL AND c.refunded > 0 AND c.refunded >= x.cut
    ),
    prv_risk AS (
        SELECT COUNT(*) AS n
        FROM prv_customers c CROSS JOIN prv_cut x
        WHERE x.cut IS NOT NULL AND c.refunded > 0 AND c.refunded >= x.cut
    )
    SELECT pr.n AS previous_value,
           ROUND(100.0 * (cr.n - pr.n)
                 / NULLIF(ABS(pr.n), 0), 2) AS divergence
    FROM cur_risk cr
    CROSS JOIN prv_risk pr
    $$
),
(
    '019fff9a-1dfc-7b0a-8fba-6a2b3c4d100a',
    '01a066fd-5aa6-7e8e-a0c8-0e3bc66fb417',
    'new_customer_revenue',
    $$
    WITH customer_order_ranks AS (
        SELECT o.created_at::date AS day,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales,
               ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.created_at ASC, o.id ASC) AS order_rank
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
    ),
    known AS (
        SELECT COALESCE(SUM(net_sales) FILTER (WHERE is_current AND order_rank = 1), 0) AS cur_new,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior   AND order_rank = 1), 0) AS prv_new
        FROM (
            SELECT r.order_rank,
                   r.net_sales,
                   ((:currentStartDate::date IS NULL OR r.day >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR r.day <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND r.day BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM customer_order_ranks r
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    guests AS (
        SELECT COALESCE(SUM(net_sales) FILTER (WHERE is_current), 0) AS cur_guest,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior),   0) AS prv_guest
        FROM (
            SELECT COALESCE(o.current_total_price, 0)
                     - COALESCE(o.current_total_tax, 0)
                     - COALESCE(o.current_shipping_price, 0) AS net_sales,
                   ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.customer_id IS NULL
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    computed AS (
        SELECT k.cur_new + g.cur_guest AS cur_value,
               k.prv_new + g.prv_guest AS prv_value
        FROM known k
        CROSS JOIN guests g
    )
    SELECT ROUND(c.prv_value, 2) AS previous_value,
           ROUND(100 * (c.cur_value - c.prv_value)
                 / NULLIF(ABS(c.prv_value), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fff9a-1dfc-7b0b-8fbb-6a2b3c4d100b',
    '01a066fd-5aa6-76c8-8869-fce5d97f195c',
    'repeat_customer_revenue',
    $$
    WITH customer_order_ranks AS (
        SELECT o.created_at::date AS day,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales,
               ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.created_at ASC, o.id ASC) AS order_rank
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
    ),
    known AS (
        SELECT COALESCE(SUM(net_sales) FILTER (WHERE is_current AND order_rank > 1), 0) AS cur_value,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior   AND order_rank > 1), 0) AS prv_value
        FROM (
            SELECT r.order_rank,
                   r.net_sales,
                   ((:currentStartDate::date IS NULL OR r.day >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR r.day <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND r.day BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM customer_order_ranks r
        ) t
        WHERE t.is_current OR t.is_prior
    )
    SELECT ROUND(k.prv_value, 2) AS previous_value,
           ROUND(100 * (k.cur_value - k.prv_value)
                 / NULLIF(ABS(k.prv_value), 0), 2) AS divergence
    FROM known k
    $$
),
(
    '019fff9a-1dfc-7b0c-8fbc-6a2b3c4d100c',
    '01a066fd-5aa8-7ac3-a64a-da5dbb91eb1d',
    'tax_exempt_customers',
    $$
    WITH valid_orders AS (
        SELECT o.customer_id, o.created_at::date AS day
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
    ),
    cur_window AS (
        SELECT DISTINCT customer_id FROM valid_orders
        WHERE (:currentStartDate::date IS NULL OR day >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR day <= :currentEndDate::date)
    ),
    prv_window AS (
        SELECT DISTINCT customer_id FROM valid_orders
        WHERE :priorStartDate::date IS NOT NULL
          AND day BETWEEN :priorStartDate::date AND :priorEndDate::date
    ),
    exempt AS (
        SELECT COUNT(*) FILTER (WHERE c.taxExempt) AS n
        FROM public.dim_customers c JOIN cur_window w ON w.customer_id = c.id
        WHERE c.seller_id = :shopId
    ),
    exempt_prv AS (
        SELECT COUNT(*) FILTER (WHERE c.taxExempt) AS n
        FROM public.dim_customers c JOIN prv_window w ON w.customer_id = c.id
        WHERE c.seller_id = :shopId
    )
    SELECT ep.n AS previous_value,
           ROUND(100.0 * (e.n - ep.n)
                 / NULLIF(ABS(ep.n), 0), 2) AS divergence
    FROM exempt e
    CROSS JOIN exempt_prv ep
    $$
),
(
    '019fff9a-1dfc-7b0d-8fbd-6a2b3c4d100d',
    '01a066fd-5aa8-7209-a3d7-fb5be4402c62',
    'inactive_customers',
    $$
    WITH valid_orders AS (
        SELECT o.customer_id, o.created_at::date AS day
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
    ),
    anchors AS (
        SELECT COALESCE(:currentEndDate::date, (SELECT MAX(day) FROM valid_orders)) AS cur_anchor,
               :priorEndDate::date AS prv_anchor
    ),
    cur_last AS (
        SELECT v.customer_id, MAX(v.day) AS last_day
        FROM valid_orders v CROSS JOIN anchors a
        WHERE v.day <= a.cur_anchor
        GROUP BY v.customer_id
    ),
    prv_last AS (
        SELECT v.customer_id, MAX(v.day) AS last_day
        FROM valid_orders v CROSS JOIN anchors a
        WHERE a.prv_anchor IS NOT NULL AND v.day <= a.prv_anchor
        GROUP BY v.customer_id
    ),
    inactive AS (
        SELECT (SELECT COUNT(*) FROM cur_last c CROSS JOIN anchors a
                WHERE a.cur_anchor - c.last_day > 90) AS cur_value,
               (SELECT COUNT(*) FROM prv_last p CROSS JOIN anchors a
                WHERE a.prv_anchor - p.last_day > 90) AS prv_value
    )
    SELECT i.prv_value AS previous_value,
           ROUND(100.0 * (i.cur_value - i.prv_value)
                 / NULLIF(ABS(i.prv_value), 0), 2) AS divergence
    FROM inactive i
    $$
),
(
    '019fff9a-1dfc-7b0e-8fbe-6a2b3c4d100e',
    '01a066fd-5aa8-7ca2-8650-760ff5d4c2b8',
    'weak_address_customers',
    $$
    WITH valid_orders AS (
        SELECT o.customer_id, o.created_at::date AS day
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
    ),
    cur_window AS (
        SELECT DISTINCT customer_id FROM valid_orders
        WHERE (:currentStartDate::date IS NULL OR day >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR day <= :currentEndDate::date)
    ),
    prv_window AS (
        SELECT DISTINCT customer_id FROM valid_orders
        WHERE :priorStartDate::date IS NOT NULL
          AND day BETWEEN :priorStartDate::date AND :priorEndDate::date
    ),
    weak_addr AS (
        SELECT COUNT(DISTINCT ca.customer_id) AS n
        FROM public.dim_customer_addresses ca
        JOIN cur_window w ON w.customer_id = ca.customer_id
        WHERE ca.seller_id = :shopId
          AND (COALESCE(ca.coordinates_validated, FALSE) = FALSE
           OR COALESCE(LENGTH(TRIM(ca.address1)), 0) = 0
           OR COALESCE(LENGTH(TRIM(ca.city)), 0) = 0
           OR COALESCE(LENGTH(TRIM(ca.province)), 0) = 0
           OR COALESCE(LENGTH(TRIM(ca.country)), 0) = 0
           OR COALESCE(LENGTH(TRIM(ca.zip)), 0) = 0)
    ),
    weak_addr_prv AS (
        SELECT COUNT(DISTINCT ca.customer_id) AS n
        FROM public.dim_customer_addresses ca
        JOIN prv_window w ON w.customer_id = ca.customer_id
        WHERE ca.seller_id = :shopId
          AND (COALESCE(ca.coordinates_validated, FALSE) = FALSE
           OR COALESCE(LENGTH(TRIM(ca.address1)), 0) = 0
           OR COALESCE(LENGTH(TRIM(ca.city)), 0) = 0
           OR COALESCE(LENGTH(TRIM(ca.province)), 0) = 0
           OR COALESCE(LENGTH(TRIM(ca.country)), 0) = 0
           OR COALESCE(LENGTH(TRIM(ca.zip)), 0) = 0)
    )
    SELECT wap.n AS previous_value,
           ROUND(100.0 * (wa.n - wap.n)
                 / NULLIF(ABS(wap.n), 0), 2) AS divergence
    FROM weak_addr wa
    CROSS JOIN weak_addr_prv wap
    $$
);
