--liquibase formatted sql logicalFilePath:20260812001_analytical_customer_retention.sql

----changeset deepankar.sharma:RW-45-1
--comment seed Customer Overview tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff9a-1dfa-7282-8db8-0ad49fdec2cc',
    'Customer Growth Trend',
    'Customer Retention/Customer Overview/PLOT/Customer Growth Trend',
    '
    WITH
    /*date_granularity_cte*/
    scoped_customers AS (
        SELECT DISTINCT c.id, date_trunc(LOWER(dp.g), c.created_at) AS bucket
        FROM public.dim_customers c
        JOIN public.fact_order_headers o ON o.customer_id = c.id
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND c.created_at IS NOT NULL
          AND c.created_at >= dp.start_bucket
          AND c.created_at <= :currentEndDate::date
    ),
    daily_new AS (
        SELECT sc.bucket, COUNT(*) AS new_customers
        FROM scoped_customers sc
        GROUP BY sc.bucket
    )
  SELECT CASE
           WHEN dp.g = 'DAY'     THEN to_char(df.bucket, 'Mon DD')
           WHEN dp.g = 'WEEK'    THEN to_char(df.bucket, 'Mon DD')
           WHEN dp.g = 'MONTH'   THEN to_char(df.bucket, 'Mon YYYY')
           WHEN dp.g = 'QUARTER' THEN 'Q' || EXTRACT(QUARTER FROM df.bucket)::int || ' ' || EXTRACT(YEAR FROM df.bucket)::int
           WHEN dp.g = 'YEAR'    THEN to_char(df.bucket, 'YYYY')
       END AS period,
       df.bucket,
       COALESCE(n.new_customers, 0) AS new_customers
FROM date_filler df
CROSS JOIN date_params dp
LEFT JOIN daily_new n ON n.bucket = df.bucket
ORDER BY df.bucket ASC
    ',
    NULL,
    'PLOT',
    60,
    'New customer acquisition growth trend grouped by dynamic date granularity.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "granularity":    { "source": "REQUEST_FILTER", "filterKey": "granularity" }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        { "provider": "DATE_GRANULARITY_CTE", "condition": "hasFilter:startDate", "placeholder": "/*date_granularity_cte*/",
          "args": { "startDateParam": "currentStartDate", "endDateParam": "currentEndDate", "granularityParam": "granularity" } }
      ]
    }'
),
    (
    '019fff9a-1dfb-7513-8ee7-49b421c93f16',
    'New vs Repeat Orders',
    'Customer Retention/Customer Overview/PLOT/New vs Repeat Orders',
    $$
    WITH
    /*date_granularity_cte*/
    customer_order_ranks AS (
    SELECT
        o.id,
        o.customer_id,
        o.created_at,
        date_trunc(LOWER(dp.g), o.created_at) AS bucket,
        ROW_NUMBER() OVER (
            PARTITION BY o.customer_id
            ORDER BY o.created_at ASC, o.id ASC
        ) AS order_rank
    FROM public.fact_order_headers o
    CROSS JOIN date_params dp
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND o.customer_id IS NOT NULL
      AND o.created_at <= dp.end_bucket
),
guest_orders AS (
    SELECT
        date_trunc(LOWER(dp.g), o.created_at) AS bucket
    FROM public.fact_order_headers o
    CROSS JOIN date_params dp
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND o.customer_id IS NULL
      AND o.created_at >= dp.start_bucket
      AND o.created_at <= dp.end_bucket
),
daily AS (
    SELECT
        r.bucket,
        COUNT(*) FILTER (
            WHERE r.order_rank = 1
        ) AS new_orders,
        COUNT(*) FILTER (
            WHERE r.order_rank > 1
        ) AS repeat_orders
    FROM customer_order_ranks r
    CROSS JOIN date_params dp
    WHERE r.created_at >= dp.start_bucket
      AND r.created_at <= dp.end_bucket
    GROUP BY r.bucket
),
daily_guests AS (
    SELECT
        g.bucket,
        COUNT(*) AS guest_new_orders
    FROM guest_orders g
    GROUP BY g.bucket
)
SELECT
    CASE
        WHEN dp.g = 'DAY'
            THEN to_char(df.bucket, 'Mon DD')
        WHEN dp.g = 'WEEK'
            THEN to_char(df.bucket, 'Mon DD')
        WHEN dp.g = 'MONTH'
            THEN to_char(df.bucket, 'Mon YYYY')
        WHEN dp.g = 'QUARTER'
            THEN 'Q'
                 || EXTRACT(QUARTER FROM df.bucket)::int
                 || ' '
                 || EXTRACT(YEAR FROM df.bucket)::int
        WHEN dp.g = 'YEAR'
            THEN to_char(df.bucket, 'YYYY')
    END AS period,
    df.bucket,
    COALESCE(d.new_orders, 0)
        + COALESCE(g.guest_new_orders, 0) AS new_orders,
    COALESCE(d.repeat_orders, 0) AS repeat_orders
FROM date_filler df
CROSS JOIN date_params dp
LEFT JOIN daily d
    ON d.bucket = df.bucket
LEFT JOIN daily_guests g
    ON g.bucket = df.bucket
ORDER BY df.bucket ASC;
    $$,
    NULL,
    'PLOT',
    60,
    'Comparative trend of new vs repeat order count grouped by dynamic date granularity.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "granularity":    { "source": "REQUEST_FILTER", "filterKey": "granularity" }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        { "provider": "DATE_GRANULARITY_CTE", "condition": "hasFilter:startDate", "placeholder": "/*date_granularity_cte*/",
          "args": { "startDateParam": "currentStartDate", "endDateParam": "currentEndDate", "granularityParam": "granularity" } }
      ]
    }'
),
    (
    '019fff9a-1dfb-727b-b29d-9f6592bc4660',
    'Customer Detail Report',
    'Customer Retention/Customer Overview/TABLE/Customer Detail Report',
    '
    WITH filtered_orders AS (
        SELECT o.id,
               o.customer_id,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.customer_id IS NOT NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    customer_totals AS (
        SELECT f.customer_id,
               COUNT(*) AS orders,
               SUM(f.net_sales) AS amount_spent
        FROM filtered_orders f
        GROUP BY f.customer_id
    ),
    customer_location AS (
        SELECT DISTINCT ON (ca.customer_id) ca.customer_id,
               CONCAT_WS(CHR(44) || CHR(32), ca.city, ca.province, ca.country) AS location
        FROM public.dim_customer_addresses ca
        WHERE ca.seller_id = :shopId
        ORDER BY ca.customer_id, ca.id
    )
    SELECT CASE WHEN LENGTH(CONCAT_WS(CHR(32), c.first_name, c.last_name)) > 0
                THEN CONCAT_WS(CHR(32), c.first_name, c.last_name)
                ELSE COALESCE(c.email, ''Guest'') END AS customer,
           c.email AS email,
           c.created_at::date::text AS created_date,
           t.orders AS orders,
           ROUND(t.amount_spent, 2) AS amount_spent,
           c.state AS state,
           COALESCE(c.taxExempt, FALSE) AS tax_exempt,
           CASE WHEN LENGTH(l.location) > 0 THEN l.location ELSE ''Unknown'' END AS location,
           COUNT(*) OVER() AS total_records
    FROM customer_totals t
    JOIN public.dim_customers c ON c.id = t.customer_id AND c.seller_id = :shopId
    LEFT JOIN customer_location l ON l.customer_id = c.id
    ORDER BY t.amount_spent DESC, c.id
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Detailed customer audit report showing email, creation date, orders count, total spend, tax exempt status, and location.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
    '019fff9a-1dfb-7807-bf9d-7db4e9fb7900',
    'New vs Repeat Customer Report',
    'Customer Retention/Customer Overview/TABLE/New vs Repeat Customer Report',
    '
    WITH customer_order_ranks AS (
        SELECT o.id,
               o.created_at::date AS day,
               ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.created_at ASC, o.id ASC) AS order_rank
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.customer_id IS NOT NULL
    ),
    guest_orders AS (
        SELECT o.id,
               o.created_at::date AS day
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.customer_id IS NULL
    ),
    classified AS (
        SELECT r.id,
               CASE WHEN r.order_rank = 1 THEN ''New'' ELSE ''Repeat'' END AS customer_type
        FROM customer_order_ranks r
        WHERE (:currentStartDate IS NULL OR r.day >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR r.day <= :currentEndDate::date)
        UNION ALL
        SELECT g.id,
               ''New'' AS customer_type
        FROM guest_orders g
        WHERE (:currentStartDate IS NULL OR g.day >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR g.day <= :currentEndDate::date)
    ),
    order_measures AS (
        SELECT cl.customer_type,
               o.id,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales,
               COALESCE(o.subtotal_price, 0) + COALESCE(o.total_discounts_amount, 0) AS gross_sales
        FROM classified cl
        JOIN public.fact_order_headers o ON o.id = cl.id
    ),
    type_totals AS (
        SELECT m.customer_type,
               COUNT(*) AS orders,
               SUM(m.net_sales) AS revenue,
               SUM(m.gross_sales) AS gross_sales
        FROM order_measures m
        GROUP BY m.customer_type
    ),
    type_refunds AS (
        SELECT m.customer_type,
               SUM(COALESCE(r.total_refunded_amount, 0)) AS refunded
        FROM public.fact_order_refunds r
        JOIN order_measures m ON m.id = r.order_id
        GROUP BY m.customer_type
    ),
    types(customer_type, sort_order) AS (
        VALUES (''New'', 1), (''Repeat'', 2)
    )
    SELECT ty.customer_type AS customer_type,
           COALESCE(t.orders, 0) AS orders,
           ROUND(COALESCE(t.revenue, 0), 2) AS revenue,
           COALESCE(ROUND(t.revenue / NULLIF(t.orders, 0), 2), 0) AS aov,
           COALESCE(ROUND(100 * COALESCE(rf.refunded, 0) / NULLIF(t.gross_sales, 0), 2), 0) AS refund_rate,
           COUNT(*) OVER() AS total_records
    FROM types ty
    LEFT JOIN type_totals t ON t.customer_type = ty.customer_type
    LEFT JOIN type_refunds rf ON rf.customer_type = ty.customer_type
    ORDER BY ty.sort_order
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Comparative summary table evaluating orders, revenue, AOV, and refund rate between New vs Repeat customers.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
);

--changeset deepankar.sharma:RW-45-2
--comment seed Customer Revenue & Value tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff9a-1dfb-76a0-844c-85dcf1a54191',
    'New vs Repeat Customer Revenue',
    'Customer Retention/Customer Revenue & Value/PLOT/New vs Repeat Customer Revenue',
    $$
    WITH
    /*date_granularity_cte*/
    customer_order_ranks AS (
        SELECT o.id,
               o.customer_id,
               date_trunc(LOWER(dp.g), o.created_at) AS bucket,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales,
               ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.created_at ASC, o.id ASC) AS order_rank
        FROM public.fact_order_headers o
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.customer_id IS NOT NULL
          AND o.created_at >= dp.start_bucket
          AND o.created_at <= :currentEndDate::date
    ),
    guest_orders AS (
        SELECT date_trunc(LOWER(dp.g), o.created_at) AS bucket,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM public.fact_order_headers o
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.customer_id IS NULL
          AND o.created_at >= dp.start_bucket
          AND o.created_at <= :currentEndDate::date
    ),
    daily AS (
        SELECT r.bucket,
               COALESCE(SUM(net_sales) FILTER (WHERE order_rank = 1), 0) AS new_revenue,
               COALESCE(SUM(net_sales) FILTER (WHERE order_rank > 1), 0) AS repeat_revenue
        FROM customer_order_ranks r
        GROUP BY r.bucket
    ),
    daily_guests AS (
        SELECT g.bucket, SUM(net_sales) AS guest_new_revenue
        FROM guest_orders g
        GROUP BY g.bucket
    )
    SELECT CASE
           WHEN dp.g = 'DAY'     THEN to_char(df.bucket, 'Mon DD')
           WHEN dp.g = 'WEEK'    THEN to_char(df.bucket, 'Mon DD')
           WHEN dp.g = 'MONTH'   THEN to_char(df.bucket, 'Mon YYYY')
           WHEN dp.g = 'QUARTER' THEN 'Q' || EXTRACT(QUARTER FROM df.bucket)::int || ' ' || EXTRACT(YEAR FROM df.bucket)::int
           WHEN dp.g = 'YEAR'    THEN to_char(df.bucket, 'YYYY')
       END AS period,
       df.bucket,
       ROUND(COALESCE(d.new_revenue, 0) + COALESCE(g.guest_new_revenue, 0), 2) AS new_revenue,
       ROUND(COALESCE(d.repeat_revenue, 0), 2) AS repeat_revenue
FROM date_filler df
CROSS JOIN date_params dp
LEFT JOIN daily d ON d.bucket = df.bucket
LEFT JOIN daily_guests g ON g.bucket = df.bucket
ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Revenue trend comparison between new vs repeat customers grouped by dynamic date granularity.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "granularity":    { "source": "REQUEST_FILTER", "filterKey": "granularity" }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        { "provider": "DATE_GRANULARITY_CTE", "condition": "hasFilter:startDate", "placeholder": "/*date_granularity_cte*/",
          "args": { "startDateParam": "currentStartDate", "endDateParam": "currentEndDate", "granularityParam": "granularity" } }
      ]
    }'
),
    (
    '019fff9a-1dfb-7d54-ae3f-df0d8febed39',
    'Revenue by Customer Segment',
    'Customer Retention/Customer Revenue & Value/PLOT/Revenue by Customer Segment',
    '
    WITH per_customer AS (
        SELECT o.customer_id,
               SUM(COALESCE(o.current_total_price, 0)
                   - COALESCE(o.current_total_tax, 0)
                   - COALESCE(o.current_shipping_price, 0)) AS revenue
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.customer_id IS NOT NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY o.customer_id
    ),
    customer_span AS (
        SELECT o.customer_id,
               MIN(o.created_at)::date AS first_order,
               MAX(o.created_at)::date AS last_order
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.customer_id IS NOT NULL
        GROUP BY o.customer_id
    ),
    win AS (
        SELECT :currentStartDate::date AS req_start,
               :currentEndDate::date AS req_end,
               COALESCE(:currentEndDate::date, (SELECT MAX(last_order) FROM customer_span)) AS end_day
    ),
    vip AS (
        SELECT percentile_cont(0.8) WITHIN GROUP (ORDER BY revenue)::numeric AS vip_cut
        FROM per_customer
    ),
    classified AS (
        SELECT p.revenue,
               CASE WHEN w.req_start IS NOT NULL
                     AND s.first_order >= w.req_start
                     AND (w.req_end IS NULL OR s.first_order <= w.req_end)   THEN ''New''
                    WHEN v.vip_cut IS NOT NULL AND p.revenue >= v.vip_cut    THEN ''VIP''
                    WHEN s.last_order < w.end_day - 60                       THEN ''At-risk''
                    ELSE ''Repeat'' END AS segment
        FROM per_customer p
        JOIN customer_span s ON s.customer_id = p.customer_id
        CROSS JOIN win w
        CROSS JOIN vip v
    ),
    segment_totals AS (
        SELECT segment, SUM(revenue) AS revenue
        FROM classified
        GROUP BY segment
    ),
    segments(segment, sort_order) AS (
        VALUES (''New'', 1), (''At-risk'', 2), (''VIP'', 3), (''Repeat'', 4)
    )
    SELECT sg.segment AS segment,
           ROUND(COALESCE(st.revenue, 0), 2) AS revenue
    FROM segments sg
    LEFT JOIN segment_totals st ON st.segment = sg.segment
    ORDER BY sg.sort_order
    ',
    NULL,
    'PLOT',
    60,
    'Revenue contribution breakdown across customer segments (New, At-risk, VIP, Repeat).',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
    '019fff9a-1dfb-7047-bd5e-e1400ef79384',
    'Top Customers by Revenue',
    'Customer Retention/Customer Revenue & Value/PLOT/Top Customers by Revenue',
    '
    WITH per_customer AS (
        SELECT o.customer_id,
               SUM(COALESCE(o.current_total_price, 0)
                   - COALESCE(o.current_total_tax, 0)
                   - COALESCE(o.current_shipping_price, 0)) AS revenue
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.customer_id IS NOT NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY o.customer_id
    )
    SELECT CASE WHEN LENGTH(CONCAT_WS(CHR(32), c.first_name, c.last_name)) > 0
                THEN CONCAT_WS(CHR(32), c.first_name, c.last_name)
                     || CHR(32) || CHR(40)
                     || COALESCE(c.email, c.id::text)
                     || CHR(41)
                ELSE COALESCE(c.email, ''Guest'') END AS customer,
           ROUND(p.revenue, 2) AS revenue
    FROM per_customer p
    JOIN public.dim_customers c ON c.id = p.customer_id
    ORDER BY p.revenue DESC, c.id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Top individual customers ranked by total net spend revenue.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
    '019fff9a-1dfb-718e-b555-8d50bbaff35c',
    'Customer Value Distribution',
    'Customer Retention/Customer Revenue & Value/PLOT/Customer Value Distribution',
    '
    WITH per_customer AS (
        SELECT o.customer_id,
               SUM(COALESCE(o.current_total_price, 0)
                   - COALESCE(o.current_total_tax, 0)
                   - COALESCE(o.current_shipping_price, 0)) AS revenue
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.customer_id IS NOT NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY o.customer_id
    ),
    bucket_defs(ord, lo, hi) AS (
        VALUES (1, 0, 250), (2, 250, 500), (3, 500, 1000), (4, 1000, 2500),
               (5, 2500, 5000), (6, 5000, 10000), (7, 10000, NULL::int)
    )
    SELECT CASE WHEN b.hi IS NULL THEN b.lo::text || CHR(43)
                ELSE b.lo::text || CHR(45) || b.hi::text END AS spend_bucket,
           COUNT(p.revenue) AS customer_count
    FROM bucket_defs b
    LEFT JOIN per_customer p ON p.revenue >= b.lo AND (b.hi IS NULL OR p.revenue < b.hi)
    GROUP BY b.ord, b.lo, b.hi
    ORDER BY b.ord
    ',
    NULL,
    'PLOT',
    60,
    'Customer count distribution across revenue spend brackets.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
    '019fff9a-1dfb-76bb-bfd3-3eee427a2d97',
    'High-Value Customer Report',
    'Customer Retention/Customer Revenue & Value/TABLE/High-Value Customer Report',
    '
    WITH per_customer AS (
        SELECT o.customer_id,
               SUM(COALESCE(o.current_total_price, 0)
                   - COALESCE(o.current_total_tax, 0)
                   - COALESCE(o.current_shipping_price, 0)) AS revenue,
               COUNT(*) AS orders,
               MAX(o.created_at)::date AS last_order_date
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.customer_id IS NOT NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY o.customer_id
    ),
    vip AS (
        SELECT percentile_cont(0.8) WITHIN GROUP (ORDER BY revenue)::numeric AS vip_cut
        FROM per_customer
    ),
    customer_location AS (
        SELECT DISTINCT ON (ca.customer_id) ca.customer_id, ca.city, ca.country
        FROM public.dim_customer_addresses ca
        WHERE ca.seller_id = :shopId
        ORDER BY ca.customer_id, ca.id
    )
    SELECT CASE WHEN LENGTH(CONCAT_WS(CHR(32), c.first_name, c.last_name)) > 0
                THEN CONCAT_WS(CHR(32), c.first_name, c.last_name)
                ELSE COALESCE(c.email, ''Guest'') END AS customer,
           ROUND(p.revenue, 2) AS revenue,
           p.orders AS orders,
           ROUND(p.revenue / NULLIF(p.orders, 0), 2) AS aov,
           p.last_order_date::text AS last_order_date,
           l.city AS city,
           l.country AS country,
           COUNT(*) OVER() AS total_records
    FROM per_customer p
    CROSS JOIN vip v
    JOIN public.dim_customers c ON c.id = p.customer_id AND c.seller_id = :shopId
    LEFT JOIN customer_location l ON l.customer_id = p.customer_id
    WHERE v.vip_cut IS NOT NULL AND p.revenue >= v.vip_cut
    ORDER BY p.revenue DESC, c.id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Audit table listing VIP high-value customers with revenue, orders, AOV, last order date, and city/country.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
);

--changeset deepankar.sharma:RW-45-3
--comment seed Customer Retention & Loyalty tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff9a-1dfb-756f-bf31-02577fcf2164',
    'Orders per Customer Distribution',
    'Customer Retention/Customer Retention & Loyalty/PLOT/Orders per Customer Distribution',
    '
    WITH per_customer AS (
        SELECT o.customer_id, COUNT(*) AS order_count
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.customer_id IS NOT NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY o.customer_id
    ),
    bucket_defs(ord, lo, hi) AS (
        VALUES (1, 1, 1), (2, 2, 2), (3, 3, 5), (4, 6, 10), (5, 11, 20), (6, 21, NULL::int)
    )
    SELECT CASE WHEN b.hi IS NULL THEN b.lo::text || CHR(43)
                WHEN b.lo = b.hi  THEN b.lo::text
                ELSE b.lo::text || CHR(45) || b.hi::text END AS order_bucket,
           COUNT(p.order_count) AS customer_count
    FROM bucket_defs b
    LEFT JOIN per_customer p ON p.order_count >= b.lo AND (b.hi IS NULL OR p.order_count <= b.hi)
    GROUP BY b.ord, b.lo, b.hi
    ORDER BY b.ord
    ',
    NULL,
    'PLOT',
    60,
    'Customer distribution across lifetime order frequency tiers (1 order to 21+ orders).',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
    '019fff9a-1dfb-70e1-9bb5-d0221b4e1569',
    'Customer Revenue Cohort',
    'Customer Retention/Customer Retention & Loyalty/PLOT/Customer Revenue Cohort',
    '
    WITH ranked AS (
        SELECT o.customer_id,
               o.created_at::date AS day,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales,
               ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.created_at ASC, o.id ASC) AS order_rank
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.customer_id IS NOT NULL
    ),
    first_order AS (
        SELECT customer_id, MIN(day) AS first_day FROM ranked GROUP BY customer_id
    ),
    cohort_members AS (
        SELECT f.customer_id,
               f.first_day,
               make_date(EXTRACT(YEAR FROM f.first_day)::int,
                         EXTRACT(MONTH FROM f.first_day)::int, 1) AS cohort_month
        FROM first_order f
        WHERE (:currentStartDate IS NULL OR f.first_day >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR f.first_day <= :currentEndDate::date)
    ),
    cohort_list AS (
        SELECT DISTINCT cohort_month FROM cohort_members
    ),
    cohort_totals AS (
        SELECT m.cohort_month,
               LEAST((EXTRACT(YEAR FROM r.day)::int - EXTRACT(YEAR FROM m.first_day)::int) * 12
                   + (EXTRACT(MONTH FROM r.day)::int - EXTRACT(MONTH FROM m.first_day)::int), 5) AS month_offset,
               SUM(r.net_sales) AS net_sales
        FROM ranked r
        JOIN cohort_members m ON m.customer_id = r.customer_id
        WHERE r.order_rank > 1
        GROUP BY m.cohort_month, 2
    )
    SELECT EXTRACT(YEAR FROM cl.cohort_month)::text || CHR(45)
             || LPAD(EXTRACT(MONTH FROM cl.cohort_month)::text, 2, CHR(48)) AS cohort,
           ROUND(COALESCE(SUM(ct.net_sales) FILTER (WHERE ct.month_offset = 0), 0), 2) AS "Month 0",
           CASE WHEN cl.cohort_month + INTERVAL ''1 month''
                     <= date_trunc(''month'', CURRENT_DATE)
                THEN ROUND(COALESCE(SUM(ct.net_sales) FILTER (WHERE ct.month_offset = 1), 0), 2)
                END AS "Month 1",
           CASE WHEN cl.cohort_month + INTERVAL ''2 month''
                     <= date_trunc(''month'', CURRENT_DATE)
                THEN ROUND(COALESCE(SUM(ct.net_sales) FILTER (WHERE ct.month_offset = 2), 0), 2)
                END AS "Month 2",
           CASE WHEN cl.cohort_month + INTERVAL ''3 month''
                     <= date_trunc(''month'', CURRENT_DATE)
                THEN ROUND(COALESCE(SUM(ct.net_sales) FILTER (WHERE ct.month_offset = 3), 0), 2)
                END AS "Month 3",
           CASE WHEN cl.cohort_month + INTERVAL ''4 month''
                     <= date_trunc(''month'', CURRENT_DATE)
                THEN ROUND(COALESCE(SUM(ct.net_sales) FILTER (WHERE ct.month_offset = 4), 0), 2)
                END AS "Month 4",
           CASE WHEN cl.cohort_month + INTERVAL ''5 month''
                     <= date_trunc(''month'', CURRENT_DATE)
                THEN ROUND(COALESCE(SUM(ct.net_sales) FILTER (WHERE ct.month_offset >= 5), 0), 2)
                END AS "Month 5+"
    FROM cohort_list cl
    LEFT JOIN cohort_totals ct ON ct.cohort_month = cl.cohort_month
    GROUP BY cl.cohort_month
    ORDER BY cl.cohort_month
    ',
    NULL,
    'PLOT',
    60,
    'Monthly cohort revenue matrix tracking repeat revenue over 0 to 5+ months. Cells a cohort has not yet aged into are left empty rather than shown as zero.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
    '019fff9a-1dfb-7501-93db-3e10a209f815',
    'Customer Cohort Report',
    'Customer Retention/Customer Retention & Loyalty/TABLE/Customer Cohort Report',
    $$
    WITH ranked AS (
        SELECT o.customer_id,
               o.created_at::date AS day,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales,
               ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.created_at ASC, o.id ASC) AS order_rank
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.customer_id IS NOT NULL
    ),
    first_order AS (
        SELECT customer_id, MIN(day) AS first_day FROM ranked GROUP BY customer_id
    ),
    cohort_params AS (
        SELECT 90 AS observation_days  
    ),
    cohort_members AS (
        SELECT f.customer_id,
               f.first_day,
               make_date(EXTRACT(YEAR FROM f.first_day)::int,
                         EXTRACT(MONTH FROM f.first_day)::int, 1) AS cohort_month
        FROM first_order f
        CROSS JOIN cohort_params cp
        WHERE (:currentStartDate IS NULL OR f.first_day >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR f.first_day <= :currentEndDate::date)
          AND f.first_day <= CURRENT_DATE - cp.observation_days
    ),
    cohort_size AS (
        SELECT cohort_month, COUNT(*) AS active_customers
        FROM cohort_members
        GROUP BY cohort_month
    ),
    cohort_repeat AS (
        SELECT m.cohort_month,
               COUNT(*) AS repeat_orders,
               SUM(r.net_sales) AS repeat_revenue,
               COUNT(DISTINCT r.customer_id) AS retained_customers
        FROM ranked r
        JOIN cohort_members m ON m.customer_id = r.customer_id
        CROSS JOIN cohort_params cp
        WHERE r.order_rank > 1
          AND r.day <= m.first_day + cp.observation_days
        GROUP BY m.cohort_month
    )
    SELECT EXTRACT(YEAR FROM s.cohort_month)::text || CHR(45)
             || LPAD(EXTRACT(MONTH FROM s.cohort_month)::text, 2, CHR(48)) AS first_order_month,
           s.active_customers AS active_customers,
           COALESCE(cr.repeat_orders, 0) AS repeat_orders,
           ROUND(COALESCE(cr.repeat_revenue, 0), 2) AS repeat_revenue,
           ROUND(100.0 * COALESCE(cr.retained_customers, 0)
                 / NULLIF(s.active_customers, 0), 2) AS retention_rate,
           COUNT(*) OVER() AS total_records
    FROM cohort_size s
    LEFT JOIN cohort_repeat cr ON cr.cohort_month = s.cohort_month
    ORDER BY s.cohort_month DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'TABLE',
    60,
    'Detailed monthly cohort analysis report evaluating active customers, repeat orders, repeat revenue, and retention rate %.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
);

--changeset deepankar.sharma:RW-45-4
--comment seed Customer Risk & Refund Analysis tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff9a-1dfb-7980-9aef-d4218448b532',
    'Refund-Risk Customers by Segment',
    'Customer Retention/Customer Risk & Refund Analysis/PLOT/Refund-Risk Customers by Segment',
    $$
    WITH customer_first AS (
        SELECT o.customer_id, MIN(o.created_at) AS first_at
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
        GROUP BY o.customer_id
    ),
    filtered_orders AS (
        SELECT o.id,
               CASE WHEN cf.first_at IS NULL OR o.created_at = cf.first_at
                    THEN 'New' ELSE 'Repeat' END AS segment
        FROM public.fact_order_headers o
        LEFT JOIN customer_first cf ON cf.customer_id = o.customer_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    order_refunds AS (
        SELECT r.order_id, SUM(r.total_refunded_amount) AS refund_amount
        FROM public.fact_order_refunds r
        JOIN filtered_orders f ON f.id = r.order_id
        GROUP BY r.order_id
    ),
    segments(ord, segment) AS (
        VALUES (1, 'New'), (2, 'Repeat')
    )
    SELECT s.segment AS segment,
           COALESCE(SUM(orf.refund_amount), 0) AS refund_amount,
           COALESCE(ROUND(100 * COUNT(orf.order_id)::numeric / NULLIF(COUNT(f.id), 0), 2), 0) AS refund_rate
    FROM segments s
    LEFT JOIN filtered_orders f ON f.segment = s.segment
    LEFT JOIN order_refunds orf ON orf.order_id = f.id
    GROUP BY s.ord, s.segment
    ORDER BY s.ord
    $$,
    NULL,
    'PLOT',
    60,
    'Refund dollar volume and refund rate % breakdown across customer segments.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
    '019fff9a-1dfb-702e-87f5-5d558c3b3a79',
    'Refund-Risk Customer Report',
    'Customer Retention/Customer Risk & Refund Analysis/TABLE/Refund-Risk Customer Report',
    '
    WITH scoped_orders AS (
        SELECT o.id,
               o.customer_id,
               COALESCE(o.subtotal_price, 0) + COALESCE(o.total_discounts_amount, 0) AS gross
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.customer_id IS NOT NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    order_refunds AS (
        SELECT s.id,
               s.customer_id,
               s.gross,
               COALESCE(SUM(r.total_refunded_amount), 0) AS refunded,
               COUNT(r.id) AS refund_rows,
               MAX(COALESCE(r.processed_at, r.created_at))::date AS last_refund_date
        FROM scoped_orders s
        LEFT JOIN public.fact_order_refunds r ON r.order_id = s.id
        GROUP BY s.id, s.customer_id, s.gross
    ),
    per_customer AS (
        SELECT customer_id,
               COUNT(*) AS orders,
               COUNT(*) FILTER (WHERE refund_rows > 0) AS refunded_orders,
               SUM(gross) AS gross,
               SUM(refunded) AS refunded,
               MAX(last_refund_date) AS last_refund_date
        FROM order_refunds
        GROUP BY customer_id
    )
    SELECT CASE WHEN LENGTH(CONCAT_WS(CHR(32), c.first_name, c.last_name)) > 0
                THEN CONCAT_WS(CHR(32), c.first_name, c.last_name)
                ELSE COALESCE(c.email, ''Guest'') END AS customer,
           p.orders AS orders,
           p.refunded_orders AS refunded_orders,
           ROUND(p.refunded, 2) AS refunded_amount,
           COALESCE(ROUND(100 * p.refunded / NULLIF(p.gross, 0), 2), 0) AS refund_rate,
           p.last_refund_date::text AS last_refund_date,
           COUNT(*) OVER() AS total_records
    FROM per_customer p
    JOIN public.dim_customers c ON c.id = p.customer_id
    WHERE p.refunded > 0
    ORDER BY p.refunded DESC, c.id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Detailed audit log table of high refund-risk customers listing orders, refunded count, refunded amount, refund rate %, and last refund date.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
);

--changeset deepankar.sharma:RW-45-5
--comment seed Customer Geography & Segmentation tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff9a-1dfb-7d51-aba5-9eac6880bcee',
    'Customer Geography',
    'Customer Retention/Customer Geography & Segmentation/PLOT/Customer Geography',
    '
    WITH located_orders AS (
        SELECT COALESCE(o.shipping_address #>> ''{country}'', ''Unknown'') AS country,
               o.customer_id,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT country AS country,
           ROUND(SUM(net_sales), 2) AS revenue,
           COUNT(*) AS orders,
           COUNT(DISTINCT customer_id) AS customers
    FROM located_orders
    GROUP BY country
    ORDER BY SUM(net_sales) DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Geographic breakdown of customer count, orders, and revenue per country.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
    '019fff9a-1dfb-7501-9628-e35284463dde',
    'Customer Location Revenue Ranking',
    'Customer Retention/Customer Geography & Segmentation/PLOT/Customer Location Revenue Ranking',
    '
    WITH located_orders AS (
        SELECT COALESCE(o.shipping_address #>> ''{city}'', ''Unknown'') AS city,
               COALESCE(o.shipping_address #>> ''{province}'', ''Unknown'') AS province,
               COALESCE(o.shipping_address #>> ''{country}'', ''Unknown'') AS country,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT CONCAT_WS(CHR(44) || CHR(32), NULLIF(city, ''Unknown''), NULLIF(province, ''Unknown''), NULLIF(country, ''Unknown'')) AS location,
           ROUND(SUM(net_sales), 2) AS revenue,
           ROUND(SUM(net_sales) / NULLIF(COUNT(*), 0), 2) AS aov
    FROM located_orders
    GROUP BY city, province, country
    ORDER BY SUM(net_sales) DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Ranking of top cities/regions by total customer revenue and AOV.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
    '019fff9a-1dfb-73e3-b8cb-cf8d48dde497',
    'Customer Geography Report',
    'Customer Retention/Customer Geography & Segmentation/TABLE/Customer Geography Report',
    '
    WITH located_orders AS (
        SELECT COALESCE(o.shipping_address #>> ''{country}'', ''Unknown'') AS country,
               COALESCE(o.shipping_address #>> ''{province}'', ''Unknown'') AS province,
               COALESCE(o.shipping_address #>> ''{city}'', ''Unknown'') AS city,
               o.customer_id,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT country AS country,
           province AS province,
           city AS city,
           COUNT(DISTINCT customer_id) AS customers,
           COUNT(*) AS orders,
           ROUND(SUM(net_sales), 2) AS revenue,
           ROUND(SUM(net_sales) / NULLIF(COUNT(*), 0), 2) AS aov,
           COUNT(*) OVER() AS total_records
    FROM located_orders
    GROUP BY country, province, city
    ORDER BY SUM(net_sales) DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Audit table breaking down customers, orders, revenue, and AOV per Country, Province, and City.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
);

--changeset deepankar.sharma:RW-45-6
--comment seed Customer Operations & Compliance tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff9a-1dfb-74e4-ac8d-73f6dc14ac98',
    'Tax-Exempt Customer Revenue',
    'Customer Retention/Customer Operations & Compliance/PLOT/Tax-Exempt Customer Revenue',
    '
    WITH order_status AS (
        SELECT CASE WHEN COALESCE(c.taxExempt, FALSE)
                    THEN ''Tax-Exempt'' ELSE ''Not Tax-Exempt'' END AS status,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM public.fact_order_headers o
        JOIN public.dim_customers c ON c.id = o.customer_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    status_totals AS (
        SELECT status, SUM(net_sales) AS revenue
        FROM order_status
        GROUP BY status
    ),
    statuses(status, sort_order) AS (
        VALUES (''Tax-Exempt'', 1), (''Not Tax-Exempt'', 2)
    )
    SELECT s.status AS tax_status,
           ROUND(COALESCE(t.revenue, 0), 2) AS revenue
    FROM statuses s
    LEFT JOIN status_totals t ON t.status = s.status
    ORDER BY s.sort_order
    ',
    NULL,
    'PLOT',
    60,
    'Revenue split comparison between tax-exempt vs taxable customer orders.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
    '019fff9a-1dfb-7bca-8834-63524c92900d',
    'Inactive Customer Aging',
    'Customer Retention/Customer Operations & Compliance/PLOT/Inactive Customer Aging',
    $$
    WITH valid_orders AS (
        SELECT o.customer_id, o.created_at::date AS day
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
    ),
    anchor AS (
        SELECT COALESCE(:currentEndDate::date, (SELECT MAX(day) FROM valid_orders)) AS anchor_day
    ),
    scoped AS (
        SELECT customer_id FROM valid_orders
        WHERE (:currentStartDate IS NULL OR day >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR day <= :currentEndDate::date)
        GROUP BY customer_id
    ),
    last_order AS (
        SELECT v.customer_id, (a.anchor_day - MAX(v.day)) AS days_inactive
        FROM valid_orders v
        CROSS JOIN anchor a
        JOIN scoped s ON s.customer_id = v.customer_id
        WHERE v.day <= a.anchor_day
        GROUP BY v.customer_id, a.anchor_day
        HAVING (a.anchor_day - MAX(v.day)) > 15
    ),
    bucket_defs(ord, lo, hi) AS (
        VALUES (1, 16, 30), (2, 31, 60), (3, 61, 90), (4, 91, 180), (5, 181, NULL::int)
    )
    SELECT CASE WHEN b.hi IS NULL THEN b.lo::text || CHR(43)
                ELSE b.lo::text || CHR(45) || b.hi::text END AS days_bucket,
           COUNT(l.customer_id) AS customer_count
    FROM bucket_defs b
    LEFT JOIN last_order l ON l.days_inactive >= b.lo AND (b.hi IS NULL OR l.days_inactive <= b.hi)
    GROUP BY b.ord, b.lo, b.hi
    ORDER BY b.ord
    $$,
    NULL,
    'PLOT',
    30,
    'Distribution of inactive customers across inactivity aging brackets (16-30 days to 181+ days).',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
    '019fff9a-1dfb-7e71-837c-54bae0ae10c2',
    'Inactive Customer Report',
    'Customer Retention/Customer Operations & Compliance/TABLE/Inactive Customer Report',
    '
    WITH valid_orders AS (
        SELECT o.customer_id,
               o.created_at::date AS day,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.customer_id IS NOT NULL
    ),
    anchor AS (
        SELECT COALESCE(:currentEndDate::date, (SELECT MAX(day) FROM valid_orders)) AS anchor_day
    ),
    lifetime AS (
        SELECT v.customer_id,
               MAX(v.day) AS last_order_date,
               SUM(v.net_sales) AS amount_spent,
               COUNT(*) AS number_of_orders
        FROM valid_orders v
        CROSS JOIN anchor a
        WHERE v.day <= a.anchor_day
        GROUP BY v.customer_id
    )
    SELECT CASE WHEN LENGTH(CONCAT_WS(CHR(32), c.first_name, c.last_name)) > 0
                THEN CONCAT_WS(CHR(32), c.first_name, c.last_name)
                ELSE COALESCE(c.email, c.id::text) END AS customer,
           l.last_order_date::text AS last_order_date,
           (a.anchor_day - l.last_order_date) AS days_inactive,
           ROUND(l.amount_spent, 2) AS amount_spent,
           l.number_of_orders AS number_of_orders,
           COUNT(*) OVER() AS total_records
    FROM lifetime l
    CROSS JOIN anchor a
    JOIN public.dim_customers c ON c.id = l.customer_id
    WHERE (a.anchor_day - l.last_order_date) > 90
    ORDER BY (a.anchor_day - l.last_order_date) DESC, c.id
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Detailed audit log table of inactive customers (>90 days) showing last order date, days inactive, total spend, and order count.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
    '019fff9a-1dfb-7814-b98f-0bdf98266f9a',
    'Tax-Exempt Customer Report',
    'Customer Retention/Customer Operations & Compliance/TABLE/Tax-Exempt Customer Report',
    '
    WITH per_customer AS (
        SELECT o.customer_id,
               COUNT(*) AS orders,
               SUM(COALESCE(o.current_total_price, 0)
                   - COALESCE(o.current_total_tax, 0)
                   - COALESCE(o.current_shipping_price, 0)) AS revenue
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.customer_id IS NOT NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY o.customer_id
    )
    SELECT CASE WHEN LENGTH(CONCAT_WS(CHR(32), c.first_name, c.last_name)) > 0
                THEN CONCAT_WS(CHR(32), c.first_name, c.last_name)
                ELSE COALESCE(c.email, c.id::text) END AS customer,
           COALESCE(c.taxExempt, FALSE) AS tax_exempt,
           CASE WHEN COALESCE(LENGTH(TRIM(c.taxExemptions::text)), 0) > 2
                THEN c.taxExemptions::text
                ELSE CHR(45) END AS exemptions,
           ROUND(p.revenue, 2) AS revenue,
           p.orders AS orders,
           COUNT(*) OVER() AS total_records
    FROM per_customer p
    JOIN public.dim_customers c ON c.id = p.customer_id
    WHERE COALESCE(c.taxExempt, FALSE) = TRUE
    ORDER BY p.revenue DESC, c.id
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Audit table listing tax-exempt customers, exemption reasons/types, net revenue, and total orders.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
    '019fff9a-1dfb-7217-b231-2c8856fc75a5',
    'Address Quality Report',
    'Customer Retention/Customer Operations & Compliance/TABLE/Address Quality Report',
    '
    WITH scoped_customers AS (
        SELECT DISTINCT o.customer_id
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.customer_id IS NOT NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT CASE WHEN LENGTH(CONCAT_WS(CHR(32), c.first_name, c.last_name)) > 0
                THEN CONCAT_WS(CHR(32), c.first_name, c.last_name)
                ELSE COALESCE(c.email, c.id::text) END AS customer,
           CONCAT_WS(CHR(32), ca.address1, ca.address2) AS address,
           ca.city AS city,
           ca.province AS province,
           ca.country AS country,
           COALESCE(ca.coordinates_validated, FALSE) AS coordinates_validated,
           CONCAT_WS(CHR(44) || CHR(32),
               CASE WHEN COALESCE(ca.coordinates_validated, FALSE) = FALSE
                    THEN ''Unvalidated coordinates'' END,
               CASE WHEN COALESCE(LENGTH(TRIM(ca.address1)), 0) = 0
                      OR COALESCE(LENGTH(TRIM(ca.city)), 0) = 0
                      OR COALESCE(LENGTH(TRIM(ca.province)), 0) = 0
                      OR COALESCE(LENGTH(TRIM(ca.country)), 0) = 0
                      OR COALESCE(LENGTH(TRIM(ca.zip)), 0) = 0
                    THEN ''Incomplete fields'' END) AS issues,
           COUNT(*) OVER() AS total_records
    FROM public.dim_customer_addresses ca
    JOIN scoped_customers s ON s.customer_id = ca.customer_id
    JOIN public.dim_customers c ON c.id = ca.customer_id AND c.seller_id = :shopId
    WHERE ca.seller_id = :shopId
      AND (COALESCE(ca.coordinates_validated, FALSE) = FALSE
       OR COALESCE(LENGTH(TRIM(ca.address1)), 0) = 0
       OR COALESCE(LENGTH(TRIM(ca.city)), 0) = 0
       OR COALESCE(LENGTH(TRIM(ca.province)), 0) = 0
       OR COALESCE(LENGTH(TRIM(ca.country)), 0) = 0
       OR COALESCE(LENGTH(TRIM(ca.zip)), 0) = 0)
    ORDER BY c.id, ca.id
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Audit table highlighting customer address quality issues (unvalidated coordinates, missing geolocation, incomplete address fields).',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
);