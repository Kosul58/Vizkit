--liquibase formatted sql logicalFilePath:20260723001_analytical_executive_store_health_data.sql

--changeset saugat:RW-34-1
--comment seed revenue overview tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31a-79f2-bf5a-2d2fb3884362',
    'Net Sales',
    'Executive Store Health/Revenue Overview/KPI/Net Sales',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(o.current_total_price, 0)
                            - COALESCE(o.current_total_tax, 0)
                            - COALESCE(o.current_shipping_price, 0)), 0), 2) AS net_sales
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Net sales (order total less tax and shipping) for the selected period vs the prior period.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"      },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"      },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate"     },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"       },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31a-7a01-8f01-1a2b3c4d0001',
    'Gross Sales',
    'Executive Store Health/Revenue Overview/KPI/Gross Sales',
    $$
    SELECT ROUND(COALESCE(SUM(li.original_unit_price * li.quantity), 0), 2) AS gross_sales
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
    'Gross sales (line item unit price x quantity, before discounts) for the selected period vs the prior period.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"      },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"      },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate"     },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"       },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31a-7a02-8f02-1a2b3c4d0002',
    'Orders',
    'Executive Store Health/Revenue Overview/KPI/Orders',
    $$
    SELECT COUNT(*) AS orders
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Total order volume for the selected period vs the prior period.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"      },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"      },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate"     },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"       },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31a-7a03-8f03-1a2b3c4d0003',
    'Average Order Value',
    'Executive Store Health/Revenue Overview/KPI/Average Order Value',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(o.current_total_price, 0)
                            - COALESCE(o.current_total_tax, 0)
                            - COALESCE(o.current_shipping_price, 0)), 0)
                 / NULLIF(COUNT(*), 0), 2) AS average_order_value
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Average order value (net sales per order) for the selected period vs the prior period.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"      },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"      },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate"     },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"       },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31a-722c-8303-27002345bfd8',
    'Sales Trend',
    'Executive Store Health/Revenue Overview/PLOT/Sales Trend',
    $$
    WITH
    /*date_granularity_cte*/
    filtered_orders AS (
        SELECT o.id,
               date_trunc(LOWER(dp.g), o.created_at) AS bucket,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM public.fact_order_headers o
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.created_at >= dp.start_bucket
          AND o.created_at <= dp.end_bucket
    ),
    scoped_refunds AS (
        SELECT date_trunc(LOWER(dp.g), r.created_at) AS bucket,
               COALESCE(r.total_refunded_amount, 0) AS amount
        FROM public.fact_order_refunds r
        JOIN public.fact_order_headers o ON o.id = r.order_id
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND r.created_at >= dp.start_bucket
          AND r.created_at <= dp.end_bucket
    ),
    daily_gross AS (
        SELECT f.bucket, SUM(li.original_unit_price * li.quantity) AS gross_sales
        FROM public.fact_order_line_items li
        JOIN filtered_orders f ON f.id = li.order_id
        GROUP BY f.bucket
    ),
    daily_net AS (
        SELECT f.bucket, SUM(f.net_sales) AS net_sales
        FROM filtered_orders f
        GROUP BY f.bucket
    ),
    daily_refunds AS (
        SELECT s.bucket, SUM(s.amount) AS refunds
        FROM scoped_refunds s
        GROUP BY s.bucket
    )
    SELECT CASE
               WHEN dp.g = 'DAY'     THEN to_char(df.bucket, 'Mon DD')
               WHEN dp.g = 'WEEK'    THEN to_char(df.bucket, 'Mon DD')
               WHEN dp.g = 'MONTH'   THEN to_char(df.bucket, 'Mon YYYY')
               WHEN dp.g = 'QUARTER' THEN 'Q' || EXTRACT(QUARTER FROM df.bucket)::int || ' ' || EXTRACT(YEAR FROM df.bucket)::int
               WHEN dp.g = 'YEAR'    THEN to_char(df.bucket, 'YYYY')
           END AS period,
           df.bucket,
           COALESCE(g.gross_sales, 0) AS gross_sales,
           COALESCE(n.net_sales, 0) AS net_sales,
           COALESCE(r.refunds, 0) AS refunds
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily_gross g ON g.bucket = df.bucket
    LEFT JOIN daily_net n ON n.bucket = df.bucket
    LEFT JOIN daily_refunds r ON r.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Breakdown of gross sales, net sales, and total refunds grouped by dynamic date granularity.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"      },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"      },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate"     },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"       },
        "granularity":      { "source": "REQUEST_FILTER", "filterKey": "granularity"   }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        { "provider": "DATE_GRANULARITY_CTE", "condition": "hasFilter:startDate", "placeholder": "/*date_granularity_cte*/",
          "args": { "startDateParam": "currentStartDate", "endDateParam": "currentEndDate", "granularityParam": "granularity" } }
      ]
    }'
),
(
    '019fff82-e31a-737a-a3b9-abbc1fbe6cf8',
    'Revenue Waterfall',
    'Executive Store Health/Revenue Overview/PLOT/Revenue Waterfall',
    $$
    WITH
    /*date_granularity_cte*/
    filtered_orders AS (
        SELECT o.id,
               date_trunc(LOWER(dp.g), o.created_at) AS bucket,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM public.fact_order_headers o
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.created_at >= dp.start_bucket
          AND o.created_at <= dp.end_bucket
    ),
    order_totals AS (
        SELECT f.bucket,
               COALESCE(SUM(f.net_sales), 0) AS net_sales
        FROM filtered_orders f
        GROUP BY f.bucket
    ),
    line_item_totals AS (
        SELECT f.bucket,
               COALESCE(SUM(li.original_unit_price * li.quantity), 0) AS gross_sales,
               COALESCE(SUM(li.total_discount_amount), 0) AS discounts
        FROM public.fact_order_line_items li
        JOIN filtered_orders f ON f.id = li.order_id
        GROUP BY f.bucket
    ),
    scoped_refunds AS (
        SELECT date_trunc(LOWER(dp.g), r.created_at) AS bucket,
               COALESCE(r.total_refunded_amount, 0) AS amount
        FROM public.fact_order_refunds r
        JOIN public.fact_order_headers o ON o.id = r.order_id
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND r.created_at >= dp.start_bucket
          AND r.created_at <= dp.end_bucket
    ),
    refund_totals AS (
        SELECT s.bucket,
               COALESCE(SUM(s.amount), 0) AS refunds
        FROM scoped_refunds s
        GROUP BY s.bucket
    ),
    stages AS (
        SELECT df.bucket,
               CASE
                   WHEN dp.g = 'DAY'     THEN to_char(df.bucket, 'Mon DD')
                   WHEN dp.g = 'WEEK'    THEN to_char(df.bucket, 'Mon DD')
                   WHEN dp.g = 'MONTH'   THEN to_char(df.bucket, 'Mon YYYY')
                   WHEN dp.g = 'QUARTER' THEN 'Q' || EXTRACT(QUARTER FROM df.bucket)::int || ' ' || EXTRACT(YEAR FROM df.bucket)::int
                   WHEN dp.g = 'YEAR'    THEN to_char(df.bucket, 'YYYY')
               END AS period_label,
               ROUND(COALESCE(l.gross_sales, 0), 2) AS gross_sales,
               ROUND(-COALESCE(l.discounts, 0), 2)  AS discount,
               ROUND(-COALESCE(r.refunds, 0), 2)    AS refunds,
               ROUND(COALESCE(t.net_sales, 0), 2)   AS net_sales
        FROM date_filler df
        CROSS JOIN date_params dp
        LEFT JOIN line_item_totals l ON l.bucket = df.bucket
        LEFT JOIN refund_totals r ON r.bucket = df.bucket
        LEFT JOIN order_totals t ON t.bucket = df.bucket
    )
    SELECT s.period_label AS category,
           s.gross_sales  AS "gross_sales",
           s.discount     AS "discount",
           s.refunds      AS "refunds",
           s.net_sales    AS "net_sales"
    FROM stages s
    ORDER BY s.bucket
    $$,
    NULL,
    'PLOT',
    60,
    'Waterfall analysis connecting Gross Sales to Net Sales via Discounts and Refunds, grouped by dynamic date granularity.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"    },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate"   },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"     },
        "granularity":      { "source": "REQUEST_FILTER", "filterKey": "granularity" }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        { "provider": "DATE_GRANULARITY_CTE", "condition": "hasFilter:startDate", "placeholder": "/*date_granularity_cte*/",
          "args": { "startDateParam": "currentStartDate", "endDateParam": "currentEndDate", "granularityParam": "granularity" } }
      ]
    }'
),
( 
    '019fff82-e31a-7ab8-9ab6-182f18146294',
    'Orders vs AOV',
    'Executive Store Health/Revenue Overview/PLOT/Orders vs AOV',
    $$
    WITH
    /*date_granularity_cte*/
    filtered_orders AS (
        SELECT date_trunc(LOWER(dp.g), o.created_at) AS bucket,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM public.fact_order_headers o
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.created_at >= dp.start_bucket
          AND o.created_at <= dp.end_bucket
    ),
    daily AS (
        SELECT f.bucket,
               COUNT(*) AS order_count,
               ROUND(SUM(f.net_sales) / COUNT(*), 2) AS aov
        FROM filtered_orders f
        GROUP BY f.bucket
    )
    SELECT CASE
               WHEN dp.g = 'DAY'     THEN to_char(df.bucket, 'Mon DD')
               WHEN dp.g = 'WEEK'    THEN to_char(df.bucket, 'Mon DD')
               WHEN dp.g = 'MONTH'   THEN to_char(df.bucket, 'Mon YYYY')
               WHEN dp.g = 'QUARTER' THEN 'Q' || EXTRACT(QUARTER FROM df.bucket)::int || ' ' || EXTRACT(YEAR FROM df.bucket)::int
               WHEN dp.g = 'YEAR'    THEN to_char(df.bucket, 'YYYY')
           END AS period,
           df.bucket,
           COALESCE(d.order_count, 0) AS order_count,
           COALESCE(d.aov, 0) AS aov
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily d ON d.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Correlation between total order count and Average Order Value (AOV) grouped by dynamic date granularity.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"    },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate"   },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"     },
        "granularity":      { "source": "REQUEST_FILTER", "filterKey": "granularity" }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        { "provider": "DATE_GRANULARITY_CTE", "condition": "hasFilter:startDate", "placeholder": "/*date_granularity_cte*/",
          "args": { "startDateParam": "currentStartDate", "endDateParam": "currentEndDate", "granularityParam": "granularity" } }
      ]
    }'
);

--changeset saugat:RW-34-2
--comment seed discount and refund tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31a-7689-b215-209e686ffcc3',
    'Discount & Refund KPIs',
    'Executive Store Health/Discount & Refund/KPI/Discount & Refund KPIs',
    $$
    WITH
    /*comparison_window_cte*/
    scoped_orders AS (
        SELECT * FROM (
            SELECT o.id,
                   ((w.cur_start IS NULL OR o.created_at::date >= w.cur_start)
                AND (w.cur_end   IS NULL OR o.created_at::date <= w.cur_end))  AS is_current,
                   (w.prv_start IS NOT NULL
                AND o.created_at::date BETWEEN w.prv_start AND w.prv_end)      AS is_prior
            FROM public.fact_order_headers o
            CROSS JOIN windows w
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    line_item_totals AS (
        SELECT COALESCE(SUM(li.original_unit_price * li.quantity)
                        FILTER (WHERE s.is_current), 0) AS cur_gross_sales,
               COALESCE(SUM(li.original_unit_price * li.quantity)
                        FILTER (WHERE s.is_prior),   0) AS prv_gross_sales,
               COALESCE(SUM(li.total_discount_amount)
                        FILTER (WHERE s.is_current), 0) AS cur_discounts,
               COALESCE(SUM(li.total_discount_amount)
                        FILTER (WHERE s.is_prior),   0) AS prv_discounts
        FROM public.fact_order_line_items li
        JOIN scoped_orders s ON s.id = li.order_id
    ),
    scoped_refunds AS (
        SELECT * FROM (
            SELECT ((w.cur_start IS NULL OR r.created_at::date >= w.cur_start)
                AND (w.cur_end   IS NULL OR r.created_at::date <= w.cur_end))  AS is_current,
                   (w.prv_start IS NOT NULL
                AND r.created_at::date BETWEEN w.prv_start AND w.prv_end)      AS is_prior,
                   COALESCE(r.total_refunded_amount, 0) AS amount
            FROM public.fact_order_refunds r
            JOIN public.fact_order_headers o ON o.id = r.order_id
            CROSS JOIN windows w
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    refund_totals AS (
        SELECT COALESCE(SUM(amount) FILTER (WHERE is_current), 0) AS cur_refunded,
               COALESCE(SUM(amount) FILTER (WHERE is_prior),   0) AS prv_refunded
        FROM scoped_refunds
    ),
    computed AS (
        SELECT rt.cur_refunded, rt.prv_refunded,
               ROUND(100 * rt.cur_refunded / NULLIF(lt.cur_gross_sales, 0), 2) AS cur_refund_rate,
               ROUND(100 * rt.prv_refunded / NULLIF(lt.prv_gross_sales, 0), 2) AS prv_refund_rate,
               ROUND(100 * lt.cur_discounts / NULLIF(lt.cur_gross_sales, 0), 2) AS cur_leakage,
               ROUND(100 * lt.prv_discounts / NULLIF(lt.prv_gross_sales, 0), 2) AS prv_leakage
        FROM refund_totals rt
        CROSS JOIN line_item_totals lt
    )
    SELECT ROUND(c.cur_refunded, 2) AS refunded_amount,
           ROUND(100 * (c.cur_refunded - c.prv_refunded)
                 / NULLIF(ABS(c.prv_refunded), 0), 2) AS refunded_amount_divergence,
           c.cur_refund_rate AS refund_rate,
           ROUND(100 * (c.cur_refund_rate - c.prv_refund_rate)
                 / NULLIF(ABS(c.prv_refund_rate), 0), 2) AS refund_rate_divergence,
           c.cur_leakage AS discount_leakage,
           ROUND(100 * (c.cur_leakage - c.prv_leakage)
                 / NULLIF(ABS(c.prv_leakage), 0), 2) AS discount_leakage_divergence
    FROM computed c
    $$,
    NULL,
    'KPI',
    60,
    'Overview metrics tracking refunded total, refund rate %, and discount revenue leakage % vs prior period.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"      },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"      },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate"     },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"       },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate"   }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        { "provider": "COMPARISON_WINDOW_CTE", "condition": "hasFilter:startDate", "placeholder": "/*comparison_window_cte*/",
          "args": { "currentStartParam": "currentStartDate", "currentEndParam": "currentEndDate", "priorStartParam": "priorStartDate", "priorEndParam": "priorEndDate" } }
      ]
    }'
),
(
    '019fff82-e31a-7d3c-8819-c9c6b13b5e8d',
    'Discount Impact Trend',
    'Executive Store Health/Discount & Refund/PLOT/Discount Impact Trend',
    $$
    WITH
    /*date_granularity_cte*/
    filtered_orders AS (
        SELECT o.id,
               date_trunc(LOWER(dp.g), o.created_at) AS bucket
        FROM public.fact_order_headers o
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.created_at >= dp.start_bucket
          AND o.created_at <= dp.end_bucket
    ),
    daily AS (
        SELECT f.bucket,
               COALESCE(SUM(li.total_discount_amount), 0) AS discount_amount,
               COALESCE(SUM(li.original_total_amount), 0) AS original_amount
        FROM public.fact_order_line_items li
        JOIN filtered_orders f ON f.id = li.order_id
        GROUP BY f.bucket
    )
    SELECT CASE
               WHEN dp.g = 'DAY'     THEN to_char(df.bucket, 'Mon DD')
               WHEN dp.g = 'WEEK'    THEN to_char(df.bucket, 'Mon DD')
               WHEN dp.g = 'MONTH'   THEN to_char(df.bucket, 'Mon YYYY')
               WHEN dp.g = 'QUARTER' THEN 'Q' || EXTRACT(QUARTER FROM df.bucket)::int || ' ' || EXTRACT(YEAR FROM df.bucket)::int
               WHEN dp.g = 'YEAR'    THEN to_char(df.bucket, 'YYYY')
           END AS period,
           df.bucket,
           ROUND(COALESCE(d.discount_amount, 0), 2) AS discount_amount,
           ROUND(100 * d.discount_amount / NULLIF(d.original_amount, 0), 2) AS discount_rate
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily d ON d.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Tracking of discount totals and discount rate % relative to gross sales grouped by dynamic date granularity.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"    },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate"   },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"     },
        "granularity":      { "source": "REQUEST_FILTER", "filterKey": "granularity" }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        { "provider": "DATE_GRANULARITY_CTE", "condition": "hasFilter:startDate", "placeholder": "/*date_granularity_cte*/",
          "args": { "startDateParam": "currentStartDate", "endDateParam": "currentEndDate", "granularityParam": "granularity" } }
      ]
    }'
),
(
    '019fff82-e31a-7430-9b0d-7d07b54cf0a2',
    'Refund Trend',
    'Executive Store Health/Discount & Refund/PLOT/Refund Trend',
    $$
    WITH
    /*date_granularity_cte*/
    scoped_refunds AS (
        SELECT date_trunc(LOWER(dp.g), r.created_at) AS bucket,
               COALESCE(r.total_refunded_amount, 0) AS amount
        FROM public.fact_order_refunds r
        JOIN public.fact_order_headers o ON o.id = r.order_id
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND r.created_at >= dp.start_bucket
          AND r.created_at <= dp.end_bucket
    ),
    daily AS (
        SELECT s.bucket,
               SUM(s.amount) AS refunded_amount,
               COUNT(*) AS refund_count
        FROM scoped_refunds s
        GROUP BY s.bucket
    )
    SELECT CASE
               WHEN dp.g = 'DAY'     THEN to_char(df.bucket, 'Mon DD')
               WHEN dp.g = 'WEEK'    THEN to_char(df.bucket, 'Mon DD')
               WHEN dp.g = 'MONTH'   THEN to_char(df.bucket, 'Mon YYYY')
               WHEN dp.g = 'QUARTER' THEN 'Q' || EXTRACT(QUARTER FROM df.bucket)::int || ' ' || EXTRACT(YEAR FROM df.bucket)::int
               WHEN dp.g = 'YEAR'    THEN to_char(df.bucket, 'YYYY')
           END AS period,
           df.bucket,
           ROUND(COALESCE(d.refunded_amount, 0), 2) AS refunded_amount,
           COALESCE(d.refund_count, 0) AS refund_count
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily d ON d.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Trend of total refunded dollar value and refund count grouped by dynamic date granularity.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"    },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate"   },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"     },
        "granularity":      { "source": "REQUEST_FILTER", "filterKey": "granularity" }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        { "provider": "DATE_GRANULARITY_CTE", "condition": "hasFilter:startDate", "placeholder": "/*date_granularity_cte*/",
          "args": { "startDateParam": "currentStartDate", "endDateParam": "currentEndDate", "granularityParam": "granularity" } }
      ]
    }'
),
(
    '019fff82-e31a-7f7d-b294-6e3cc8e3a7a7',
    'Top Refunded Products',
    'Executive Store Health/Discount & Refund/PLOT/Top Refunded Products',
    $$
    WITH
    scoped_refunds AS (
        SELECT r.order_id,
               SUM(COALESCE(r.total_refunded_amount, 0)) AS refunded
        FROM public.fact_order_refunds r
        JOIN public.fact_order_headers o ON o.id = r.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR r.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR r.created_at::date <= :currentEndDate::date)
        GROUP BY r.order_id
    ),
    refunded_lines AS (
        SELECT li.order_id,
               li.product_variant_id,
               li.quantity,
               GREATEST(COALESCE(li.quantity, 0)
                        - COALESCE(li.refundable_quantity, li.quantity), 0) AS units_returned,
               COALESCE(li.discounted_total_amount, li.original_unit_price * li.quantity, 0) AS line_value
        FROM public.fact_order_line_items li
        JOIN scoped_refunds s ON s.order_id = li.order_id
    ),
    line_share AS (
        SELECT rl.order_id,
               rl.product_variant_id,
               rl.quantity,
               rl.units_returned,
               rl.line_value,
               SUM(rl.line_value) OVER (PARTITION BY rl.order_id) AS order_value,
               SUM(rl.units_returned) OVER (PARTITION BY rl.order_id) AS order_units_returned
        FROM refunded_lines rl
    ),
    allocated AS (
        SELECT ls.product_variant_id,
               ls.units_returned,
               CASE WHEN ls.order_units_returned > 0
                    THEN ls.units_returned * ls.line_value / NULLIF(ls.quantity, 0)
                    ELSE s.refunded * ls.line_value / NULLIF(ls.order_value, 0)
               END AS refund_value
        FROM line_share ls
        JOIN scoped_refunds s ON s.order_id = ls.order_id
    )
    SELECT COALESCE(p.title, pv.sku, pv.id) AS product,
           ROUND(SUM(a.refund_value), 2) AS refund_value,
           SUM(a.units_returned) AS units_returned
    FROM allocated a
    JOIN public.dim_product_variants pv ON pv.id = a.product_variant_id
    LEFT JOIN public.dim_products p ON p.id = pv.product_id
    GROUP BY COALESCE(p.title, pv.sku, pv.id)
    ORDER BY refund_value DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'PLOT',
    60,
    'Top products by refund dollar value and returned units.',
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

--changeset saugat:RW-34-3
--comment seed inventory and opeartions tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31a-7d0f-a3ed-86fca428844f',
    'Inventory & Operations KPIs',
    'Executive Store Health/Inventory & Operations/KPI/Inventory & Operations KPIs',
    $$
    WITH
    /*comparison_window_cte*/
    scoped_orders AS (
        SELECT * FROM (
            SELECT o.id,
                   o.created_at::date AS day,
                   ((w.cur_start IS NULL OR o.created_at::date >= w.cur_start)
                AND (w.cur_end   IS NULL OR o.created_at::date <= w.cur_end))  AS is_current,
                   (w.prv_start IS NOT NULL
                AND o.created_at::date BETWEEN w.prv_start AND w.prv_end)      AS is_prior,
                   COALESCE(o.total_outstanding_amount, 0) AS outstanding
            FROM public.fact_order_headers o
            CROSS JOIN windows w
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    period AS (
        SELECT GREATEST(COALESCE(w.cur_end, (SELECT MAX(day) FROM scoped_orders WHERE is_current))
                      - COALESCE(w.cur_start, (SELECT MIN(day) FROM scoped_orders WHERE is_current))
                      + 1, 1) AS cur_days,
               GREATEST(w.prv_end - w.prv_start + 1, 1) AS prv_days
        FROM windows w
    ),
    variant_sales AS (
        SELECT li.product_variant_id AS variant_id,
               COALESCE(SUM(li.quantity) FILTER (WHERE s.is_current), 0) AS cur_units,
               COALESCE(SUM(li.quantity) FILTER (WHERE s.is_prior),   0) AS prv_units,
               COALESCE(SUM(li.original_unit_price * li.quantity)
                        FILTER (WHERE s.is_current), 0) AS cur_revenue,
               COALESCE(SUM(li.original_unit_price * li.quantity)
                        FILTER (WHERE s.is_prior),   0) AS prv_revenue
        FROM public.fact_order_line_items li
        JOIN scoped_orders s ON s.id = li.order_id
        GROUP BY li.product_variant_id
    ),
    variant_stock AS (
        SELECT pv.id AS variant_id,
               SUM(COALESCE(lvl.available_quantity, lvl.on_hand_quantity, 0)) AS available
        FROM public.dim_inventory_levels lvl
        JOIN public.dim_inventory_items ii ON ii.id = lvl.inventory_item_id
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        WHERE lvl.seller_id = :shopId
        GROUP BY pv.id
    ),
    variant_risk AS (
        SELECT vs.cur_revenue,
               vs.prv_revenue,
               st.available / NULLIF(vs.cur_units::numeric / p.cur_days, 0) AS cur_cover,
               st.available / NULLIF(vs.prv_units::numeric / p.prv_days, 0) AS prv_cover
        FROM variant_sales vs
        JOIN variant_stock st ON st.variant_id = vs.variant_id
        CROSS JOIN period p
    ),
    risk_totals AS (
        SELECT COALESCE(SUM(cur_revenue) FILTER (WHERE cur_cover < 14), 0) AS cur_risk,
               COALESCE(SUM(prv_revenue) FILTER (WHERE prv_cover < 14), 0) AS prv_risk
        FROM variant_risk
    ),
    outstanding AS (
        SELECT COALESCE(SUM(outstanding) FILTER (WHERE is_current), 0) AS cur_outstanding,
               COALESCE(SUM(outstanding) FILTER (WHERE is_prior),   0) AS prv_outstanding
        FROM scoped_orders
    )
    SELECT ROUND(rt.cur_risk, 2) AS low_stock_revenue_risk,
           ROUND(100 * (rt.cur_risk - rt.prv_risk)
                 / NULLIF(ABS(rt.prv_risk), 0), 2) AS low_stock_revenue_risk_divergence,
           ROUND(o.cur_outstanding, 2) AS outstanding_amount,
           ROUND(100 * (o.cur_outstanding - o.prv_outstanding)
                 / NULLIF(ABS(o.prv_outstanding), 0), 2) AS outstanding_amount_divergence
    FROM risk_totals rt
    CROSS JOIN outstanding o
    $$,
    NULL,
    'KPI',
    60,
    'Metrics tracking low-stock revenue risk and total outstanding unpaid order balances.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"      },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"      },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate"     },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"       },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate"   }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        { "provider": "COMPARISON_WINDOW_CTE", "condition": "hasFilter:startDate", "placeholder": "/*comparison_window_cte*/",
          "args": { "currentStartParam": "currentStartDate", "currentEndParam": "currentEndDate", "priorStartParam": "priorStartDate", "priorEndParam": "priorEndDate" } }
      ]
    }'
),
(
    '019fff82-e31a-74eb-9293-d7aa7f1356da',
    'Stock Value by Location',
    'Executive Store Health/Inventory & Operations/PLOT/Stock Value by Location',
    $$
    WITH
    base_locations AS (
        SELECT loc.name AS location,
               ROUND(SUM(COALESCE(lvl.on_hand_quantity, 0) * COALESCE(ii.unit_cost, 0)), 2) AS stock_value
        FROM public.dim_inventory_levels lvl
        JOIN public.dim_inventory_locations loc ON loc.id = lvl.inventory_location_id
        JOIN public.dim_inventory_items ii ON ii.id = lvl.inventory_item_id
        WHERE lvl.seller_id = :shopId
        GROUP BY loc.name
    )
    SELECT location, stock_value
    FROM base_locations
    ORDER BY stock_value DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'PLOT',
    60,
    'Valuation of inventory on hand distributed across fulfillment locations.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31a-7323-8269-e6d293ea4b07',
    'Unfulfilled Revenue Risk',
    'Executive Store Health/Inventory & Operations/PLOT/Unfulfilled Revenue Risk',
    $$
    WITH
    unfulfilled AS (
        SELECT COALESCE(o.current_total_price, 0) AS order_value,
               (CURRENT_DATE - o.created_at::date) AS age_days
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.fulfillmentstatus IS DISTINCT FROM 'FULFILLED'
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    buckets AS (
        SELECT ROUND(COALESCE(SUM(order_value) FILTER (WHERE age_days <= 3), 0), 2)              AS "0-3 days",
               ROUND(COALESCE(SUM(order_value) FILTER (WHERE age_days BETWEEN 4 AND 7), 0), 2)   AS "4-7 days",
               ROUND(COALESCE(SUM(order_value) FILTER (WHERE age_days BETWEEN 8 AND 14), 0), 2)  AS "8-14 days",
               ROUND(COALESCE(SUM(order_value) FILTER (WHERE age_days BETWEEN 15 AND 30), 0), 2) AS "15-30 days",
               ROUND(COALESCE(SUM(order_value) FILTER (WHERE age_days > 30), 0), 2)              AS "31+ days"
        FROM unfulfilled
    )
    SELECT e.bucket AS bucket,
           e.amount::numeric AS unfulfilled_value
    FROM buckets b,
         json_each_text(row_to_json(b)) WITH ORDINALITY AS e(bucket, amount, ord)
    ORDER BY e.ord
    $$,
    NULL,
    'PLOT',
    60,
    'Unfulfilled order revenue grouped into aging buckets (0-3 days to 31+ days).',
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
    '019fff82-e31a-71ad-8841-83e7ba0a2123',
    'Fulfillment Status Mix',
    'Executive Store Health/Inventory & Operations/PLOT/Fulfillment Status Mix',
    $$
    WITH
    /*date_granularity_cte*/
    filtered_orders AS (
        SELECT date_trunc(LOWER(dp.g), o.created_at) AS bucket,
               o.fulfillmentstatus,
               COALESCE(o.current_total_price, 0) AS order_value
        FROM public.fact_order_headers o
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.created_at >= dp.start_bucket
          AND o.created_at <= dp.end_bucket
    ),
    daily AS (
        SELECT f.bucket,
               SUM(f.order_value) FILTER (WHERE f.fulfillmentstatus = 'FULFILLED') AS fulfilled,
               SUM(f.order_value) FILTER (WHERE f.fulfillmentstatus = 'PARTIALLY_FULFILLED') AS partial,
               SUM(f.order_value) FILTER (
                   WHERE f.fulfillmentstatus IS DISTINCT FROM 'FULFILLED'
                     AND f.fulfillmentstatus IS DISTINCT FROM 'PARTIALLY_FULFILLED') AS unfulfilled
        FROM filtered_orders f
        GROUP BY f.bucket
    )
    SELECT CASE
               WHEN dp.g = 'DAY'     THEN to_char(df.bucket, 'Mon DD')
               WHEN dp.g = 'WEEK'    THEN to_char(df.bucket, 'Mon DD')
               WHEN dp.g = 'MONTH'   THEN to_char(df.bucket, 'Mon YYYY')
               WHEN dp.g = 'QUARTER' THEN 'Q' || EXTRACT(QUARTER FROM df.bucket)::int || ' ' || EXTRACT(YEAR FROM df.bucket)::int
               WHEN dp.g = 'YEAR'    THEN to_char(df.bucket, 'YYYY')
           END AS period,
           df.bucket,
           ROUND(COALESCE(d.fulfilled, 0), 2) AS fulfilled,
           ROUND(COALESCE(d.partial, 0), 2) AS partial,
           ROUND(COALESCE(d.unfulfilled, 0), 2) AS unfulfilled
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily d ON d.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Order revenue split by status (Fulfilled, Partially Fulfilled, Unfulfilled) grouped by dynamic date granularity.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"    },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate"   },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"     },
        "granularity":      { "source": "REQUEST_FILTER", "filterKey": "granularity" }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        { "provider": "DATE_GRANULARITY_CTE", "condition": "hasFilter:startDate", "placeholder": "/*date_granularity_cte*/",
          "args": { "startDateParam": "currentStartDate", "endDateParam": "currentEndDate", "granularityParam": "granularity" } }
      ]
    }'
),
(
    '019fff82-e31a-7561-962f-82900d935653',
    'Inventory Risk by Product',
    'Executive Store Health/Inventory & Operations/PLOT/Inventory Risk by Product',
    $$
    WITH
    filtered_orders AS (
        SELECT o.id,
               o.created_at::date AS day
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    window_days AS (
        SELECT GREATEST(COALESCE(:currentEndDate::date, (SELECT MAX(day) FROM filtered_orders))
                        - COALESCE(:currentStartDate::date, (SELECT MIN(day) FROM filtered_orders)) + 1, 1) AS days
    ),
    variant_sales AS (
        SELECT li.product_variant_id AS variant_id,
               SUM(li.quantity) AS units_sold
        FROM public.fact_order_line_items li
        JOIN filtered_orders f ON f.id = li.order_id
        GROUP BY li.product_variant_id
    ),
    variant_stock AS (
        SELECT pv.id AS variant_id,
               SUM(COALESCE(lvl.available_quantity, lvl.on_hand_quantity, 0)) AS available
        FROM public.dim_inventory_levels lvl
        JOIN public.dim_inventory_items ii ON ii.id = lvl.inventory_item_id
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        WHERE lvl.seller_id = :shopId
        GROUP BY pv.id
    ),
    ranked AS (
        SELECT COALESCE(p.title, pv.sku, pv.id) AS product,
               st.available AS available_stock,
               COALESCE(vs.units_sold, 0) AS units_sold,
               ROUND(st.available / NULLIF(COALESCE(vs.units_sold, 0)::numeric / w.days, 0), 1) AS days_of_cover
        FROM variant_stock st
        JOIN public.dim_product_variants pv ON pv.id = st.variant_id
        LEFT JOIN public.dim_products p ON p.id = pv.product_id
        LEFT JOIN variant_sales vs ON vs.variant_id = st.variant_id
        CROSS JOIN window_days w
    )
    SELECT r.product AS product,
           r.available_stock AS available_stock,
           r.units_sold AS units_sold,
           r.days_of_cover AS days_of_cover,
           (r.days_of_cover < 14) AS at_risk
    FROM ranked r
    ORDER BY r.days_of_cover ASC NULLS LAST
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'PLOT',
    60,
    'Products ranked by stock cover days; items below 14 days flagged as stockout risk.',
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
    '019fff82-e31a-7fd2-98bd-1d94abe28a36',
    'New vs Repeat Revenue',
    'Executive Store Health/Customer & Channel/PLOT/New vs Repeat Revenue',
    $$
    WITH
    /*date_granularity_cte*/
    filtered_orders AS (
        SELECT o.id,
               o.customer_id,
               o.created_at,
               date_trunc(LOWER(dp.g), o.created_at) AS bucket,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM public.fact_order_headers o
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.created_at >= dp.start_bucket
          AND o.created_at <= dp.end_bucket
    ),
    customer_first AS (
        SELECT o.customer_id,
               MIN(o.created_at) AS first_order_at
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.customer_id IS NOT NULL
        GROUP BY o.customer_id
    ),
    daily AS (
        SELECT f.bucket,
               SUM(f.net_sales) FILTER (
                   WHERE f.customer_id IS NULL OR f.created_at <= cf.first_order_at) AS new_revenue,
               SUM(f.net_sales) FILTER (
                   WHERE f.customer_id IS NOT NULL AND f.created_at > cf.first_order_at) AS repeat_revenue
        FROM filtered_orders f
        LEFT JOIN customer_first cf ON cf.customer_id = f.customer_id
        GROUP BY f.bucket
    )
    SELECT CASE
               WHEN dp.g = 'DAY'     THEN to_char(df.bucket, 'Mon DD')
               WHEN dp.g = 'WEEK'    THEN to_char(df.bucket, 'Mon DD')
               WHEN dp.g = 'MONTH'   THEN to_char(df.bucket, 'Mon YYYY')
               WHEN dp.g = 'QUARTER' THEN 'Q' || EXTRACT(QUARTER FROM df.bucket)::int || ' ' || EXTRACT(YEAR FROM df.bucket)::int
               WHEN dp.g = 'YEAR'    THEN to_char(df.bucket, 'YYYY')
           END AS period,
           df.bucket,
           ROUND(COALESCE(d.new_revenue, 0), 2) AS new_revenue,
           ROUND(COALESCE(d.repeat_revenue, 0), 2) AS repeat_revenue
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily d ON d.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Net revenue contribution from new vs returning customers grouped by dynamic date granularity.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"    },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate"   },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"     },
        "granularity":      { "source": "REQUEST_FILTER", "filterKey": "granularity" }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        { "provider": "DATE_GRANULARITY_CTE", "condition": "hasFilter:startDate", "placeholder": "/*date_granularity_cte*/",
          "args": { "startDateParam": "currentStartDate", "endDateParam": "currentEndDate", "granularityParam": "granularity" } }
      ]
    }'
),
(
    '019fff82-e31a-7553-af0b-2fc2d407e2cb',
    'Top Customer Segments',
    'Executive Store Health/Customer & Channel/PLOT/Top Customer Segments',
    $$
    WITH
    filtered_orders AS (
        SELECT o.id,
               COALESCE(
                   o.shipping_address #>> '{country}',
                   o.shipping_address #>> '{province}',
                   o.shipping_address #>> '{city}'
               ) AS segment,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    segments AS (
        SELECT f.segment AS segment,
               SUM(f.net_sales) AS revenue,
               COUNT(*) AS orders
        FROM filtered_orders f
        WHERE f.segment IS NOT NULL
        GROUP BY f.segment
    )
    SELECT s.segment AS segment,
           ROUND(s.revenue, 2) AS revenue,
           s.orders AS orders,
           ROUND(s.revenue / NULLIF(s.orders, 0), 2) AS aov
    FROM segments s
    ORDER BY s.revenue DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'PLOT',
    60,
    'Top geographic customer segments ranked by net sales, order volume, and AOV.',
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
    '019fff82-e31a-7a80-b020-11c6d77f5502',
    'Sales by Channel',
    'Executive Store Health/Customer & Channel/PLOT/Sales by Channel',
    $$
  WITH filtered_orders AS (
    SELECT o.id,
           COALESCE(o.current_total_price, 0)
             - COALESCE(o.current_total_tax, 0)
             - COALESCE(o.current_shipping_price, 0) AS net_sales,
           COALESCE(o.attribution_displayname, o.source_name) AS channel
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      
      AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
)
SELECT COALESCE(channel, 'unknown') AS channel,
       ROUND(SUM(net_sales), 2) AS net_sales,
       COUNT(*) AS orders
FROM filtered_orders
GROUP BY COALESCE(channel, 'unknown')
ORDER BY net_sales DESC
LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'PLOT',
    60,
    'Breakdown of net sales and order volume across sales channels and integration apps.',
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
    '019fff82-e31a-7851-94f1-b2ed33f54156',
    'Channel Quality Matrix',
    'Executive Store Health/Customer & Channel/TABLE/Channel Quality Matrix',
    $$
    WITH
    channel_orders AS (
        SELECT o.id,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales,
               COALESCE(o.attribution_displayname, o.source_name, 'unknown') AS channel
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    channel_totals AS (
        SELECT co.channel,
               SUM(co.net_sales) AS net_sales,
               COUNT(*) AS orders
        FROM channel_orders co
        GROUP BY co.channel
    ),
    channel_lines AS (
        SELECT co.channel,
               SUM(li.original_unit_price * li.quantity) AS gross_sales,
               SUM(li.total_discount_amount) AS discounted,
               SUM(li.original_total_amount) AS original_amount
        FROM public.fact_order_line_items li
        JOIN channel_orders co ON co.id = li.order_id
        GROUP BY co.channel
    ),
    channel_refunds AS (
        SELECT co.channel,
               SUM(COALESCE(r.total_refunded_amount, 0)) AS refunded
        FROM public.fact_order_refunds r
        JOIN channel_orders co ON co.id = r.order_id
        GROUP BY co.channel
    )
    SELECT ct.channel AS channel,
           ROUND(ct.net_sales, 2) AS net_sales,
           ct.orders AS orders,
           ROUND(ct.net_sales / NULLIF(ct.orders, 0), 2) AS aov,
           ROUND(100 * COALESCE(cr.refunded, 0) / NULLIF(cl.gross_sales, 0), 2) AS refund_rate,
           ROUND(100 * COALESCE(cl.discounted, 0)/ NULLIF(cl.original_amount, 0), 2) AS discount_rate,
           COUNT(*) OVER() AS total_records
    FROM channel_totals ct
    LEFT JOIN channel_lines cl ON cl.channel IS NOT DISTINCT FROM ct.channel
    LEFT JOIN channel_refunds cr ON cr.channel IS NOT DISTINCT FROM ct.channel
    ORDER BY ct.net_sales DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'TABLE',
    60,
    'Comparative performance scorecard per sales channel evaluating AOV, refund %, and discount %.',
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

--changeset saugat:RW-34-5
--comment seed payment and business risk tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31a-7d26-8130-686674870f58',
    'Payments & Risk KPIs',
    'Executive Store Health/Payment & Business Risk/KPI/Payments & Risk KPIs',
    $$
    WITH
    scoped_orders AS (
        SELECT * FROM (
            SELECT o.id,
                   ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date))  AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)          AS is_prior,
                   COALESCE(o.current_total_price, 0)
                     - COALESCE(o.current_total_tax, 0)
                     - COALESCE(o.current_shipping_price, 0) AS net_sales
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    variant_cost AS (
        SELECT pv.id AS variant_id,
               AVG(ii.unit_cost) AS unit_cost
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        WHERE ii.seller_id = :shopId
        GROUP BY pv.id
    ),
    order_totals AS (
        SELECT COALESCE(SUM(net_sales) FILTER (WHERE is_current), 0) AS cur_net_sales,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior),   0) AS prv_net_sales
        FROM scoped_orders
    ),
    cogs_totals AS (
        SELECT COALESCE(SUM(li.quantity * vc.unit_cost) FILTER (WHERE s.is_current), 0) AS cur_cogs,
               COALESCE(SUM(li.quantity * vc.unit_cost) FILTER (WHERE s.is_prior),   0) AS prv_cogs
        FROM public.fact_order_line_items li
        JOIN scoped_orders s ON s.id = li.order_id
        LEFT JOIN variant_cost vc ON vc.variant_id = li.product_variant_id
    ),
    computed AS (
        SELECT ot.cur_net_sales - ct.cur_cogs AS cur_margin,
               ot.prv_net_sales - ct.prv_cogs AS prv_margin
        FROM order_totals ot
        CROSS JOIN cogs_totals ct
    )
    SELECT ROUND(c.cur_margin, 2) AS gross_margin_estimate,
           ROUND(100 * (c.cur_margin - c.prv_margin)
                 / NULLIF(ABS(c.prv_margin), 0), 2) AS gross_margin_estimate_divergence
    FROM computed c
    $$,
    NULL,
    'KPI',
    60,
    'Estimated gross margin vs prior period.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"      },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"      },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate"     },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"       },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate"   }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        { "provider": "COMPARISON_WINDOW_CTE", "condition": "hasFilter:startDate", "placeholder": "/*comparison_window_cte*/",
          "args": { "currentStartParam": "currentStartDate", "currentEndParam": "currentEndDate", "priorStartParam": "priorStartDate", "priorEndParam": "priorEndDate" } }
      ]
    }'
),
(
    '019fff82-e31a-7585-80ff-4990966674d4',
    'Payment Method Mix',
    'Executive Store Health/Payment & Business Risk/PLOT/Payment Method Mix',
    $$
    WITH
    filtered_tender AS (
        SELECT COALESCE(tt.payment_method, tt.transaction_credit_card_company) AS payment_method,
               ROUND(SUM(COALESCE(tt.amount, 0)), 2) AS amount
        FROM public.dim_tender_transactions tt
        JOIN public.fact_order_headers o ON o.id = tt.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND tt.test = FALSE
          AND (:currentStartDate IS NULL OR tt.processed_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR tt.processed_at::date <= :currentEndDate::date)
        GROUP BY COALESCE(tt.payment_method, tt.transaction_credit_card_company)
    )
    SELECT payment_method, amount
    FROM filtered_tender
    ORDER BY amount DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'PLOT',
    60,
    'Distribution of gross transaction amounts grouped by payment method / credit card type.',
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
    '019fff82-e31a-7ef0-9306-64b7d8c6b62d',
    'Transaction Fee Impact',
    'Executive Store Health/Payment & Business Risk/PLOT/Transaction Fee Impact',
    $$
    WITH
    filtered_fees AS (
        SELECT COALESCE(NULLIF(t.gateway, ''), 'unknown')  AS gateway,
               ROUND(SUM(COALESCE(t.transaction_fee, 0)), 2) AS fee_amount,
               ROUND(100 * SUM(COALESCE(t.transaction_fee, 0)) / NULLIF(SUM(COALESCE(t.amount, 0)), 0), 2) AS fee_rate
        FROM public.fact_order_transactions t
        JOIN public.fact_order_headers o ON o.id = t.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND t.test = FALSE
          AND t.kind = 'SALE'
          AND t.status = 'SUCCESS'
          AND (:currentStartDate IS NULL OR t.processed_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR t.processed_at::date <= :currentEndDate::date)
        GROUP BY 1
    )
    SELECT gateway, fee_amount, fee_rate
    FROM filtered_fees
    ORDER BY fee_amount DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'PLOT',
    60,
    'Payment gateway transaction fee totals and effective fee rate percentages.',
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