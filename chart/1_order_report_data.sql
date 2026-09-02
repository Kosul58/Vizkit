--liquibase formatted sql logicalFilePath:20260731001_order_report_data.sql

--changeset kosul:RW-38-1
--comment seed sales & revenue data
INSERT INTO chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31d-7a2c-9710-92ecf736d574',
    'Sales & Revenue KPIs',
    'Order Reports/Sales & Revenue/KPI/Sales & Revenue KPIs',
    $$
    WITH
    /*comparison_window_cte*/
    scoped_orders AS (
        SELECT * FROM (
            SELECT o.id,
                   ((w.cur_start IS NULL OR o.created_at::date >= w.cur_start)
                AND (w.cur_end   IS NULL OR o.created_at::date <= w.cur_end))  AS is_current,
                   (w.prv_start IS NOT NULL
                AND o.created_at::date BETWEEN w.prv_start AND w.prv_end)      AS is_prior,
                   COALESCE(o.current_total_price, 0)
                     - COALESCE(o.current_total_tax, 0)
                     - COALESCE(o.current_shipping_price, 0) AS net_sales,
                   COALESCE(o.subtotal_price, 0)
                     + COALESCE(o.total_discounts_amount, 0) AS gross_sales,
                   COALESCE(o.total_discounts_amount, 0) AS discount_amount,
                   COALESCE(o.current_total_tax, 0) AS tax_collected
            FROM public.fact_order_headers o
            CROSS JOIN windows w
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.cancelled_at IS NULL
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    order_totals AS (
        SELECT COUNT(*) FILTER (WHERE is_current) AS cur_orders,
               COUNT(*) FILTER (WHERE is_prior)   AS prv_orders,
               COALESCE(SUM(net_sales)       FILTER (WHERE is_current), 0) AS cur_net,
               COALESCE(SUM(net_sales)       FILTER (WHERE is_prior),   0) AS prv_net,
               COALESCE(SUM(gross_sales)     FILTER (WHERE is_current), 0) AS cur_gross,
               COALESCE(SUM(gross_sales)     FILTER (WHERE is_prior),   0) AS prv_gross,
               COALESCE(SUM(discount_amount) FILTER (WHERE is_current), 0) AS cur_discount,
               COALESCE(SUM(discount_amount) FILTER (WHERE is_prior),   0) AS prv_discount,
               COALESCE(SUM(tax_collected)   FILTER (WHERE is_current), 0) AS cur_tax,
               COALESCE(SUM(tax_collected)   FILTER (WHERE is_prior),   0) AS prv_tax
        FROM scoped_orders
    ),
    refund_totals AS (
        SELECT COALESCE(SUM(r.total_refunded_amount) FILTER (WHERE s.is_current), 0) AS cur_refunded,
               COALESCE(SUM(r.total_refunded_amount) FILTER (WHERE s.is_prior),   0) AS prv_refunded
        FROM public.fact_order_refunds r
        JOIN scoped_orders s ON s.id = r.order_id
    ),
    computed AS (
        SELECT ot.cur_net, ot.prv_net, ot.cur_gross, ot.prv_gross,
               ot.cur_discount, ot.prv_discount, ot.cur_tax, ot.prv_tax,
               rt.cur_refunded, rt.prv_refunded,
               ROUND(COALESCE(ot.cur_net / NULLIF(ot.cur_orders, 0), 0), 2) AS cur_aov,
               ROUND(COALESCE(ot.prv_net / NULLIF(ot.prv_orders, 0), 0), 2) AS prv_aov
        FROM order_totals ot
        CROSS JOIN refund_totals rt
    )
    SELECT ROUND(c.cur_net, 2) AS net_sales,
           ROUND(100 * (c.cur_net - c.prv_net)
                 / NULLIF(ABS(c.prv_net), 0), 2) AS net_sales_divergence,
           ROUND(c.cur_gross, 2) AS gross_sales,
           ROUND(100 * (c.cur_gross - c.prv_gross)
                 / NULLIF(ABS(c.prv_gross), 0), 2) AS gross_sales_divergence,
           c.cur_aov AS average_order_value,
           ROUND(100 * (c.cur_aov - c.prv_aov)
                 / NULLIF(ABS(c.prv_aov), 0), 2) AS average_order_value_divergence,
           ROUND(c.cur_discount, 2) AS discount_amount,
           ROUND(100 * (c.cur_discount - c.prv_discount)
                 / NULLIF(ABS(c.prv_discount), 0), 2) AS discount_amount_divergence,
           ROUND(c.cur_refunded, 2) AS refunded_order_value,
           ROUND(100 * (c.cur_refunded - c.prv_refunded)
                 / NULLIF(ABS(c.prv_refunded), 0), 2) AS refunded_order_value_divergence,
           ROUND(c.cur_tax, 2) AS tax_collected,
           ROUND(100 * (c.cur_tax - c.prv_tax)
                 / NULLIF(ABS(c.prv_tax), 0), 2) AS tax_collected_divergence
    FROM computed c
    $$,
    NULL,
    'KPI',
    60,
    'High-level order sales & revenue KPIs evaluating net sales, gross sales, AOV, discounts, refunds, and tax vs prior period.',
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
        {
          "provider": "COMPARISON_WINDOW_CTE",
          "condition": "hasFilter:startDate",
          "placeholder": "/*comparison_window_cte*/",
          "args": {
            "currentStartParam": "currentStartDate",
            "currentEndParam": "currentEndDate",
            "priorStartParam": "priorStartDate",
            "priorEndParam": "priorEndDate"
          }
        }
      ]
    }'
),
(
    '019fff82-e31d-73b8-9e6d-85c6d409913c',
    'Sales Trend',
    'Order Reports/Sales & Revenue/PLOT/Sales Trend',
    $$
    WITH
    /*date_granularity_cte*/
    filtered_orders AS (
        SELECT date_trunc(LOWER(dp.g), o.created_at) AS bucket,
               COALESCE(o.subtotal_price, 0)
                 + COALESCE(o.total_discounts_amount, 0) AS gross_sales,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM public.fact_order_headers o
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND o.created_at >= dp.start_bucket
          AND o.created_at <= dp.end_bucket
    ),
    daily AS (
        SELECT f.bucket,
               SUM(f.gross_sales) AS gross_sales,
               SUM(f.net_sales) AS net_sales
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
           ROUND(COALESCE(d.gross_sales, 0), 2) AS gross_sales,
           ROUND(COALESCE(d.net_sales, 0), 2) AS net_sales
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily d ON d.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Order gross vs net sales trend grouped by dynamic date granularity.',
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
        {
          "provider": "DATE_GRANULARITY_CTE",
          "condition": "hasFilter:startDate",
          "placeholder": "/*date_granularity_cte*/",
          "args": {
            "startDateParam": "currentStartDate",
            "endDateParam": "currentEndDate",
            "granularityParam": "granularity"
          }
        }
      ]
    }'
),
(
    '019fff82-e31d-797f-be67-74f6653427aa',
    'Revenue Waterfall',
    'Order Reports/Sales & Revenue/PLOT/Revenue Waterfall',
    $$
    WITH
    /*date_granularity_cte*/
    filtered_orders AS (
        SELECT o.id,
               date_trunc(LOWER(dp.g), o.created_at) AS bucket,
               COALESCE(o.subtotal_price, 0)
                 + COALESCE(o.total_discounts_amount, 0) AS gross_sales,
               COALESCE(o.total_discounts_amount, 0) AS discounts,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM public.fact_order_headers o
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND o.created_at >= dp.start_bucket
          AND o.created_at <= dp.end_bucket
    ),
    order_totals AS (
        SELECT f.bucket,
               COALESCE(SUM(f.gross_sales), 0) AS gross_sales,
               COALESCE(SUM(f.discounts), 0) AS discounts,
               COALESCE(SUM(f.net_sales), 0) AS net_sales
        FROM filtered_orders f
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
          AND o.cancelled_at IS NULL
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
               ROUND(COALESCE(o.gross_sales, 0), 2) AS gross_sales,
               ROUND(-COALESCE(o.discounts, 0), 2)  AS discounts,
               ROUND(-COALESCE(r.refunds, 0), 2)    AS refunds,
               ROUND(COALESCE(o.net_sales, 0), 2)   AS net_sales
        FROM date_filler df
        CROSS JOIN date_params dp
        LEFT JOIN order_totals o
               ON o.bucket = df.bucket
        LEFT JOIN refund_totals r
               ON r.bucket = df.bucket
    )
    SELECT s.period_label AS category,
           s.gross_sales  AS "gross_sales",
           s.discounts    AS "discounts",
           s.refunds      AS "refunds",
           s.net_sales    AS "net_sales"
    FROM stages s
    ORDER BY s.bucket
    $$,
    NULL,
    'PLOT',
    60,
    'Waterfall chart reconciling Gross Sales to Net Sales via order discounts and refunds, grouped by dynamic date granularity.',
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
        {
          "provider": "DATE_GRANULARITY_CTE",
          "condition": "hasFilter:startDate",
          "placeholder": "/*date_granularity_cte*/",
          "args": {
            "startDateParam": "currentStartDate",
            "endDateParam": "currentEndDate",
            "granularityParam": "granularity"
          }
        }
      ]
    }'
),
(
    '019fff82-e31d-7f37-bca1-e5405982d060',
    'Discount Trend',
    'Order Reports/Sales & Revenue/PLOT/Discount Trend',
    $$
    WITH
    /*date_granularity_cte*/
    filtered_orders AS (
        SELECT date_trunc(LOWER(dp.g), o.created_at) AS bucket,
               COALESCE(o.subtotal_price, 0)
                 + COALESCE(o.total_discounts_amount, 0) AS gross_sales,
               COALESCE(o.total_discounts_amount, 0) AS discount_amount
        FROM public.fact_order_headers o
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND o.created_at >= dp.start_bucket
          AND o.created_at <= dp.end_bucket
    ),
    daily AS (
        SELECT f.bucket,
               SUM(f.gross_sales) AS gross_sales,
               SUM(f.discount_amount) AS discount_amount
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
           ROUND(COALESCE(d.discount_amount, 0), 2) AS discount_amount,
           ROUND(COALESCE(100 * d.discount_amount / NULLIF(d.gross_sales, 0), 0), 2) AS discount_rate
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily d ON d.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Discount dollar total and discount rate % trend grouped by dynamic date granularity.',
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
        {
          "provider": "DATE_GRANULARITY_CTE",
          "condition": "hasFilter:startDate",
          "placeholder": "/*date_granularity_cte*/",
          "args": {
            "startDateParam": "currentStartDate",
            "endDateParam": "currentEndDate",
            "granularityParam": "granularity"
          }
        }
      ]
    }'
),
(
    '019fff82-e31d-7bf1-8c13-df22e4af91f2',
    'Refunded Orders Trend',
    'Order Reports/Sales & Revenue/PLOT/Refunded Orders Trend',
    $$
    WITH
    /*date_granularity_cte*/
    filtered_refunds AS (
        SELECT r.order_id,
               date_trunc(LOWER(dp.g), r.created_at) AS bucket,
               COALESCE(r.total_refunded_amount, 0) AS refunded_value
        FROM public.fact_order_refunds r
        JOIN public.fact_order_headers o ON o.id = r.order_id
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND r.created_at >= dp.start_bucket
          AND r.created_at <= dp.end_bucket
    ),
    daily AS (
        SELECT f.bucket,
               COUNT(DISTINCT f.order_id) AS refunded_order_count,
               SUM(f.refunded_value) AS refunded_value
        FROM filtered_refunds f
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
           COALESCE(d.refunded_order_count, 0) AS refunded_order_count,
           ROUND(COALESCE(d.refunded_value, 0), 2) AS refunded_value
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily d ON d.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Trend of refunded order counts and total refunded value grouped by dynamic date granularity.',
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
        {
          "provider": "DATE_GRANULARITY_CTE",
          "condition": "hasFilter:startDate",
          "placeholder": "/*date_granularity_cte*/",
          "args": {
            "startDateParam": "currentStartDate",
            "endDateParam": "currentEndDate",
            "granularityParam": "granularity"
          }
        }
      ]
    }'
),
(
    '019fff82-e31d-7bc3-a07b-7beb0c45249b',
    'Orders vs AOV Trend',
    'Order Reports/Sales & Revenue/PLOT/Orders vs AOV Trend',
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
          AND o.cancelled_at IS NULL
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
    'Order volume and Average Order Value (AOV) trend grouped by dynamic date granularity.',
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
        {
          "provider": "DATE_GRANULARITY_CTE",
          "condition": "hasFilter:startDate",
          "placeholder": "/*date_granularity_cte*/",
          "args": {
            "startDateParam": "currentStartDate",
            "endDateParam": "currentEndDate",
            "granularityParam": "granularity"
          }
        }
      ]
    }'
),
(
    '019fff82-e31d-769a-bc42-f99a7173de6a',
    'Orders Detail Report',
    'Order Reports/Sales & Revenue/TABLE/Orders Detail Report',
    $$
    WITH filtered_orders AS (
        SELECT o.id,
               o.id AS order_id,
               o.created_at,
               o.customer_id,
               o.source_name,
               o.financialStatus AS financial_status,
               o.fulfillmentStatus AS fulfillment_status,
               COALESCE(o.original_total_price, 0) AS gross_sales,
               COALESCE(o.total_discounts_amount, 0) AS discounts,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales,
               COALESCE(o.current_total_tax, 0) AS tax,
               COALESCE(o.current_shipping_price, 0) AS shipping,
               COALESCE(o.total_outstanding_amount, 0) AS outstanding_amount
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT f.order_id,
           f.created_at::date::text AS order_date,
           CASE WHEN LENGTH(CONCAT_WS(CHR(32), c.first_name, c.last_name)) > 0
                THEN CONCAT_WS(CHR(32), c.first_name, c.last_name)
                ELSE COALESCE(c.email, 'Guest') END AS customer,
           COALESCE(f.source_name, 'unknown') AS channel,
           f.source_name AS source,
           f.financial_status,
           f.fulfillment_status,
           ROUND(f.gross_sales, 2) AS gross_sales,
           ROUND(f.discounts, 2) AS discounts,
           ROUND(f.net_sales, 2) AS net_sales,
           ROUND(f.tax, 2) AS tax,
           ROUND(f.shipping, 2) AS shipping,
           ROUND(f.outstanding_amount, 2) AS outstanding_amount,
           COUNT(*) OVER() AS total_records
    FROM filtered_orders f
    LEFT JOIN public.dim_customers c ON c.id = f.customer_id
    ORDER BY f.created_at DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'TABLE',
    60,
    'Comprehensive tabular report of all order transactions including financial status, sales totals, taxes, and shipping.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
);

--changeset kosul:RW-38-2
--comment seed Orders & Fulfillment tab 

INSERT INTO chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31d-7345-8f03-4bdb44f89b93',
    'Orders & Fulfillment KPIs',
    'Order Reports/Orders & Fulfillment/KPI/Orders & Fulfillment KPIs',
    $$
    WITH
    /*comparison_window_cte*/
    scoped_orders AS (
        SELECT * FROM (
            SELECT UPPER(o."fulfillmentStatus") AS fulfillment_status,
                   ((w.cur_start IS NULL OR o.created_at::date >= w.cur_start)
                AND (w.cur_end   IS NULL OR o.created_at::date <= w.cur_end))  AS is_current,
                   (w.prv_start IS NOT NULL
                AND o.created_at::date BETWEEN w.prv_start AND w.prv_end)      AS is_prior
            FROM public.fact_order_headers o
            CROSS JOIN windows w
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.cancelled_at IS NULL
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    scoped_cancellations AS (
        SELECT * FROM (
            SELECT ((w.cur_start IS NULL OR o.cancelled_at::date >= w.cur_start)
                AND (w.cur_end   IS NULL OR o.cancelled_at::date <= w.cur_end))  AS is_current,
                   (w.prv_start IS NOT NULL
                AND o.cancelled_at::date BETWEEN w.prv_start AND w.prv_end)      AS is_prior
            FROM public.fact_order_headers o
            CROSS JOIN windows w
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.cancelled_at IS NOT NULL
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    totals AS (
        SELECT COUNT(*) FILTER (WHERE is_current) AS cur_total,
               COUNT(*) FILTER (WHERE is_prior)   AS prv_total,
               COUNT(*) FILTER (WHERE is_current
                             AND fulfillment_status IS DISTINCT FROM 'FULFILLED') AS cur_pending,
               COUNT(*) FILTER (WHERE is_prior
                             AND fulfillment_status IS DISTINCT FROM 'FULFILLED') AS prv_pending
        FROM scoped_orders
    ),
    cancelled AS (
        SELECT COUNT(*) FILTER (WHERE is_current) AS cur_cancelled,
               COUNT(*) FILTER (WHERE is_prior)   AS prv_cancelled
        FROM scoped_cancellations
    )
    SELECT t.cur_total AS total_orders,
           ROUND(100 * (t.cur_total - t.prv_total)
                 / NULLIF(ABS(t.prv_total), 0), 2) AS total_orders_divergence,
           t.cur_pending AS fulfillment_pending_orders,
           ROUND(100 * (t.cur_pending - t.prv_pending)
                 / NULLIF(ABS(t.prv_pending), 0), 2) AS fulfillment_pending_orders_divergence,
           c.cur_cancelled AS cancelled_orders,
           ROUND(100 * (c.cur_cancelled - c.prv_cancelled)
                 / NULLIF(ABS(c.prv_cancelled), 0), 2) AS cancelled_orders_divergence
    FROM totals t
    CROSS JOIN cancelled c
    $$,
    NULL,
    'KPI',
    60,
    'KPIs tracking total order volume, pending unfulfilled orders, and cancelled order counts vs prior period.',
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
        {
          "provider": "COMPARISON_WINDOW_CTE",
          "condition": "hasFilter:startDate",
          "placeholder": "/*comparison_window_cte*/",
          "args": {
            "currentStartParam": "currentStartDate",
            "currentEndParam": "currentEndDate",
            "priorStartParam": "priorStartDate",
            "priorEndParam": "priorEndDate"
          }
        }
      ]
    }'
),
(
    '019fff82-e31d-7da5-bec3-40a9b99a9baa',
    'Orders by Status',
    'Order Reports/Orders & Fulfillment/PLOT/Orders by Status',
    $$
    WITH filtered_orders AS (
        SELECT COALESCE(UPPER(o."fulfillmentStatus"), 'UNFULFILLED') AS fulfillment_status,
               UPPER(o.financialStatus) AS financial_status,
               COALESCE(o.original_total_price, 0) AS order_value
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT f.fulfillment_status AS status,
           ROUND(COALESCE(SUM(f.order_value) FILTER (WHERE f.financial_status = 'PAID'), 0), 2)               AS paid,
           ROUND(COALESCE(SUM(f.order_value) FILTER (WHERE f.financial_status = 'PENDING'), 0), 2)            AS pending,
           ROUND(COALESCE(SUM(f.order_value) FILTER (WHERE f.financial_status = 'AUTHORIZED'), 0), 2)         AS authorized,
           ROUND(COALESCE(SUM(f.order_value) FILTER (WHERE f.financial_status = 'PARTIALLY_PAID'), 0), 2)     AS partially_paid,
           ROUND(COALESCE(SUM(f.order_value) FILTER (WHERE f.financial_status = 'PARTIALLY_REFUNDED'), 0), 2) AS partially_refunded,
           ROUND(COALESCE(SUM(f.order_value) FILTER (WHERE f.financial_status = 'REFUNDED'), 0), 2)           AS refunded,
           ROUND(COALESCE(SUM(f.order_value) FILTER (WHERE f.financial_status = 'VOIDED'), 0), 2)             AS voided,
           ROUND(COALESCE(SUM(f.order_value) FILTER (WHERE f.financial_status = 'EXPIRED'), 0), 2)            AS expired
    FROM filtered_orders f
    GROUP BY f.fulfillment_status
    ORDER BY SUM(f.order_value) DESC
    $$,
    NULL,
    'PLOT',
    60,
    'Order value breakdown matrix across fulfillment status and financial status.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31d-7d01-b0e7-e98182e66062',
    'Cancelled Order Loss',
    'Order Reports/Orders & Fulfillment/PLOT/Cancelled Order Loss',
    $$
    WITH
    /*date_granularity_cte*/
    filtered_cancellations AS (
        SELECT date_trunc(LOWER(dp.g), o.cancelled_at) AS bucket,
               COALESCE(o.original_total_price, 0) AS cancelled_value
        FROM public.fact_order_headers o
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NOT NULL
          AND o.cancelled_at >= dp.start_bucket
          AND o.cancelled_at <= dp.end_bucket
    ),
    daily AS (
        SELECT f.bucket,
               SUM(f.cancelled_value) AS cancelled_value
        FROM filtered_cancellations f
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
           ROUND(COALESCE(d.cancelled_value, 0), 2) AS cancelled_value
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily d ON d.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Dollar value trend of lost sales from cancelled orders grouped by dynamic date granularity.',
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
        {
          "provider": "DATE_GRANULARITY_CTE",
          "condition": "hasFilter:startDate",
          "placeholder": "/*date_granularity_cte*/",
          "args": {
            "startDateParam": "currentStartDate",
            "endDateParam": "currentEndDate",
            "granularityParam": "granularity"
          }
        }
      ]
    }'
),
(
    '019fff82-e31d-7950-8048-cc15a851e0f2',
    'Cancelled Orders Report',
    'Order Reports/Orders & Fulfillment/TABLE/Cancelled Orders Report',
    $$
    WITH filtered_orders AS (
        SELECT o.id,
               o.id AS order_id,
               o.cancelled_at,
               o.customer_id,
               o.source_name,
               COALESCE(o.original_total_price, 0) AS original_value
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NOT NULL
          AND (:currentStartDate IS NULL OR o.cancelled_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.cancelled_at::date <= :currentEndDate::date)
    )
    SELECT f.order_id,
           f.cancelled_at::date::text AS cancelled_date,
           ROUND(f.original_value, 2) AS original_value,
           CASE WHEN LENGTH(CONCAT_WS(CHR(32), c.first_name, c.last_name)) > 0
                THEN CONCAT_WS(CHR(32), c.first_name, c.last_name)
                ELSE COALESCE(c.email, 'Guest') END AS customer,
           f.source_name AS source,
           COALESCE(f.source_name, 'unknown') AS channel,
           COUNT(*) OVER() AS total_records
    FROM filtered_orders f
    LEFT JOIN public.dim_customers c ON c.id = f.customer_id
    ORDER BY f.cancelled_at DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'TABLE',
    60,
    'Detailed audit log of cancelled orders including customer, date, lost value, and channel.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
);

--changeset kosul:RW-38-3
--comment seed Payments & Collections tab 

INSERT INTO chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31d-7a4d-96d2-1b2921c3001d',
    'Payments & Collections KPIs',
    'Order Reports/Payments & Collections/KPI/Payments & Collections KPIs',
    $$
    WITH
    /*comparison_window_cte*/
    scoped_orders AS (
        SELECT * FROM (
            SELECT UPPER(o.financialStatus) AS financial_status,
                   ((w.cur_start IS NULL OR o.created_at::date >= w.cur_start)
                AND (w.cur_end   IS NULL OR o.created_at::date <= w.cur_end))  AS is_current,
                   (w.prv_start IS NOT NULL
                AND o.created_at::date BETWEEN w.prv_start AND w.prv_end)      AS is_prior,
                   COALESCE(o.total_outstanding_amount, 0) AS outstanding_amount
            FROM public.fact_order_headers o
            CROSS JOIN windows w
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.cancelled_at IS NULL
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    totals AS (
        SELECT COALESCE(SUM(outstanding_amount) FILTER (WHERE is_current), 0) AS cur_outstanding,
               COALESCE(SUM(outstanding_amount) FILTER (WHERE is_prior),   0) AS prv_outstanding,
               ROUND(COALESCE(100.0 * COUNT(*) FILTER (WHERE is_current AND financial_status = 'PAID')
                              / NULLIF(COUNT(*) FILTER (WHERE is_current), 0), 0), 2) AS cur_paid_rate,
               ROUND(COALESCE(100.0 * COUNT(*) FILTER (WHERE is_prior AND financial_status = 'PAID')
                              / NULLIF(COUNT(*) FILTER (WHERE is_prior), 0), 0), 2) AS prv_paid_rate
        FROM scoped_orders
    )
    SELECT ROUND(t.cur_outstanding, 2) AS outstanding_amount,
           ROUND(100 * (t.cur_outstanding - t.prv_outstanding)
                 / NULLIF(ABS(t.prv_outstanding), 0), 2) AS outstanding_amount_divergence,
           t.cur_paid_rate AS paid_order_rate,
           ROUND(100 * (t.cur_paid_rate - t.prv_paid_rate)
                 / NULLIF(ABS(t.prv_paid_rate), 0), 2) AS paid_order_rate_divergence
    FROM totals t
    $$,
    NULL,
    'KPI',
    60,
    'KPI metrics evaluating total unpaid outstanding order balance and paid order rate % vs prior period.',
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
        {
          "provider": "COMPARISON_WINDOW_CTE",
          "condition": "hasFilter:startDate",
          "placeholder": "/*comparison_window_cte*/",
          "args": {
            "currentStartParam": "currentStartDate",
            "currentEndParam": "currentEndDate",
            "priorStartParam": "priorStartDate",
            "priorEndParam": "priorEndDate"
          }
        }
      ]
    }'
),
(
    '019fff82-e31d-7c28-8dee-e197d859bba8',
    'Unpaid Orders Aging',
    'Order Reports/Payments & Collections/PLOT/Unpaid Orders Aging',
    $$
    WITH filtered_orders AS (
        SELECT COALESCE(o.total_outstanding_amount, 0) AS outstanding_amount,
               (COALESCE(:currentEndDate::date, CURRENT_DATE) - o.created_at::date) AS age_days
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND o.total_outstanding_amount > 0
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    buckets AS (
        SELECT ROUND(COALESCE(SUM(outstanding_amount) FILTER (WHERE age_days <= 1), 0), 2)             AS "0-1 days",
               ROUND(COALESCE(SUM(outstanding_amount) FILTER (WHERE age_days BETWEEN 2 AND 3), 0), 2)  AS "2-3 days",
               ROUND(COALESCE(SUM(outstanding_amount) FILTER (WHERE age_days BETWEEN 4 AND 7), 0), 2)  AS "4-7 days",
               ROUND(COALESCE(SUM(outstanding_amount) FILTER (WHERE age_days > 7), 0), 2)              AS "7+ days"
        FROM filtered_orders
    )
    SELECT e.bucket AS bucket,
           e.amount::numeric AS outstanding_amount
    FROM buckets b,
         json_each_text(row_to_json(b)) WITH ORDINALITY AS e(bucket, amount, ord)
    ORDER BY e.ord
    $$,
    NULL,
    'PLOT',
    60,
    'Aging distribution of unpaid outstanding order balances (0-1 days to 7+ days).',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31d-7adf-9ec0-da4952b71ce1',
    'Payment Gateway Mix',
    'Order Reports/Payments & Collections/PLOT/Payment Gateway Mix',
    $$
    WITH filtered_orders AS (
        SELECT o.id
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT COALESCE(t.gateway, 'unknown') AS gateway,
           ROUND(COALESCE(SUM(t.amount), 0), 2) AS "Order Value"
    FROM public.fact_order_transactions t
    JOIN filtered_orders f ON f.id = t.order_id
    WHERE UPPER(t.kind) = 'SALE'
      AND UPPER(t.status) = 'SUCCESS'
    GROUP BY 1
    ORDER BY 2 DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'PLOT',
    60,
    'Distribution of paid order volume across payment gateways.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31d-772e-a943-97b7591e0ecd',
    'Unpaid Orders Queue',
    'Order Reports/Payments & Collections/TABLE/Unpaid Orders Queue',
    $$
    WITH filtered_orders AS (
        SELECT o.id,
               o.id AS order_id,
               o.created_at,
               o.customer_id,
               o.financialStatus AS financial_status,
               o.payment_gateway_names,
               COALESCE(o.total_outstanding_amount, 0) AS outstanding_amount
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND o.total_outstanding_amount > 0
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT f.order_id,
           CASE WHEN LENGTH(CONCAT_WS(CHR(32), c.first_name, c.last_name)) > 0
                THEN CONCAT_WS(CHR(32), c.first_name, c.last_name)
                ELSE COALESCE(c.email, 'Guest') END AS customer,
           f.created_at::date::text AS order_date,
           ROUND(f.outstanding_amount, 2) AS outstanding_amount,
           f.financial_status,
           COALESCE(t.gateway, f.payment_gateway_names->>0, 'unknown') AS payment_gateway,
           (COALESCE(:currentEndDate::date, CURRENT_DATE) - f.created_at::date) AS days_unpaid,
           COUNT(*) OVER() AS total_records
    FROM filtered_orders f
    LEFT JOIN public.dim_customers c ON c.id = f.customer_id
    LEFT JOIN public.fact_order_transactions t ON t.order_id = f.id AND UPPER(t.kind) = 'SALE' AND UPPER(t.status) = 'SUCCESS'
    ORDER BY days_unpaid DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'TABLE',
    60,
    'Actionable queue table listing unpaid orders sorted by aging days unpaid.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
);

--changeset kosul:RW-38-4
--comment seed Customers tab 
INSERT INTO chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31d-7e39-a770-59ebdce216a3',
    'Orders by Customer Type',
    'Order Reports/Customers/KPI/Orders by Customer Type',
    $$
    WITH
    /*comparison_window_cte*/
    customer_order_ranks AS (
        SELECT o.created_at::date AS day,
               ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.created_at ASC, o.id ASC) AS order_rank
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND o.customer_id IS NOT NULL
    ),
    scoped_orders AS (
        SELECT * FROM (
            SELECT r.order_rank,
                   ((w.cur_start IS NULL OR r.day >= w.cur_start)
                AND (w.cur_end   IS NULL OR r.day <= w.cur_end))  AS is_current,
                   (w.prv_start IS NOT NULL
                AND r.day BETWEEN w.prv_start AND w.prv_end)      AS is_prior
            FROM customer_order_ranks r
            CROSS JOIN windows w
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    scoped_guest_orders AS (
        SELECT * FROM (
            SELECT ((w.cur_start IS NULL OR o.created_at::date >= w.cur_start)
                AND (w.cur_end   IS NULL OR o.created_at::date <= w.cur_end))  AS is_current,
                   (w.prv_start IS NOT NULL
                AND o.created_at::date BETWEEN w.prv_start AND w.prv_end)      AS is_prior
            FROM public.fact_order_headers o
            CROSS JOIN windows w
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.cancelled_at IS NULL
              AND o.customer_id IS NULL
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    known AS (
        SELECT COUNT(*) FILTER (WHERE is_current AND order_rank = 1) AS cur_new,
               COUNT(*) FILTER (WHERE is_prior   AND order_rank = 1) AS prv_new,
               COUNT(*) FILTER (WHERE is_current AND order_rank > 1) AS cur_repeat,
               COUNT(*) FILTER (WHERE is_prior   AND order_rank > 1) AS prv_repeat
        FROM scoped_orders
    ),
    guests AS (
        SELECT COUNT(*) FILTER (WHERE is_current) AS cur_guest,
               COUNT(*) FILTER (WHERE is_prior)   AS prv_guest
        FROM scoped_guest_orders
    ),
    computed AS (
        SELECT k.cur_new + g.cur_guest AS cur_new_orders,
               k.prv_new + g.prv_guest AS prv_new_orders,
               k.cur_repeat AS cur_repeat_orders,
               k.prv_repeat AS prv_repeat_orders
        FROM known k
        CROSS JOIN guests g
    )
    SELECT c.cur_new_orders AS new_orders,
           ROUND(100 * (c.cur_new_orders - c.prv_new_orders)
                 / NULLIF(ABS(c.prv_new_orders), 0), 2) AS new_orders_divergence,
           c.cur_repeat_orders AS repeat_orders,
           ROUND(100 * (c.cur_repeat_orders - c.prv_repeat_orders)
                 / NULLIF(ABS(c.prv_repeat_orders), 0), 2) AS repeat_orders_divergence
    FROM computed c
    $$,
    NULL,
    'KPI',
    60,
    'KPI breakdown of order volume split between new customers (including guests) vs repeat returning customers vs prior period.',
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
        {
          "provider": "COMPARISON_WINDOW_CTE",
          "condition": "hasFilter:startDate",
          "placeholder": "/*comparison_window_cte*/",
          "args": {
            "currentStartParam": "currentStartDate",
            "currentEndParam": "currentEndDate",
            "priorStartParam": "priorStartDate",
            "priorEndParam": "priorEndDate"
          }
        }
      ]
    }'
),
(
    '019fff82-e31d-7cbb-9e99-db4ae79df001',
    'New vs Repeat Orders',
    'Order Reports/Customers/PLOT/New vs Repeat Orders',
    $$
    WITH
    /*date_granularity_cte*/
    customer_order_ranks AS (
        SELECT o.id,
               date_trunc(LOWER(dp.g), o.created_at) AS bucket,
               ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.created_at ASC, o.id ASC) AS order_rank
        FROM public.fact_order_headers o
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND o.customer_id IS NOT NULL
          AND o.created_at >= dp.start_bucket
          AND o.created_at <= dp.end_bucket
    ),
    guest_orders AS (
        SELECT date_trunc(LOWER(dp.g), o.created_at) AS bucket
        FROM public.fact_order_headers o
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND o.customer_id IS NULL
          AND o.created_at >= dp.start_bucket
          AND o.created_at <= dp.end_bucket
    ),
    daily AS (
        SELECT r.bucket,
               COUNT(*) FILTER (WHERE r.order_rank = 1) AS new_orders,
               COUNT(*) FILTER (WHERE r.order_rank > 1) AS repeat_orders
        FROM customer_order_ranks r
        GROUP BY r.bucket
    ),
    daily_guests AS (
        SELECT g.bucket,
               COUNT(*) AS guest_new_orders
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
           COALESCE(d.new_orders, 0) + COALESCE(g.guest_new_orders, 0) AS new_orders,
           COALESCE(d.repeat_orders, 0) AS repeat_orders
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily d ON d.bucket = df.bucket
    LEFT JOIN daily_guests g ON g.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Comparative order count trend of new vs repeat orders grouped by dynamic date granularity.',
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
        {
          "provider": "DATE_GRANULARITY_CTE",
          "condition": "hasFilter:startDate",
          "placeholder": "/*date_granularity_cte*/",
          "args": {
            "startDateParam": "currentStartDate",
            "endDateParam": "currentEndDate",
            "granularityParam": "granularity"
          }
        }
      ]
    }'
);

--changeset kosul:RW-38-5
--comment seed Channels & Geography tab 

INSERT INTO chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31d-7383-af37-68c2c40c388b',
    'Sales by Channel',
    'Order Reports/Channels & Geography/PLOT/Sales by Channel',
    $$
    WITH filtered_orders AS (
        SELECT o.id,
               o.source_name,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT
        COALESCE(f.source_name, 'unknown') AS name,
        ROUND(SUM(f.net_sales), 2) AS net_sales,
        COUNT(*) AS orders
    FROM filtered_orders f
    GROUP BY 1
    ORDER BY net_sales DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'PLOT',
    60,
    'Sales and order volume breakdown grouped across channel, source, and integration apps.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31d-7247-92b0-22f212b5136c',
    'Channel Order Report',
    'Order Reports/Channels & Geography/TABLE/Channel Order Report',
    $$
    WITH filtered_orders AS (
        SELECT o.id,
               COALESCE(o.source_name, 'unknown') AS source,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    channel_totals AS (
        SELECT source,
               SUM(net_sales) AS net_sales,
               COUNT(*) AS orders
        FROM filtered_orders
        GROUP BY source
    ),
    channel_lines AS (
        SELECT f.source,
               SUM(li.original_unit_price * li.quantity) AS gross_sales,
               SUM(li.discounted_total_amount) AS discounted
        FROM public.fact_order_line_items li
        JOIN filtered_orders f ON f.id = li.order_id
        GROUP BY f.source
    ),
    channel_refunds AS (
        SELECT f.source,
               SUM(COALESCE(r.total_refunded_amount, 0)) AS refunded
        FROM public.fact_order_refunds r
        JOIN filtered_orders f ON f.id = r.order_id
        GROUP BY f.source
    )
    SELECT ct.source AS channel,
           ct.source AS source,
           ct.orders AS orders,
           ROUND(ct.net_sales, 2) AS net_sales,
           ROUND(ct.net_sales / NULLIF(ct.orders, 0), 2) AS aov,
           ROUND(100 * COALESCE(cr.refunded, 0) / NULLIF(cl.gross_sales, 0), 2) AS refund_rate,
           ROUND(100 * (cl.gross_sales - COALESCE(cl.discounted, 0)) / NULLIF(cl.gross_sales, 0), 2) AS discount_rate,
           COUNT(*) OVER() AS total_records
    FROM channel_totals ct
    LEFT JOIN channel_lines cl ON cl.source IS NOT DISTINCT FROM ct.source
    LEFT JOIN channel_refunds cr ON cr.source IS NOT DISTINCT FROM ct.source
    ORDER BY ct.net_sales DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'TABLE',
    60,
    'Comparative performance report across channels evaluating orders, net sales, AOV, refund %, and discount %.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31d-7eca-b184-91c61334d67c',
    'Orders by Geography',
    'Order Reports/Channels & Geography/PLOT/Orders by Geography',
    '
    WITH filtered_orders AS (
        SELECT o.id,
               COALESCE(
                   o.shipping_address #>> ''{country}'',
                   o.shipping_address #>> ''{province}'',
                   o.shipping_address #>> ''{city}'',
                   ''Unknown''
               ) AS geography,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT f.geography AS name,
           ROUND(SUM(f.net_sales), 2) AS net_sales,
           COUNT(*) AS orders
    FROM filtered_orders f
    GROUP BY f.geography
    ORDER BY net_sales DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Distribution of order volume and net sales grouped by customer destination country, province, or city.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31d-78eb-98ea-48b41df26c99',
    'Geography Sales Report',
    'Order Reports/Channels & Geography/TABLE/Geography Sales Report',
    '
    WITH filtered_orders AS (
        SELECT o.id,
               COALESCE(o.shipping_address #>> ''{country}'', ''Unknown'') AS country,
               COALESCE(o.shipping_address #>> ''{province}'', ''Unknown'') AS province,
               COALESCE(o.shipping_address #>> ''{city}'', ''Unknown'') AS city,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    geo_totals AS (
        SELECT country, province, city,
               SUM(net_sales) AS net_sales,
               COUNT(*) AS orders
        FROM filtered_orders
        GROUP BY country, province, city
    ),
    geo_lines AS (
        SELECT fo.country, fo.province, fo.city,
               SUM(li.original_unit_price * li.quantity) AS gross_sales
        FROM public.fact_order_line_items li
        JOIN filtered_orders fo ON fo.id = li.order_id
        GROUP BY fo.country, fo.province, fo.city
    ),
    geo_refunds AS (
        SELECT fo.country, fo.province, fo.city,
               SUM(COALESCE(r.total_refunded_amount, 0)) AS refunded
        FROM public.fact_order_refunds r
        JOIN filtered_orders fo ON fo.id = r.order_id
        GROUP BY fo.country, fo.province, fo.city
    )
    SELECT gt.country AS country,
           gt.province AS province,
           gt.city AS city,
           gt.orders AS orders,
           ROUND(gt.net_sales, 2) AS sales,
           ROUND(gt.net_sales / NULLIF(gt.orders, 0), 2) AS aov,
           ROUND(100 * COALESCE(gr.refunded, 0) / NULLIF(gl.gross_sales, 0), 2) AS refund_rate,
           COUNT(*) OVER() AS total_records
    FROM geo_totals gt
    LEFT JOIN geo_lines gl
        ON gl.country IS NOT DISTINCT FROM gt.country
       AND gl.province IS NOT DISTINCT FROM gt.province
       AND gl.city IS NOT DISTINCT FROM gt.city
    LEFT JOIN geo_refunds gr
        ON gr.country IS NOT DISTINCT FROM gt.country
       AND gr.province IS NOT DISTINCT FROM gt.province
       AND gr.city IS NOT DISTINCT FROM gt.city
    ORDER BY gt.net_sales DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Detailed geographic report breakdown per Country, Province, and City evaluating orders, sales, AOV, and refund rate %.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
);