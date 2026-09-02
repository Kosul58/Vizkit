--liquibase formatted sql logicalFilePath:20260812002_analytical_sales_channel_attribution.sql

--changeset saugat:RW-46-1
--comment seed Channel Performance tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fffa2-0f80-7a28-bd46-3540650afb5d',
    'Channel Performance KPIs',
    'Sales Channel Attribution/Channel Performance/KPI/Channel Performance KPIs',
    '
    WITH
    /*comparison_window_cte*/
    scoped_orders AS (
        SELECT * FROM (
            SELECT ((w.cur_start IS NULL OR o.created_at::date >= w.cur_start)
                AND (w.cur_end   IS NULL OR o.created_at::date <= w.cur_end))  AS is_current,
                   (w.prv_start IS NOT NULL
                AND o.created_at::date BETWEEN w.prv_start AND w.prv_end)      AS is_prior,
                   COALESCE(ch.name, app.name, o.source_name, ''Unattributed'') AS channel,
                   COALESCE(o.current_total_price, 0)
                     - COALESCE(o.current_total_tax, 0)
                     - COALESCE(o.current_shipping_price, 0) AS net_sales
            FROM orders o
            LEFT JOIN channel ch ON ch.id = o.channel_id
            LEFT JOIN order_app app ON app.id = o.order_app_id
            CROSS JOIN windows w
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    order_totals AS (
        SELECT COALESCE(SUM(net_sales) FILTER (WHERE is_current), 0) AS cur_net_sales,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior),   0) AS prv_net_sales,
               COUNT(*) FILTER (WHERE is_current) AS cur_orders,
               COUNT(*) FILTER (WHERE is_prior)   AS prv_orders
        FROM scoped_orders
    ),
    channel_current AS (
        SELECT channel,
               SUM(net_sales) AS net_sales,
               COUNT(*) AS orders,
               SUM(net_sales) / NULLIF(COUNT(*), 0) AS aov
        FROM scoped_orders
        WHERE is_current
        GROUP BY channel
    ),
    top_revenue AS (
        SELECT channel
        FROM channel_current
        ORDER BY net_sales DESC NULLS LAST, channel ASC
        LIMIT 1
    ),
    top_aov AS (
        SELECT channel
        FROM channel_current
        ORDER BY aov DESC NULLS LAST, channel ASC
        LIMIT 1
    ),
    computed AS (
        SELECT ot.cur_net_sales, ot.prv_net_sales,
               ot.cur_orders, ot.prv_orders,
               ROUND(ot.cur_net_sales / NULLIF(ot.cur_orders, 0), 2) AS cur_aov,
               ROUND(ot.prv_net_sales / NULLIF(ot.prv_orders, 0), 2) AS prv_aov
        FROM order_totals ot
    )
    SELECT ROUND(c.cur_net_sales, 2) AS total_channel_revenue,
           ROUND(100 * (c.cur_net_sales - c.prv_net_sales)
                 / NULLIF(ABS(c.prv_net_sales), 0), 2) AS total_channel_revenue_divergence,
           c.cur_orders AS channel_orders,
           ROUND(100.0 * (c.cur_orders - c.prv_orders)
                 / NULLIF(ABS(c.prv_orders), 0), 2) AS channel_orders_divergence,
           c.cur_aov AS channel_aov,
           ROUND(100 * (c.cur_aov - c.prv_aov)
                 / NULLIF(ABS(c.prv_aov), 0), 2) AS channel_aov_divergence,
           COALESCE((SELECT channel FROM top_revenue), ''No data'') AS top_revenue_channel,
           COALESCE((SELECT channel FROM top_aov), ''No data'') AS top_aov_channel
    FROM computed c
    ',
    NULL,
    'KPI',
    60,
    'Sales channel KPIs evaluating total channel revenue, total channel orders, channel AOV, top revenue channel, and top AOV channel.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        { "provider": "COMPARISON_WINDOW_CTE", "condition": "hasFilter:startDate", "placeholder": "/*comparison_window_cte*/",
          "args": { "currentStartParam": "currentStartDate", "currentEndParam": "currentEndDate", "priorStartParam": "priorStartDate", "priorEndParam": "priorEndDate" } }
      ]
    }'
),
(
    '019fffa2-0f80-77ca-b168-dec3d25e1385',
    'Revenue by Channel',
    'Sales Channel Attribution/Channel Performance/PLOT/Revenue by Channel',
    '
    WITH filtered_orders AS (
        SELECT COALESCE(ch.name, app.name, o.source_name, ''Unattributed'') AS channel,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM orders o
        LEFT JOIN channel ch ON ch.id = o.channel_id
        LEFT JOIN order_app app ON app.id = o.order_app_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT f.channel AS channel,
           ROUND(SUM(f.net_sales), 2) AS net_sales
    FROM filtered_orders f
    GROUP BY f.channel
    ORDER BY SUM(f.net_sales) DESC, f.channel ASC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Revenue distribution per sales channel.',
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
    '019fffa2-0f80-75e3-b775-87a0a8633e24',
    'Orders by Channel',
    'Sales Channel Attribution/Channel Performance/PLOT/Orders by Channel',
    '
    WITH filtered_orders AS (
        SELECT COALESCE(ch.name, app.name, o.source_name, ''Unattributed'') AS channel
        FROM orders o
        LEFT JOIN channel ch ON ch.id = o.channel_id
        LEFT JOIN order_app app ON app.id = o.order_app_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT f.channel AS channel,
           COUNT(*) AS orders
    FROM filtered_orders f
    GROUP BY f.channel
    ORDER BY COUNT(*) DESC, f.channel ASC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Order count distribution per sales channel.',
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
    '019fffa2-0f80-7d9e-8291-cc8dd6928cfd',
    'Channel AOV Comparison',
    'Sales Channel Attribution/Channel Performance/PLOT/Channel AOV Comparison',
    '
    WITH filtered_orders AS (
        SELECT COALESCE(ch.name, app.name, o.source_name, ''Unattributed'') AS channel,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM orders o
        LEFT JOIN channel ch ON ch.id = o.channel_id
        LEFT JOIN order_app app ON app.id = o.order_app_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT f.channel AS channel,
           ROUND(SUM(f.net_sales) / NULLIF(COUNT(*), 0), 2) AS aov
    FROM filtered_orders f
    GROUP BY f.channel
    ORDER BY SUM(f.net_sales) / NULLIF(COUNT(*), 0) DESC NULLS LAST, f.channel ASC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Average Order Value (AOV) comparison across sales channels.',
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
    '019fffa2-0f80-777c-ae56-782c587a8bde',
    'Channel Revenue Trend',
    'Sales Channel Attribution/Channel Performance/PLOT/Channel Revenue Trend',
    '
    WITH
    /*date_granularity_cte*/
    filtered_orders AS (
        SELECT date_trunc(LOWER(dp.g), o.created_at) AS bucket,
               CASE WHEN LOWER(o.source_name) = ''web'' THEN 1
                    WHEN LOWER(o.source_name) = ''pos'' THEN 2
                    WHEN LOWER(o.source_name) IN (''mobile'', ''iphone'', ''android'') THEN 3
                    WHEN LOWER(o.source_name) IN (''social'', ''facebook'', ''instagram'',
                                                  ''pinterest'', ''tiktok'') THEN 4
                    ELSE 5 END AS channel_bucket,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM orders o
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.created_at >= dp.start_bucket
          AND o.created_at <= :currentEndDate::date
    ),
    daily AS (
        SELECT f.bucket,
               SUM(f.net_sales) FILTER (WHERE f.channel_bucket = 1) AS online_store,
               SUM(f.net_sales) FILTER (WHERE f.channel_bucket = 2) AS point_of_sale,
               SUM(f.net_sales) FILTER (WHERE f.channel_bucket = 3) AS mobile,
               SUM(f.net_sales) FILTER (WHERE f.channel_bucket = 4) AS social,
               SUM(f.net_sales) FILTER (WHERE f.channel_bucket = 5) AS other
        FROM filtered_orders f
        GROUP BY f.bucket
    )
    SELECT to_char(df.bucket,
               CASE WHEN dp.g = ''DAY''   THEN ''Mon DD, YYYY''
                    WHEN dp.g = ''WEEK''  THEN ''Mon DD, YYYY''
                    WHEN dp.g = ''MONTH'' THEN ''Mon YYYY''
                    WHEN dp.g = ''YEAR''  THEN ''YYYY''
               END
           ) AS period,
           df.bucket,
           ROUND(COALESCE(d.online_store, 0), 2) AS "Online Store",
           ROUND(COALESCE(d.point_of_sale, 0), 2) AS "Point of Sale",
           ROUND(COALESCE(d.mobile, 0), 2) AS "Mobile",
           ROUND(COALESCE(d.social, 0), 2) AS "Social",
           ROUND(COALESCE(d.other, 0), 2) AS "Other"
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily d ON d.bucket = df.bucket
    ORDER BY df.bucket ASC
    ',
    NULL,
    'PLOT',
    60,
    'Revenue trend across major sales channels grouped by dynamic date granularity.',
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
    '019fffa2-0f80-7889-9761-5bc951290334',
    'Channel Performance Report',
    'Sales Channel Attribution/Channel Performance/TABLE/Channel Performance Report',
    '
    WITH filtered_orders AS (
        SELECT o.id,
               COALESCE(ch.name, app.name, o.source_name, ''Unattributed'') AS channel,
               o.source_name AS source_name,
               app.name AS app_name,
               COALESCE(o.subtotal_price, 0) + COALESCE(o.total_discounts_amount, 0) AS gross_sales,
               COALESCE(o.total_discounts_amount, 0) AS discounts,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM orders o
        LEFT JOIN channel ch ON ch.id = o.channel_id
        LEFT JOIN order_app app ON app.id = o.order_app_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    channel_totals AS (
        SELECT f.channel,
               COUNT(*) AS orders,
               SUM(f.gross_sales) AS gross_sales,
               SUM(f.discounts) AS discounts,
               SUM(f.net_sales) AS net_sales,
               string_agg(DISTINCT f.source_name, CHR(44) || CHR(32)) AS source,
               string_agg(DISTINCT f.app_name, CHR(44) || CHR(32)) AS app
        FROM filtered_orders f
        GROUP BY f.channel
    ),
    channel_refunds AS (
        SELECT f.channel,
               SUM(COALESCE(r.total_refunded_amount, 0)) AS refunded
        FROM refund r
        JOIN filtered_orders f ON f.id = r.order_id
        GROUP BY f.channel
    )
    SELECT ct.channel AS channel,
           COALESCE(ct.source, ''Unknown'') AS source,
           COALESCE(ct.app, ''Unknown'') AS app,
           ct.orders AS orders,
           ROUND(ct.gross_sales, 2) AS gross_sales,
           ROUND(ct.discounts, 2) AS discounts,
           ROUND(ct.net_sales, 2) AS net_sales,
           ROUND(ct.net_sales / NULLIF(ct.orders, 0), 2) AS aov,
           ROUND(100 * COALESCE(cr.refunded, 0) / NULLIF(ct.gross_sales, 0), 2) AS refund_rate,
           COUNT(*) OVER() AS total_records
    FROM channel_totals ct
    LEFT JOIN channel_refunds cr ON cr.channel IS NOT DISTINCT FROM ct.channel
    ORDER BY ct.net_sales DESC, ct.channel ASC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Comprehensive scorecard table per sales channel showing orders, gross sales, discounts, net sales, AOV, and refund rate %.',
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
    '019fffa2-0f80-7a6c-a7fa-d1b9b8e71fd8',
    'Channel Order Detail Report',
    'Sales Channel Attribution/Channel Performance/TABLE/Channel Order Detail Report',
    '
    WITH filtered_orders AS (
        SELECT o.id,
               o.order_gid,
               o.created_at,
               o.customer_id,
               o.source_name,
               o.financial_status,
               COALESCE(ch.name, app.name, o.source_name, ''Unattributed'') AS channel,
               app.name AS app_name,
               COALESCE(o.total_price, o.current_total_price, 0) AS order_total,
               COALESCE(o.total_discounts_amount, 0) AS discounts,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM orders o
        LEFT JOIN channel ch ON ch.id = o.channel_id
        LEFT JOIN order_app app ON app.id = o.order_app_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    order_refunds AS (
        SELECT f.id,
               SUM(COALESCE(r.total_refunded_amount, 0)) AS refunded
        FROM filtered_orders f
        LEFT JOIN refund r ON r.order_id = f.id
        GROUP BY f.id
    )
    SELECT f.order_gid AS order_id,
           f.created_at::date::text AS order_date,
           CASE WHEN LENGTH(CONCAT_WS(CHR(32), c.first_name, c.last_name)) > 0
                THEN CONCAT_WS(CHR(32), c.first_name, c.last_name)
                ELSE COALESCE(c.email, ''Guest'') END AS customer,
           f.channel AS channel,
           COALESCE(f.source_name, ''Unknown'') AS source,
           COALESCE(f.app_name, ''Unknown'') AS app,
           ROUND(f.net_sales, 2) AS net_sales,
           ROUND(f.discounts, 2) AS discounts,
           CASE WHEN COALESCE(orf.refunded, 0) <= 0            THEN ''None''
                WHEN orf.refunded >= f.order_total - 0.01      THEN ''Full''
                ELSE ''Partial'' END AS refund_status,
           f.financial_status AS financial_status,
           COUNT(*) OVER() AS total_records
    FROM filtered_orders f
    LEFT JOIN order_refunds orf ON orf.id = f.id
    LEFT JOIN sh_customer c ON c.id = f.customer_id
    ORDER BY f.created_at DESC, f.id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Detailed audit log table of individual channel orders listing date, customer, channel, source, app, sales, discounts, refund status, and financial status.',
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

--changeset saugat:RW-46-2
--comment seed Channel Quality & Profitability tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fffa2-0f80-7819-9ed6-49cfe9e1ccfc',
    'Channel Quality KPIs',
    'Sales Channel Attribution/Channel Quality & Profitability/KPI/Channel Quality KPIs',
    '
    WITH
    /*comparison_window_cte*/
    scoped_orders AS (
        SELECT * FROM (
            SELECT o.id,
                   ((w.cur_start IS NULL OR o.created_at::date >= w.cur_start)
                AND (w.cur_end   IS NULL OR o.created_at::date <= w.cur_end))  AS is_current,
                   (w.prv_start IS NOT NULL
                AND o.created_at::date BETWEEN w.prv_start AND w.prv_end)      AS is_prior,
                   COALESCE(o.subtotal_price, 0) + COALESCE(o.total_discounts_amount, 0) AS gross_sales,
                   COALESCE(o.total_discounts_amount, 0) AS discounts,
                   COALESCE(o.current_total_price, 0)
                     - COALESCE(o.current_total_tax, 0)
                     - COALESCE(o.current_shipping_price, 0) AS net_sales
            FROM orders o
            CROSS JOIN windows w
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    order_totals AS (
        SELECT COALESCE(SUM(gross_sales) FILTER (WHERE is_current), 0) AS cur_gross,
               COALESCE(SUM(gross_sales) FILTER (WHERE is_prior),   0) AS prv_gross,
               COALESCE(SUM(discounts) FILTER (WHERE is_current), 0) AS cur_discounts,
               COALESCE(SUM(discounts) FILTER (WHERE is_prior),   0) AS prv_discounts,
               COALESCE(SUM(net_sales) FILTER (WHERE is_current), 0) AS cur_net,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior),   0) AS prv_net
        FROM scoped_orders
    ),
    refund_totals AS (
        SELECT COALESCE(SUM(COALESCE(r.total_refunded_amount, 0))
                        FILTER (WHERE s.is_current), 0) AS cur_refunded,
               COALESCE(SUM(COALESCE(r.total_refunded_amount, 0))
                        FILTER (WHERE s.is_prior),   0) AS prv_refunded
        FROM refund r
        JOIN scoped_orders s ON s.id = r.order_id
    ),
    computed AS (
        SELECT ot.cur_net, ot.prv_net,
               ROUND(100 * rt.cur_refunded / NULLIF(ot.cur_gross, 0), 2) AS cur_refund_rate,
               ROUND(100 * rt.prv_refunded / NULLIF(ot.prv_gross, 0), 2) AS prv_refund_rate,
               ROUND(100 * ot.cur_discounts / NULLIF(ot.cur_gross, 0), 2) AS cur_discount_rate,
               ROUND(100 * ot.prv_discounts / NULLIF(ot.prv_gross, 0), 2) AS prv_discount_rate
        FROM order_totals ot
        CROSS JOIN refund_totals rt
    )
    SELECT ROUND(c.cur_net, 2) AS net_revenue_after_refunds,
           ROUND(100 * (c.cur_net - c.prv_net)
                 / NULLIF(ABS(c.prv_net), 0), 2) AS net_revenue_after_refunds_divergence,
           c.cur_refund_rate AS channel_refund_rate,
           ROUND(100 * (c.cur_refund_rate - c.prv_refund_rate)
                 / NULLIF(ABS(c.prv_refund_rate), 0), 2) AS channel_refund_rate_divergence,
           c.cur_discount_rate AS channel_discount_rate,
           ROUND(100 * (c.cur_discount_rate - c.prv_discount_rate)
                 / NULLIF(ABS(c.prv_discount_rate), 0), 2) AS channel_discount_rate_divergence
    FROM computed c
    ',
    NULL,
    'KPI',
    60,
    'Quality KPIs evaluating net revenue after refunds, overall channel refund rate %, and channel discount rate % vs prior period.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        { "provider": "COMPARISON_WINDOW_CTE", "condition": "hasFilter:startDate", "placeholder": "/*comparison_window_cte*/",
          "args": { "currentStartParam": "currentStartDate", "currentEndParam": "currentEndDate", "priorStartParam": "priorStartDate", "priorEndParam": "priorEndDate" } }
      ]
    }'
),
(
    '019fffa2-0f80-77bd-8a78-95f23c54470b',
    'Channel Quality Matrix',
    'Sales Channel Attribution/Channel Quality & Profitability/PLOT/Channel Quality Matrix',
    '
    WITH filtered_orders AS (
        SELECT o.id,
               COALESCE(ch.name, app.name, o.source_name, ''Unattributed'') AS channel,
               COALESCE(o.subtotal_price, 0) + COALESCE(o.total_discounts_amount, 0) AS gross_sales,
               COALESCE(o.total_discounts_amount, 0) AS discounts,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM orders o
        LEFT JOIN channel ch ON ch.id = o.channel_id
        LEFT JOIN order_app app ON app.id = o.order_app_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    channel_refunds AS (
        SELECT f.channel,
               SUM(COALESCE(r.total_refunded_amount, 0)) AS refunded
        FROM refund r
        JOIN filtered_orders f ON f.id = r.order_id
        GROUP BY f.channel
    ),
    channel_agg AS (
        SELECT f.channel,
               SUM(f.net_sales) AS net_sales,
               SUM(f.net_sales) / NULLIF(COUNT(*), 0) AS aov,
               SUM(f.gross_sales) AS gross_sales,
               SUM(f.discounts) AS discounts
        FROM filtered_orders f
        GROUP BY f.channel
    ),
    channel_metrics AS (
        SELECT ca.channel,
               ca.net_sales,
               ca.aov,
               COALESCE(100 * COALESCE(cr.refunded, 0) / NULLIF(ca.gross_sales, 0), 0) AS refund_rate,
               COALESCE(100 * ca.discounts / NULLIF(ca.gross_sales, 0), 0) AS discount_rate
        FROM channel_agg ca
        LEFT JOIN channel_refunds cr ON cr.channel IS NOT DISTINCT FROM ca.channel
    ),
    ranges AS (
        SELECT cm.channel, cm.net_sales, cm.aov, cm.refund_rate, cm.discount_rate,
               MIN(cm.net_sales)    OVER () AS min_net, MAX(cm.net_sales)    OVER () AS max_net,
               MIN(cm.aov)          OVER () AS min_aov, MAX(cm.aov)          OVER () AS max_aov,
               MIN(cm.refund_rate)  OVER () AS min_rr,  MAX(cm.refund_rate)  OVER () AS max_rr,
               MIN(cm.discount_rate) OVER () AS min_dr, MAX(cm.discount_rate) OVER () AS max_dr
        FROM channel_metrics cm
    )
    SELECT r.channel AS channel,
           COALESCE(ROUND(100 * (r.net_sales - r.min_net)
                          / NULLIF(r.max_net - r.min_net, 0)), 100) AS "Revenue",
           COALESCE(ROUND(100 * (r.aov - r.min_aov)
                          / NULLIF(r.max_aov - r.min_aov, 0)), 100) AS "AOV",
           COALESCE(ROUND(100 * (r.max_rr - r.refund_rate)
                          / NULLIF(r.max_rr - r.min_rr, 0)), 100) AS "Low Refund Rate",
           COALESCE(ROUND(100 * (r.max_dr - r.discount_rate)
                          / NULLIF(r.max_dr - r.min_dr, 0)), 100) AS "Low Discount Rate"
    FROM ranges r
    ORDER BY r.net_sales DESC, r.channel ASC
    ',
    NULL,
    'PLOT',
    60,
    'Normalized quality index matrix comparing revenue, AOV, low refund rate, and low discount rate across channels.',
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
    '019fffa2-0f80-75b9-ab4b-b31d2a23ed61',
    'Net Revenue After Refunds by Channel',
    'Sales Channel Attribution/Channel Quality & Profitability/PLOT/Net Revenue After Refunds by Channel',
    '
    WITH filtered_orders AS (
        SELECT COALESCE(ch.name, app.name, o.source_name, ''Unattributed'') AS channel,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM orders o
        LEFT JOIN channel ch ON ch.id = o.channel_id
        LEFT JOIN order_app app ON app.id = o.order_app_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT f.channel AS channel,
           ROUND(SUM(f.net_sales), 2) AS net_revenue
    FROM filtered_orders f
    GROUP BY f.channel
    ORDER BY SUM(f.net_sales) DESC, f.channel ASC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Net revenue realization after refunds across channels.',
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
    '019fffa2-0f80-70c4-9a28-0385c2cf3627',
    'Refund Rate by Channel',
    'Sales Channel Attribution/Channel Quality & Profitability/PLOT/Refund Rate by Channel',
    '
    WITH filtered_orders AS (
        SELECT o.id,
               COALESCE(ch.name, app.name, o.source_name, ''Unattributed'') AS channel,
               COALESCE(o.subtotal_price, 0) + COALESCE(o.total_discounts_amount, 0) AS gross_sales
        FROM orders o
        LEFT JOIN channel ch ON ch.id = o.channel_id
        LEFT JOIN order_app app ON app.id = o.order_app_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    channel_refunds AS (
        SELECT f.channel,
               SUM(COALESCE(r.total_refunded_amount, 0)) AS refunded
        FROM refund r
        JOIN filtered_orders f ON f.id = r.order_id
        GROUP BY f.channel
    ),
    channel_gross AS (
        SELECT f.channel,
               SUM(f.gross_sales) AS gross_sales
        FROM filtered_orders f
        GROUP BY f.channel
    )
    SELECT cg.channel AS channel,
           ROUND(100 * COALESCE(cr.refunded, 0) / NULLIF(cg.gross_sales, 0), 2) AS refund_rate
    FROM channel_gross cg
    LEFT JOIN channel_refunds cr ON cr.channel IS NOT DISTINCT FROM cg.channel
    ORDER BY 100 * COALESCE(cr.refunded, 0) / NULLIF(cg.gross_sales, 0) DESC NULLS LAST,
             cg.channel ASC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Refund rate percentage comparison per channel.',
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
    '019fffa2-0f80-776e-972e-acecde275b53',
    'Discount Rate by Channel',
    'Sales Channel Attribution/Channel Quality & Profitability/PLOT/Discount Rate by Channel',
    '
    WITH filtered_orders AS (
        SELECT COALESCE(ch.name, app.name, o.source_name, ''Unattributed'') AS channel,
               COALESCE(o.subtotal_price, 0) + COALESCE(o.total_discounts_amount, 0) AS gross_sales,
               COALESCE(o.total_discounts_amount, 0) AS discounts
        FROM orders o
        LEFT JOIN channel ch ON ch.id = o.channel_id
        LEFT JOIN order_app app ON app.id = o.order_app_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT f.channel AS channel,
           ROUND(100 * SUM(f.discounts) / NULLIF(SUM(f.gross_sales), 0), 2) AS discount_rate
    FROM filtered_orders f
    GROUP BY f.channel
    ORDER BY 100 * SUM(f.discounts) / NULLIF(SUM(f.gross_sales), 0) DESC NULLS LAST,
             f.channel ASC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Discount rate percentage comparison per channel.',
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
    '019fffa2-0f80-7da9-bd88-43e4b7c25702',
    'Channel Quality Report',
    'Sales Channel Attribution/Channel Quality & Profitability/TABLE/Channel Quality Report',
    '
    WITH filtered_orders AS (
        SELECT o.id,
               COALESCE(ch.name, app.name, o.source_name, ''Unattributed'') AS channel,
               o.fulfillment_status,
               COALESCE(o.subtotal_price, 0) + COALESCE(o.total_discounts_amount, 0) AS gross_sales,
               COALESCE(o.total_discounts_amount, 0) AS discounts,
               COALESCE(o.total_outstanding_amount, 0) AS outstanding,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM orders o
        LEFT JOIN channel ch ON ch.id = o.channel_id
        LEFT JOIN order_app app ON app.id = o.order_app_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    channel_refunds AS (
        SELECT f.channel,
               SUM(COALESCE(r.total_refunded_amount, 0)) AS refunded
        FROM refund r
        JOIN filtered_orders f ON f.id = r.order_id
        GROUP BY f.channel
    ),
    channel_totals AS (
        SELECT f.channel,
               COUNT(*) AS orders,
               SUM(f.net_sales) AS net_sales,
               SUM(f.gross_sales) AS gross_sales,
               SUM(f.discounts) AS discounts,
               SUM(f.outstanding) AS unpaid_amount,
               COUNT(*) FILTER (
                   WHERE UPPER(f.fulfillment_status) IS DISTINCT FROM ''FULFILLED'') AS fulfillment_pending
        FROM filtered_orders f
        GROUP BY f.channel
    )
    SELECT ct.channel AS channel,
           ct.orders AS orders,
           ROUND(ct.net_sales, 2) AS net_sales,
           ROUND(ct.net_sales / NULLIF(ct.orders, 0), 2) AS aov,
           ROUND(100 * ct.discounts / NULLIF(ct.gross_sales, 0), 2) AS discount_rate,
           ROUND(100 * COALESCE(cr.refunded, 0) / NULLIF(ct.gross_sales, 0), 2) AS refund_rate,
           ROUND(ct.unpaid_amount, 2) AS unpaid_amount,
           ct.fulfillment_pending AS fulfillment_pending,
           COUNT(*) OVER() AS total_records
    FROM channel_totals ct
    LEFT JOIN channel_refunds cr ON cr.channel IS NOT DISTINCT FROM ct.channel
    ORDER BY ct.net_sales DESC, ct.channel ASC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Detailed channel quality report table listing orders, net sales, AOV, discount rate %, refund rate %, unpaid balance, and unfulfilled orders count.',
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
    '019fffa2-0f80-770e-8d37-2f7fa9a51a10',
    'Channel Refund Report',
    'Sales Channel Attribution/Channel Quality & Profitability/TABLE/Channel Refund Report',
    '
    WITH channel_orders AS (
        SELECT o.id,
               COALESCE(ch.name, app.name, o.source_name, ''Unattributed'') AS channel,
               COALESCE(o.subtotal_price, 0) + COALESCE(o.total_discounts_amount, 0) AS gross_sales
        FROM orders o
        LEFT JOIN channel ch ON ch.id = o.channel_id
        LEFT JOIN order_app app ON app.id = o.order_app_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    order_refunds AS (
        SELECT r.order_id,
               SUM(COALESCE(r.total_refunded_amount, 0)) AS refunded
        FROM refund r
        GROUP BY r.order_id
    ),
    channel_refunds AS (
        SELECT co.channel,
               COUNT(*) FILTER (WHERE COALESCE(orf.refunded, 0) > 0) AS refunded_orders,
               SUM(COALESCE(orf.refunded, 0)) AS refunded_amount,
               SUM(co.gross_sales) AS gross_sales
        FROM channel_orders co
        LEFT JOIN order_refunds orf ON orf.order_id = co.id
        GROUP BY co.channel
    ),
    sku_returns AS (
        SELECT co.channel,
               COALESCE(pv.sku, pv.product_variant_gid) AS sku,
               SUM(GREATEST(COALESCE(li.quantity, 0)
                            - COALESCE(li.refundable_quantity, li.quantity), 0)) AS units
        FROM order_line_item li
        JOIN channel_orders co ON co.id = li.order_id
        JOIN product_variant pv ON pv.id = li.product_variant_id
        GROUP BY co.channel, COALESCE(pv.sku, pv.product_variant_gid)
    ),
    ranked_skus AS (
        SELECT channel, sku, units,
               ROW_NUMBER() OVER (PARTITION BY channel ORDER BY units DESC, sku ASC) AS rn
        FROM sku_returns
        WHERE units > 0
    ),
    top_skus AS (
        SELECT channel,
               string_agg(sku || CHR(32) || CHR(40) || units::text || CHR(41),
                          CHR(44) || CHR(32) ORDER BY rn) AS top_refunded_skus
        FROM ranked_skus
        WHERE rn <= 3
        GROUP BY channel
    )
    SELECT cr.channel AS channel,
           cr.refunded_orders AS refunded_orders,
           ROUND(cr.refunded_amount, 2) AS refunded_amount,
           ROUND(100 * cr.refunded_amount / NULLIF(cr.gross_sales, 0), 2) AS refund_rate,
           COALESCE(ts.top_refunded_skus, ''None'') AS top_refunded_skus,
           COUNT(*) OVER() AS total_records
    FROM channel_refunds cr
    LEFT JOIN top_skus ts ON ts.channel IS NOT DISTINCT FROM cr.channel
    ORDER BY cr.refunded_amount DESC, cr.channel ASC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Detailed refund analysis report per channel showing refunded orders count, refunded dollar amount, refund rate %, and top refunded SKUs.',
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

--changeset saugat:RW-46-3
--comment seed Marketing Attribution tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fffa2-0f80-7d69-850d-7e635d094b1d',
    'Marketing Attribution KPIs',
    'Sales Channel Attribution/Marketing Attribution/KPI/Marketing Attribution KPIs',
    '
    WITH
    /*comparison_window_cte*/
    scoped_orders AS (
        SELECT * FROM (
            SELECT ((w.cur_start IS NULL OR o.created_at::date >= w.cur_start)
                AND (w.cur_end   IS NULL OR o.created_at::date <= w.cur_end))  AS is_current,
                   (w.prv_start IS NOT NULL
                AND o.created_at::date BETWEEN w.prv_start AND w.prv_end)      AS is_prior,
                   LOWER(NULLIF(TRIM(o.utm_parameters ->> ''source''), '''')) AS utm_source,
                   LOWER(NULLIF(TRIM(o.utm_parameters ->> ''medium''), '''')) AS utm_medium,
                   NULLIF(TRIM(o.utm_parameters ->> ''campaign''), '''') AS utm_campaign,
                   COALESCE(o.referring_sites #>> ''{0,url}'',
                            o.referring_sites #>> ''{0,domain}'',
                            o.referring_sites #>> ''{0,site}'',
                            CASE WHEN jsonb_typeof(o.referring_sites -> 0) = ''string''
                                 THEN o.referring_sites #>> ''{0}'' END,
                            CASE WHEN jsonb_typeof(o.referring_sites) = ''string''
                                 THEN o.referring_sites #>> ''{}'' END,
                            o.referring_sites ->> ''url'',
                            o.referring_sites ->> ''domain'',
                            o.referring_sites ->> ''site'') AS referring_site,
                   COALESCE(o.current_total_price, 0)
                     - COALESCE(o.current_total_tax, 0)
                     - COALESCE(o.current_shipping_price, 0) AS net_sales
            FROM orders o
            CROSS JOIN windows w
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    classified AS (
        SELECT s.is_current,
               s.is_prior,
               s.net_sales,
               (s.utm_source IS NOT NULL
             OR s.utm_medium IS NOT NULL
             OR s.utm_campaign IS NOT NULL) AS has_utm,
               (s.referring_site IS NOT NULL) AS has_referral,
               CASE WHEN s.utm_medium IN (''cpc'', ''ppc'', ''paid'', ''paidsearch'', ''paid_search'',
                                          ''paid-search'', ''cpm'', ''cpv'', ''display'', ''banner'',
                                          ''retargeting'')                                   THEN 1
                    WHEN s.utm_medium IN (''organic'', ''seo'', ''organic_search'',
                                          ''organic-search'')                                THEN 2
                    WHEN s.utm_medium IN (''referral'', ''referrer'', ''ref'')                THEN 3
                    WHEN s.utm_medium IN (''email'', ''e-mail'', ''newsletter'', ''mail'')     THEN 4
                    WHEN s.utm_medium IN (''social'', ''social_media'', ''social-media'',
                                          ''socialmedia'', ''sm'', ''facebook'', ''instagram'',
                                          ''twitter'', ''tiktok'', ''pinterest'', ''linkedin'') THEN 5
                    ELSE 6 END AS medium_group
        FROM scoped_orders s
    ),
    totals AS (
        SELECT COALESCE(SUM(net_sales) FILTER (WHERE is_current AND has_utm), 0) AS cur_utm_rev,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior   AND has_utm), 0) AS prv_utm_rev,
               COUNT(*) FILTER (WHERE is_current AND has_utm) AS cur_utm_orders,
               COUNT(*) FILTER (WHERE is_prior   AND has_utm) AS prv_utm_orders,
               COALESCE(SUM(net_sales) FILTER (WHERE is_current AND has_referral), 0) AS cur_ref_rev,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior   AND has_referral), 0) AS prv_ref_rev,
               COALESCE(SUM(net_sales) FILTER (WHERE is_current AND medium_group = 1), 0) AS cur_paid_rev,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior   AND medium_group = 1), 0) AS prv_paid_rev,
               COALESCE(SUM(net_sales) FILTER (WHERE is_current), 0) AS cur_total_rev,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior),   0) AS prv_total_rev
        FROM classified
    ),
    computed AS (
        SELECT t.cur_utm_rev, t.prv_utm_rev,
               t.cur_ref_rev, t.prv_ref_rev,
               ROUND(t.cur_utm_rev / NULLIF(t.cur_utm_orders, 0), 2) AS cur_utm_aov,
               ROUND(t.prv_utm_rev / NULLIF(t.prv_utm_orders, 0), 2) AS prv_utm_aov,
               ROUND(100 * t.cur_paid_rev / NULLIF(t.cur_total_rev, 0), 2) AS cur_paid_share,
               ROUND(100 * t.prv_paid_rev / NULLIF(t.prv_total_rev, 0), 2) AS prv_paid_share
        FROM totals t
    )
    SELECT ROUND(c.cur_utm_rev, 2) AS utm_revenue,
           ROUND(100 * (c.cur_utm_rev - c.prv_utm_rev)
                 / NULLIF(ABS(c.prv_utm_rev), 0), 2) AS utm_revenue_divergence,
           c.cur_utm_aov AS utm_aov,
           ROUND(100 * (c.cur_utm_aov - c.prv_utm_aov)
                 / NULLIF(ABS(c.prv_utm_aov), 0), 2) AS utm_aov_divergence,
           ROUND(c.cur_ref_rev, 2) AS referral_revenue,
           ROUND(100 * (c.cur_ref_rev - c.prv_ref_rev)
                 / NULLIF(ABS(c.prv_ref_rev), 0), 2) AS referral_revenue_divergence,
           COALESCE(c.cur_paid_share, 0) AS paid_revenue_share,
           ROUND(100 * (c.cur_paid_share - c.prv_paid_share)
                 / NULLIF(ABS(c.prv_paid_share), 0), 2) AS paid_revenue_share_divergence
    FROM computed c
    ',
    NULL,
    'KPI',
    60,
    'Marketing KPIs tracking UTM-tagged revenue, UTM AOV, referral site revenue, and paid media revenue share % vs prior period.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        { "provider": "COMPARISON_WINDOW_CTE", "condition": "hasFilter:startDate", "placeholder": "/*comparison_window_cte*/",
          "args": { "currentStartParam": "currentStartDate", "currentEndParam": "currentEndDate", "priorStartParam": "priorStartDate", "priorEndParam": "priorEndDate" } }
      ]
    }'
),
(
    '019fffa2-0f80-70ef-9a0f-c359403e905d',
    'UTM Campaign Revenue',
    'Sales Channel Attribution/Marketing Attribution/PLOT/UTM Campaign Revenue',
    '
    WITH filtered_orders AS (
        SELECT NULLIF(TRIM(o.utm_parameters ->> ''campaign''), '''') AS utm_campaign,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM orders o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT f.utm_campaign AS campaign,
           ROUND(SUM(f.net_sales), 2) AS net_sales
    FROM filtered_orders f
    WHERE f.utm_campaign IS NOT NULL
    GROUP BY f.utm_campaign
    ORDER BY SUM(f.net_sales) DESC, f.utm_campaign ASC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Net revenue contribution per marketing campaign name.',
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
    '019fffa2-0f80-71ce-a2f8-1d91eb3cf4e6',
    'UTM Source / Medium Performance',
    'Sales Channel Attribution/Marketing Attribution/PLOT/UTM Source / Medium Performance',
    '
    WITH filtered_orders AS (
        SELECT LOWER(NULLIF(TRIM(o.utm_parameters ->> ''source''), '''')) AS utm_source,
               LOWER(NULLIF(TRIM(o.utm_parameters ->> ''medium''), '''')) AS utm_medium,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM orders o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    labelled AS (
        SELECT COALESCE(f.utm_source, ''unknown'') || CHR(32) || CHR(47) || CHR(32)
                 || COALESCE(f.utm_medium, ''unknown'') AS source_medium,
               f.net_sales
        FROM filtered_orders f
        WHERE f.utm_source IS NOT NULL OR f.utm_medium IS NOT NULL
    )
    SELECT l.source_medium AS source_medium,
           ROUND(SUM(l.net_sales), 2) AS net_sales,
           ROUND(SUM(l.net_sales) / NULLIF(COUNT(*), 0), 2) AS aov,
           COUNT(*) AS orders
    FROM labelled l
    GROUP BY l.source_medium
    ORDER BY SUM(l.net_sales) DESC, l.source_medium ASC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Performance breakdown across combined UTM source / medium pairs evaluating revenue, AOV, and orders.',
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
    '019fffa2-0f80-73f6-a81c-b324e3603939',
    'Referral Site Revenue',
    'Sales Channel Attribution/Marketing Attribution/PLOT/Referral Site Revenue',
    '
    WITH filtered_orders AS (
        SELECT COALESCE(o.referring_sites #>> ''{0,url}'',
                        o.referring_sites #>> ''{0,domain}'',
                        o.referring_sites #>> ''{0,site}'',
                        CASE WHEN jsonb_typeof(o.referring_sites -> 0) = ''string''
                             THEN o.referring_sites #>> ''{0}'' END,
                        CASE WHEN jsonb_typeof(o.referring_sites) = ''string''
                             THEN o.referring_sites #>> ''{}'' END,
                        o.referring_sites ->> ''url'',
                        o.referring_sites ->> ''domain'',
                        o.referring_sites ->> ''site'') AS referring_site,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM orders o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT f.referring_site AS referring_site,
           ROUND(SUM(f.net_sales), 2) AS net_sales
    FROM filtered_orders f
    WHERE f.referring_site IS NOT NULL
    GROUP BY f.referring_site
    ORDER BY SUM(f.net_sales) DESC, f.referring_site ASC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Revenue contribution per referring website URL/domain.',
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
    '019fffa2-0f80-79ee-84eb-b644d7b1d5c4',
    'Paid vs Organic Revenue Mix',
    'Sales Channel Attribution/Marketing Attribution/PLOT/Paid vs Organic Revenue Mix',
    '
    WITH filtered_orders AS (
        SELECT LOWER(NULLIF(TRIM(o.utm_parameters ->> ''medium''), '''')) AS utm_medium,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM orders o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    classified AS (
        SELECT CASE WHEN f.utm_medium IN (''cpc'', ''ppc'', ''paid'', ''paidsearch'', ''paid_search'',
                                          ''paid-search'', ''cpm'', ''cpv'', ''display'', ''banner'',
                                          ''retargeting'')                                   THEN 1
                    WHEN f.utm_medium IN (''organic'', ''seo'', ''organic_search'',
                                          ''organic-search'')                                THEN 2
                    WHEN f.utm_medium IN (''referral'', ''referrer'', ''ref'')                THEN 3
                    WHEN f.utm_medium IN (''email'', ''e-mail'', ''newsletter'', ''mail'')     THEN 4
                    WHEN f.utm_medium IN (''social'', ''social_media'', ''social-media'',
                                          ''socialmedia'', ''sm'', ''facebook'', ''instagram'',
                                          ''twitter'', ''tiktok'', ''pinterest'', ''linkedin'') THEN 5
                    ELSE 6 END AS medium_group,
               f.net_sales
        FROM filtered_orders f
    ),
    totals AS (
        SELECT COALESCE(SUM(net_sales), 0) AS total_net,
               COALESCE(SUM(net_sales) FILTER (WHERE medium_group = 1), 0) AS paid,
               COALESCE(SUM(net_sales) FILTER (WHERE medium_group = 2), 0) AS organic,
               COALESCE(SUM(net_sales) FILTER (WHERE medium_group = 3), 0) AS referral,
               COALESCE(SUM(net_sales) FILTER (WHERE medium_group = 4), 0) AS email,
               COALESCE(SUM(net_sales) FILTER (WHERE medium_group = 5), 0) AS social,
               COALESCE(SUM(net_sales) FILTER (WHERE medium_group = 6), 0) AS direct
        FROM classified
    )
    SELECT ''Revenue Mix'' AS mix,
           COALESCE(ROUND(100 * t.paid     / NULLIF(t.total_net, 0), 2), 0) AS "Paid",
           COALESCE(ROUND(100 * t.organic  / NULLIF(t.total_net, 0), 2), 0) AS "Organic",
           COALESCE(ROUND(100 * t.referral / NULLIF(t.total_net, 0), 2), 0) AS "Referral",
           COALESCE(ROUND(100 * t.email    / NULLIF(t.total_net, 0), 2), 0) AS "Email",
           COALESCE(ROUND(100 * t.social   / NULLIF(t.total_net, 0), 2), 0) AS "Social",
           COALESCE(ROUND(100 * t.direct   / NULLIF(t.total_net, 0), 2), 0) AS "Direct / Unknown"
    FROM totals t
    ',
    NULL,
    'PLOT',
    60,
    'Proportional revenue mix percentage across traffic acquisition mediums (Paid, Organic, Referral, Email, Social, Direct).',
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
    '019fffa2-0f80-7510-8c97-1bd21c12e627',
    'UTM Campaign Report',
    'Sales Channel Attribution/Marketing Attribution/TABLE/UTM Campaign Report',
    '
    WITH filtered_orders AS (
        SELECT o.id,
               LOWER(NULLIF(TRIM(o.utm_parameters ->> ''source''), '''')) AS utm_source,
               LOWER(NULLIF(TRIM(o.utm_parameters ->> ''medium''), '''')) AS utm_medium,
               NULLIF(TRIM(o.utm_parameters ->> ''campaign''), '''') AS utm_campaign,
               COALESCE(o.subtotal_price, 0) + COALESCE(o.total_discounts_amount, 0) AS gross_sales,
               COALESCE(o.total_discounts_amount, 0) AS discounts,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM orders o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    attributed AS (
        SELECT f.id, f.utm_source, f.utm_medium, f.utm_campaign,
               f.gross_sales, f.discounts, f.net_sales
        FROM filtered_orders f
        WHERE f.utm_source IS NOT NULL
           OR f.utm_medium IS NOT NULL
           OR f.utm_campaign IS NOT NULL
    ),
    campaign_totals AS (
        SELECT a.utm_source, a.utm_medium, a.utm_campaign,
               COUNT(*) AS orders,
               SUM(a.gross_sales) AS gross_sales,
               SUM(a.discounts) AS discounts,
               SUM(a.net_sales) AS net_sales
        FROM attributed a
        GROUP BY a.utm_source, a.utm_medium, a.utm_campaign
    ),
    campaign_refunds AS (
        SELECT a.utm_source, a.utm_medium, a.utm_campaign,
               SUM(COALESCE(r.total_refunded_amount, 0)) AS refunded
        FROM refund r
        JOIN attributed a ON a.id = r.order_id
        GROUP BY a.utm_source, a.utm_medium, a.utm_campaign
    )
    SELECT COALESCE(ct.utm_source, ''Unknown'') AS utm_source,
           COALESCE(ct.utm_medium, ''Unknown'') AS utm_medium,
           COALESCE(ct.utm_campaign, ''Unknown'') AS utm_campaign,
           ct.orders AS orders,
           ROUND(ct.net_sales, 2) AS net_sales,
           ROUND(ct.net_sales / NULLIF(ct.orders, 0), 2) AS aov,
           ROUND(100 * COALESCE(cr.refunded, 0) / NULLIF(ct.gross_sales, 0), 2) AS refund_rate,
           ROUND(100 * ct.discounts / NULLIF(ct.gross_sales, 0), 2) AS discount_rate,
           COUNT(*) OVER() AS total_records
    FROM campaign_totals ct
    LEFT JOIN campaign_refunds cr
           ON cr.utm_source   IS NOT DISTINCT FROM ct.utm_source
          AND cr.utm_medium   IS NOT DISTINCT FROM ct.utm_medium
          AND cr.utm_campaign IS NOT DISTINCT FROM ct.utm_campaign
    ORDER BY ct.net_sales DESC, ct.utm_campaign ASC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Detailed performance report table per campaign listing UTM source, medium, campaign name, orders, net sales, AOV, refund %, and discount %.',
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
    '019fffa2-0f80-71e2-b91c-c916a676dd3e',
    'Referral Site Report',
    'Sales Channel Attribution/Marketing Attribution/TABLE/Referral Site Report',
    '
    WITH filtered_orders AS (
        SELECT o.created_at,
               o.customer_id,
               COALESCE(o.referring_sites #>> ''{0,url}'',
                        o.referring_sites #>> ''{0,domain}'',
                        o.referring_sites #>> ''{0,site}'',
                        CASE WHEN jsonb_typeof(o.referring_sites -> 0) = ''string''
                             THEN o.referring_sites #>> ''{0}'' END,
                        CASE WHEN jsonb_typeof(o.referring_sites) = ''string''
                             THEN o.referring_sites #>> ''{}'' END,
                        o.referring_sites ->> ''url'',
                        o.referring_sites ->> ''domain'',
                        o.referring_sites ->> ''site'') AS referring_site,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM orders o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT f.referring_site AS referring_site,
           MIN(f.created_at)::date::text AS first_order,
           MAX(f.created_at)::date::text AS last_order,
           COUNT(*) AS orders,
           ROUND(SUM(f.net_sales), 2) AS net_sales,
           ROUND(SUM(f.net_sales) / NULLIF(COUNT(*), 0), 2) AS aov,
           COUNT(DISTINCT f.customer_id) AS customer_count,
           COUNT(*) OVER() AS total_records
    FROM filtered_orders f
    WHERE f.referring_site IS NOT NULL
    GROUP BY f.referring_site
    ORDER BY SUM(f.net_sales) DESC, f.referring_site ASC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Report table per referring site domain listing first order date, last order date, orders, net sales, AOV, and customer count.',
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

--changeset saugat:RW-46-4
--comment seed Attribution Health tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fffa2-0f80-7305-bd5d-53ae0ca111f1',
    'Orders Without Attribution',
    'Sales Channel Attribution/Attribution Health/KPI/Orders Without Attribution',
    '
    WITH
    /*comparison_window_cte*/
    scoped_orders AS (
        SELECT * FROM (
            SELECT ((w.cur_start IS NULL OR o.created_at::date >= w.cur_start)
                AND (w.cur_end   IS NULL OR o.created_at::date <= w.cur_end))  AS is_current,
                   (w.prv_start IS NOT NULL
                AND o.created_at::date BETWEEN w.prv_start AND w.prv_end)      AS is_prior,
                   (NULLIF(TRIM(o.utm_parameters ->> ''source''), '''') IS NULL
                AND NULLIF(TRIM(o.utm_parameters ->> ''medium''), '''') IS NULL
                AND NULLIF(TRIM(o.utm_parameters ->> ''campaign''), '''') IS NULL) AS missing_utm,
                   (COALESCE(o.referring_sites #>> ''{0,url}'',
                             o.referring_sites #>> ''{0,domain}'',
                             o.referring_sites #>> ''{0,site}'',
                             CASE WHEN jsonb_typeof(o.referring_sites -> 0) = ''string''
                                  THEN o.referring_sites #>> ''{0}'' END,
                             CASE WHEN jsonb_typeof(o.referring_sites) = ''string''
                                  THEN o.referring_sites #>> ''{}'' END,
                             o.referring_sites ->> ''url'',
                             o.referring_sites ->> ''domain'',
                             o.referring_sites ->> ''site'') IS NULL) AS missing_referring_site,
                   (o.channel_id IS NULL
                AND o.order_app_id IS NULL
                AND NULLIF(TRIM(o.source_name), '''') IS NULL) AS missing_channel
            FROM orders o
            CROSS JOIN windows w
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    totals AS (
        SELECT COUNT(*) FILTER (WHERE is_current
                            AND (missing_utm OR missing_referring_site OR missing_channel)) AS cur_gap,
               COUNT(*) FILTER (WHERE is_prior
                            AND (missing_utm OR missing_referring_site OR missing_channel)) AS prv_gap
        FROM scoped_orders
    )
    SELECT t.cur_gap AS orders_without_attribution,
           ROUND(100.0 * (t.cur_gap - t.prv_gap)
                 / NULLIF(ABS(t.prv_gap), 0), 2) AS orders_without_attribution_divergence
    FROM totals t
    ',
    NULL,
    'KPI',
    60,
    'Attribution health KPI tracking count of orders lacking attribution tracking data vs prior period.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        { "provider": "COMPARISON_WINDOW_CTE", "condition": "hasFilter:startDate", "placeholder": "/*comparison_window_cte*/",
          "args": { "currentStartParam": "currentStartDate", "currentEndParam": "currentEndDate", "priorStartParam": "priorStartDate", "priorEndParam": "priorEndDate" } }
      ]
    }'
),
(
    '019fffa2-0f80-7aec-b21a-cf83cf3fd204',
    'Unattributed Orders Trend',
    'Sales Channel Attribution/Attribution Health/PLOT/Unattributed Orders Trend',
    '
    WITH
    /*date_granularity_cte*/
    filtered_orders AS (
        SELECT date_trunc(LOWER(dp.g), o.created_at) AS bucket,
               (NULLIF(TRIM(o.utm_parameters ->> ''source''), '''') IS NULL
            AND NULLIF(TRIM(o.utm_parameters ->> ''medium''), '''') IS NULL
            AND NULLIF(TRIM(o.utm_parameters ->> ''campaign''), '''') IS NULL) AS missing_utm,
               (COALESCE(o.referring_sites #>> ''{0,url}'',
                         o.referring_sites #>> ''{0,domain}'',
                         o.referring_sites #>> ''{0,site}'',
                         CASE WHEN jsonb_typeof(o.referring_sites -> 0) = ''string''
                              THEN o.referring_sites #>> ''{0}'' END,
                         CASE WHEN jsonb_typeof(o.referring_sites) = ''string''
                              THEN o.referring_sites #>> ''{}'' END,
                         o.referring_sites ->> ''url'',
                         o.referring_sites ->> ''domain'',
                         o.referring_sites ->> ''site'') IS NULL) AS missing_referring_site,
               (o.channel_id IS NULL
            AND o.order_app_id IS NULL
            AND NULLIF(TRIM(o.source_name), '''') IS NULL) AS missing_channel
        FROM orders o
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.created_at >= dp.start_bucket
          AND o.created_at <= :currentEndDate::date
    ),
    daily AS (
        SELECT f.bucket, COUNT(*) AS unattributed_orders
        FROM filtered_orders f
        WHERE f.missing_utm OR f.missing_referring_site OR f.missing_channel
        GROUP BY f.bucket
    )
    SELECT to_char(df.bucket,
               CASE WHEN dp.g = ''DAY''   THEN ''Mon DD, YYYY''
                    WHEN dp.g = ''WEEK''  THEN ''Mon DD, YYYY''
                    WHEN dp.g = ''MONTH'' THEN ''Mon YYYY''
                    WHEN dp.g = ''YEAR''  THEN ''YYYY''
               END
           ) AS period,
           df.bucket,
           COALESCE(d.unattributed_orders, 0) AS unattributed_orders
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily d ON d.bucket = df.bucket
    ORDER BY df.bucket ASC
    ',
    NULL,
    'PLOT',
    60,
    'Volume trend of unattributed orders grouped by dynamic date granularity.',
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
    '019fffa2-0f80-77e4-8127-7707ab16f3d5',
    'Attribution Gap Report',
    'Sales Channel Attribution/Attribution Health/TABLE/Attribution Gap Report',
    '
    WITH filtered_orders AS (
        SELECT o.id,
               o.order_gid,
               COALESCE(NULLIF(TRIM(o.source_name), ''''), ''Unknown'') AS source_name,
               COALESCE(ch.name, app.name, o.source_name, ''Unattributed'') AS channel,
               (NULLIF(TRIM(o.utm_parameters ->> ''source''), '''') IS NULL
            AND NULLIF(TRIM(o.utm_parameters ->> ''medium''), '''') IS NULL
            AND NULLIF(TRIM(o.utm_parameters ->> ''campaign''), '''') IS NULL) AS missing_utm,
               (COALESCE(o.referring_sites #>> ''{0,url}'',
                         o.referring_sites #>> ''{0,domain}'',
                         o.referring_sites #>> ''{0,site}'',
                         CASE WHEN jsonb_typeof(o.referring_sites -> 0) = ''string''
                              THEN o.referring_sites #>> ''{0}'' END,
                         CASE WHEN jsonb_typeof(o.referring_sites) = ''string''
                              THEN o.referring_sites #>> ''{}'' END,
                         o.referring_sites ->> ''url'',
                         o.referring_sites ->> ''domain'',
                         o.referring_sites ->> ''site'') IS NULL) AS missing_referring_site,
               (o.channel_id IS NULL
            AND o.order_app_id IS NULL
            AND NULLIF(TRIM(o.source_name), '''') IS NULL) AS missing_channel,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM orders o
        LEFT JOIN channel ch ON ch.id = o.channel_id
        LEFT JOIN order_app app ON app.id = o.order_app_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT f.order_gid AS order_id,
           f.source_name AS source_name,
           f.channel AS channel,
           f.missing_utm AS missing_utm,
           f.missing_referring_site AS missing_referring_site,
           ROUND(f.net_sales, 2) AS order_value,
           COUNT(*) OVER() AS total_records
    FROM filtered_orders f
    WHERE f.missing_utm OR f.missing_referring_site OR f.missing_channel
    ORDER BY f.net_sales DESC, f.id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Audit table listing individual unattributed orders with flags for missing UTM, missing referral site, and net order value.',
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

--changeset saugat:RW-46-5
--comment seed Customer Quality tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fffa2-0f80-7c9f-a6df-cc1624af3cd2',
    'Channel Customer Quality Report',
    'Sales Channel Attribution/Customer Quality/TABLE/Channel Customer Quality Report',
    '
    WITH filtered_orders AS (
        SELECT o.id,
               o.customer_id,
               COALESCE(ch.name, app.name, o.source_name, ''Unattributed'') AS channel,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM orders o
        LEFT JOIN channel ch ON ch.id = o.channel_id
        LEFT JOIN order_app app ON app.id = o.order_app_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.customer_id IS NOT NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    channel_customer AS (
        SELECT f.channel,
               f.customer_id,
               COUNT(*) AS orders_in_window,
               SUM(f.net_sales) AS revenue
        FROM filtered_orders f
        GROUP BY f.channel, f.customer_id
    ),
    channel_customers AS (
        SELECT cc.channel,
               COUNT(*) FILTER (WHERE cc.orders_in_window = 1) AS new_customers,
               COUNT(*) FILTER (WHERE cc.orders_in_window > 1) AS repeat_customers,
               COUNT(*) AS total_customers,
               SUM(cc.revenue) AS customer_revenue
        FROM channel_customer cc
        GROUP BY cc.channel
    ),
    order_refunds AS (
        SELECT r.order_id,
               SUM(COALESCE(r.total_refunded_amount, 0)) AS refunded
        FROM refund r
        GROUP BY r.order_id
    ),
    customer_refunds AS (
        SELECT f.customer_id,
               SUM(COALESCE(orf.refunded, 0)) AS refunded
        FROM filtered_orders f
        LEFT JOIN order_refunds orf ON orf.order_id = f.id
        GROUP BY f.customer_id
    ),
    risk_cut AS (
        SELECT percentile_cont(0.8) WITHIN GROUP (ORDER BY refunded)::numeric AS cut
        FROM customer_refunds
    ),
    risk_customers AS (
        SELECT cr.customer_id
        FROM customer_refunds cr
        CROSS JOIN risk_cut x
        WHERE x.cut IS NOT NULL
          AND cr.refunded > 0
          AND cr.refunded >= x.cut
    ),
    channel_risk AS (
        SELECT cc.channel,
               COUNT(*) AS refund_risk_customers
        FROM channel_customer cc
        JOIN risk_customers rc ON rc.customer_id = cc.customer_id
        GROUP BY cc.channel
    )
    SELECT cch.channel AS channel,
           cch.new_customers AS new_customers,
           cch.repeat_customers AS repeat_customers,
           ROUND(100.0 * cch.repeat_customers
                 / NULLIF(cch.total_customers, 0), 2) AS repeat_rate,
           ROUND(cch.customer_revenue, 2) AS customer_revenue,
           COALESCE(crk.refund_risk_customers, 0) AS refund_risk_customers,
           COUNT(*) OVER() AS total_records
    FROM channel_customers cch
    LEFT JOIN channel_risk crk ON crk.channel IS NOT DISTINCT FROM cch.channel
    ORDER BY cch.customer_revenue DESC, cch.channel ASC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Channel quality scorecard evaluating new customers, repeat customers, repeat rate %, customer revenue, and refund-risk customers count.',
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

--changeset saugat:RW-46-6
--comment seed Operations & Fulfillment tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fffa2-0f80-787c-ab20-d084e6171e29',
    'Channel Operations KPIs',
    'Sales Channel Attribution/Operations & Fulfillment/KPI/Channel Operations KPIs',
    '
    WITH
    /*comparison_window_cte*/
    scoped_orders AS (
        SELECT * FROM (
            SELECT o.id,
                   ((w.cur_start IS NULL OR o.created_at::date >= w.cur_start)
                AND (w.cur_end   IS NULL OR o.created_at::date <= w.cur_end))  AS is_current,
                   (w.prv_start IS NOT NULL
                AND o.created_at::date BETWEEN w.prv_start AND w.prv_end)      AS is_prior,
                   COALESCE(o.current_total_tax, 0) AS tax
            FROM orders o
            CROSS JOIN windows w
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    tax_totals AS (
        SELECT COALESCE(SUM(tax) FILTER (WHERE is_current), 0) AS cur_tax,
               COALESCE(SUM(tax) FILTER (WHERE is_prior),   0) AS prv_tax
        FROM scoped_orders
    ),
    unfulfilled_totals AS (
        SELECT COALESCE(SUM(COALESCE(li.unfulfilled_discounted_total_amount, 0))
                        FILTER (WHERE s.is_current), 0) AS cur_unfulfilled,
               COALESCE(SUM(COALESCE(li.unfulfilled_discounted_total_amount, 0))
                        FILTER (WHERE s.is_prior),   0) AS prv_unfulfilled
        FROM order_line_item li
        JOIN scoped_orders s ON s.id = li.order_id
    )
    SELECT ROUND(t.cur_tax, 2) AS channel_tax_collected,
           ROUND(100 * (t.cur_tax - t.prv_tax)
                 / NULLIF(ABS(t.prv_tax), 0), 2) AS channel_tax_collected_divergence,
           ROUND(u.cur_unfulfilled, 2) AS channel_fulfillment_risk,
           ROUND(100 * (u.cur_unfulfilled - u.prv_unfulfilled)
                 / NULLIF(ABS(u.prv_unfulfilled), 0), 2) AS channel_fulfillment_risk_divergence
    FROM tax_totals t
    CROSS JOIN unfulfilled_totals u
    ',
    NULL,
    'KPI',
    60,
    'Channel operations KPIs tracking total tax collected and unfulfilled dollar risk vs prior period.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        { "provider": "COMPARISON_WINDOW_CTE", "condition": "hasFilter:startDate", "placeholder": "/*comparison_window_cte*/",
          "args": { "currentStartParam": "currentStartDate", "currentEndParam": "currentEndDate", "priorStartParam": "priorStartDate", "priorEndParam": "priorEndDate" } }
      ]
    }'
),
(
    '019fffa2-0f80-763a-b2bb-f4448a711028',
    'Channel Fulfillment Backlog',
    'Sales Channel Attribution/Operations & Fulfillment/PLOT/Channel Fulfillment Backlog',
    '
    WITH filtered_orders AS (
        SELECT o.id,
               COALESCE(ch.name, app.name, o.source_name, ''Unattributed'') AS channel
        FROM orders o
        LEFT JOIN channel ch ON ch.id = o.channel_id
        LEFT JOIN order_app app ON app.id = o.order_app_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    order_unfulfilled AS (
        SELECT li.order_id,
               SUM(COALESCE(li.unfulfilled_discounted_total_amount, 0)) AS unfulfilled_value
        FROM order_line_item li
        JOIN filtered_orders f ON f.id = li.order_id
        GROUP BY li.order_id
    )
    SELECT f.channel AS channel,
           ROUND(SUM(ou.unfulfilled_value), 2) AS unfulfilled_value
    FROM filtered_orders f
    JOIN order_unfulfilled ou ON ou.order_id = f.id
    WHERE ou.unfulfilled_value > 0
    GROUP BY f.channel
    ORDER BY SUM(ou.unfulfilled_value) DESC, f.channel ASC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Unfulfilled order backlog dollar value per channel.',
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
    '019fffa2-0f80-7234-9907-dd1623f04383',
    'Channel Geography Mix',
    'Sales Channel Attribution/Operations & Fulfillment/PLOT/Channel Geography Mix',
    '
    WITH filtered_orders AS (
        SELECT COALESCE(a.country, ''Unknown'') AS country,
               CASE WHEN LOWER(o.source_name) = ''web'' THEN 1
                    WHEN LOWER(o.source_name) = ''pos'' THEN 2
                    WHEN LOWER(o.source_name) IN (''mobile'', ''iphone'', ''android'') THEN 3
                    WHEN LOWER(o.source_name) IN (''social'', ''facebook'', ''instagram'',
                                                  ''pinterest'', ''tiktok'') THEN 4
                    ELSE 5 END AS channel_bucket,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM orders o
        LEFT JOIN sh_address a ON a.id = o.shipping_address_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT f.country AS country,
           ROUND(COALESCE(SUM(f.net_sales) FILTER (WHERE f.channel_bucket = 1), 0), 2) AS "Online Store",
           ROUND(COALESCE(SUM(f.net_sales) FILTER (WHERE f.channel_bucket = 2), 0), 2) AS "Point of Sale",
           ROUND(COALESCE(SUM(f.net_sales) FILTER (WHERE f.channel_bucket = 3), 0), 2) AS "Mobile",
           ROUND(COALESCE(SUM(f.net_sales) FILTER (WHERE f.channel_bucket = 4), 0), 2) AS "Social",
           ROUND(COALESCE(SUM(f.net_sales) FILTER (WHERE f.channel_bucket = 5), 0), 2) AS "Other"
    FROM filtered_orders f
    GROUP BY f.country
    ORDER BY SUM(f.net_sales) DESC, f.country ASC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Revenue breakdown per destination country across sales channel categories.',
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
    '019fffa2-0f80-7abe-96ab-bc331790de2d',
    'Channel Fulfillment Report',
    'Sales Channel Attribution/Operations & Fulfillment/TABLE/Channel Fulfillment Report',
    '
    WITH filtered_orders AS (
        SELECT o.id,
               o.created_at,
               o.fulfillment_status,
               COALESCE(ch.name, app.name, o.source_name, ''Unattributed'') AS channel
        FROM orders o
        LEFT JOIN channel ch ON ch.id = o.channel_id
        LEFT JOIN order_app app ON app.id = o.order_app_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    order_unfulfilled AS (
        SELECT li.order_id,
               SUM(COALESCE(li.unfulfilled_discounted_total_amount, 0)) AS unfulfilled_value
        FROM order_line_item li
        JOIN filtered_orders f ON f.id = li.order_id
        GROUP BY li.order_id
    ),
    backlog AS (
        SELECT f.channel,
               f.fulfillment_status,
               (CURRENT_DATE - f.created_at::date) AS aging_days,
               ou.unfulfilled_value
        FROM filtered_orders f
        JOIN order_unfulfilled ou ON ou.order_id = f.id
        WHERE ou.unfulfilled_value > 0
    )
    SELECT b.channel AS channel,
           COUNT(*) AS unfulfilled_orders,
           ROUND(SUM(b.unfulfilled_value), 2) AS unfulfilled_value,
           COUNT(*) FILTER (
               WHERE UPPER(b.fulfillment_status) = ''UNFULFILLED'') AS fully_unfulfilled,
           COUNT(*) FILTER (
               WHERE UPPER(b.fulfillment_status) = ''PARTIALLY_FULFILLED'') AS partially_fulfilled,
           ROUND(AVG(b.aging_days), 1) AS avg_aging_days,
           MAX(b.aging_days) AS max_aging_days,
           COUNT(*) OVER() AS total_records
    FROM backlog b
    GROUP BY b.channel
    ORDER BY SUM(b.unfulfilled_value) DESC, b.channel ASC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Fulfillment backlog report table per channel showing unfulfilled orders count, unfulfilled value, fully/partially unfulfilled breakdown, and average/max aging days.',
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
