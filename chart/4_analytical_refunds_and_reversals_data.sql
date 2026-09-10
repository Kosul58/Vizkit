--liquibase formatted sql logicalFilePath:20260730001_analytical_refunds_and_reversals_data.sql

--changeset saugat:RW-36-1
--comment seed refund overview tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31b-748a-8425-3bb474a85b65',
    'Refund Trend',
    'Refunds & Reversals/Refund Overview/PLOT/Refund Trend',
    $$
    WITH
    /*date_granularity_cte*/
    scoped_refunds AS (
        SELECT date_trunc(LOWER(dp.g), COALESCE(r.processed_at, r.created_at)) AS bucket,
               COALESCE(r.total_refunded_amount, 0) AS amount
        FROM public.fact_order_refunds r
        JOIN public.fact_order_headers o ON o.id = r.order_id
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.financialstatus != 'VOIDED'
          AND COALESCE(r.processed_at, r.created_at) >= dp.start_bucket
          AND COALESCE(r.processed_at, r.created_at) < dp.end_bucket + dp.step
    ),
    daily_refunds AS (
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
    LEFT JOIN daily_refunds d ON d.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Trend of total refunded dollar value and refund count grouped by dynamic date granularity.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
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
    '019fff82-e31b-74ba-ba74-370b43f625be',
    'Refund Rate Trend',
    'Refunds & Reversals/Refund Overview/PLOT/Refund Rate Trend',
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
          AND o.created_at < dp.end_bucket + dp.step
    ),
    scoped_refunds AS (
        SELECT date_trunc(LOWER(dp.g), COALESCE(r.processed_at, r.created_at)) AS bucket,
               COALESCE(r.total_refunded_amount, 0) AS amount
        FROM public.fact_order_refunds r
        JOIN public.fact_order_headers o ON o.id = r.order_id
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND COALESCE(r.processed_at, r.created_at) >= dp.start_bucket
          AND COALESCE(r.processed_at, r.created_at) < dp.end_bucket + dp.step
    ),
    daily_gross AS (
        SELECT f.bucket,
               SUM(COALESCE(li.original_total_amount, li.original_unit_price * li.quantity, 0)) AS gross_sales
        FROM public.fact_order_line_items li
        JOIN filtered_orders f ON f.id = li.order_id
        GROUP BY f.bucket
    ),
    daily_refunds AS (
        SELECT s.bucket, SUM(s.amount) AS refunded_amount
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
           COALESCE(ROUND(100 * COALESCE(dr.refunded_amount, 0) / NULLIF(dg.gross_sales, 0), 2), 0) AS refund_rate
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily_gross dg ON dg.bucket = df.bucket
    LEFT JOIN daily_refunds dr ON dr.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Refund percentage rate relative to gross sales grouped by dynamic date granularity.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
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
    '019fff82-e31b-79f4-9202-7fba04cbf8de',
    'Refunds vs Sales',
    'Refunds & Reversals/Refund Overview/PLOT/Refunds vs Sales',
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
          AND o.financialstatus != 'VOIDED'
          AND o.created_at >= dp.start_bucket
          AND o.created_at < dp.end_bucket + dp.step
    ),
    scoped_refunds AS (
        SELECT date_trunc(LOWER(dp.g), COALESCE(r.processed_at, r.created_at)) AS bucket,
               COALESCE(r.total_refunded_amount, 0) AS amount
        FROM public.fact_order_refunds r
        JOIN public.fact_order_headers o ON o.id = r.order_id
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND COALESCE(r.processed_at, r.created_at) >= dp.start_bucket
          AND COALESCE(r.processed_at, r.created_at) < dp.end_bucket + dp.step
    ),
    daily_net AS (
        SELECT f.bucket, SUM(f.net_sales) AS net_sales
        FROM filtered_orders f
        GROUP BY f.bucket
    ),
    daily_refunds AS (
        SELECT s.bucket, SUM(s.amount) AS refunded_amount
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
           ROUND(COALESCE(n.net_sales, 0), 2) AS net_sales,
           ROUND(COALESCE(r.refunded_amount, 0), 2) AS refunded_amount
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily_net n ON n.bucket = df.bucket
    LEFT JOIN daily_refunds r ON r.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Comparison trend of net sales vs total refunded amount grouped by dynamic date granularity.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
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
    '019fff82-e31b-75ee-96c8-10a77eeb0a92',
    'Refunded Orders Report',
    'Refunds & Reversals/Refund Overview/TABLE/Refunded Orders Report',
    $$
    WITH scoped_refunds AS (
        SELECT r.order_id,
               COALESCE(r.total_refunded_amount, 0) AS amount
        FROM public.fact_order_refunds r
        JOIN public.fact_order_headers o ON o.id = r.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.financialstatus != 'VOIDED'
          AND (:currentStartDate IS NULL OR COALESCE(r.processed_at, r.created_at)::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR COALESCE(r.processed_at, r.created_at)::date <= :currentEndDate::date)
    ),
    refunded_orders AS (
        SELECT s.order_id, SUM(s.amount) AS refunded_amount
        FROM scoped_refunds s
        GROUP BY s.order_id
    ),
    order_gross AS (
        SELECT li.order_id,
               SUM(COALESCE(li.original_total_amount, li.original_unit_price * li.quantity, 0)) AS gross_sales
        FROM public.fact_order_line_items li
        JOIN refunded_orders ro ON ro.order_id = li.order_id
        GROUP BY li.order_id
    )
    SELECT o.id AS order_id,
           o.created_at::date::text AS order_date,
           o.financialStatus AS financial_status,
           ROUND(COALESCE(g.gross_sales, 0), 2) AS gross_sales,
           ROUND(COALESCE(o.current_total_price, 0)
                   - COALESCE(o.current_total_tax, 0)
                   - COALESCE(o.current_shipping_price, 0), 2) AS net_sales,
           ROUND(ro.refunded_amount, 2) AS refunded_amount,
           ROUND(100 * ro.refunded_amount / NULLIF(g.gross_sales, 0), 2) AS refund_rate,
           COALESCE(o.attribution_displayname,o.source_name, 'unknown') AS channel,
           COUNT(*) OVER() AS total_records
    FROM refunded_orders ro
    JOIN public.fact_order_headers o ON o.id = ro.order_id
    LEFT JOIN order_gross g ON g.order_id = ro.order_id
    ORDER BY refunded_amount DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'TABLE',
    60,
    'Detailed tabular audit report of individual refunded orders.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
);

--changeset saugat:RW-36-2
--comment seed Revenue Impact and Financial Reconciliation tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31b-78d0-9da5-5953fef1cb38',
    'Refunded Shipping Trend',
    'Refunds & Reversals/Revenue Impact/PLOT/Refunded Shipping Trend',
    $$
    WITH
    /*date_granularity_cte*/
    filtered_orders AS (
        SELECT date_trunc(LOWER(dp.g), o.created_at) AS bucket,
               COALESCE(o.total_refunded_shipping_amount, 0) AS refunded_shipping
        FROM public.fact_order_headers o
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.created_at >= dp.start_bucket
          AND o.created_at <= dp.end_bucket
    ),
    daily_shipping AS (
        SELECT f.bucket, SUM(f.refunded_shipping) AS refunded_shipping
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
           ROUND(COALESCE(d.refunded_shipping, 0), 2) AS refunded_shipping
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily_shipping d ON d.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Trend of refunded shipping amounts grouped by dynamic date granularity.',
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
    '019fff82-e31b-7dbf-9fe8-864fac6fd708',
    'Refund Transaction Reconciliation',
    'Refunds & Reversals/Revenue Impact/PLOT/Refund Transaction Reconciliation',
    $$
    WITH refund_records AS (
        SELECT COALESCE(SUM(COALESCE(r.total_refunded_amount, 0)), 0) AS amount
        FROM public.fact_order_refunds r
        JOIN public.fact_order_headers o ON o.id = r.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR COALESCE(r.processed_at, r.created_at)::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR COALESCE(r.processed_at, r.created_at)::date <= :currentEndDate::date)
    ),
    refund_txns AS (
        SELECT COALESCE(SUM(COALESCE(t.amount, 0)), 0) AS amount
        FROM public.fact_order_transactions t
        JOIN public.fact_order_headers o ON o.id = t.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND t.test = FALSE
          AND t.kind = 'REFUND'
          AND t.status = 'SUCCESS'
          AND (:currentStartDate IS NULL OR t.processed_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR t.processed_at::date <= :currentEndDate::date)
    )
    SELECT v.source AS source,
           v.amount AS amount
    FROM refund_records rr
    CROSS JOIN refund_txns tt
    CROSS JOIN LATERAL (VALUES
        ('Refund Records',      ROUND(rr.amount, 2),             1),
        ('Refund Transactions', ROUND(tt.amount, 2),             2),
        ('Difference',          ROUND(rr.amount - tt.amount, 2), 3)
    ) AS v(source, amount, ord)
    ORDER BY v.ord
    $$,
    NULL,
    'PLOT',
    60,
    'Reconciliation chart comparing refund records vs processed gateway refund transactions.',
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
    '019fff82-e31b-7fdf-83ea-fda8faadf542',
    'Refund Transaction Reconciliation Report',
    'Refunds & Reversals/Revenue Impact/TABLE/Refund Transaction Reconciliation Report',
    $$
    WITH refund_records AS (
        SELECT
            r.order_id,
            string_agg(
                r.id::text,
                CHR(44) || CHR(32)
                ORDER BY r.id
            ) AS refund_id,
            SUM(COALESCE(r.total_refunded_amount, 0)) AS refund_amount
        FROM public.fact_order_refunds r
        JOIN public.fact_order_headers o
            ON o.id = r.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (
              :currentStartDate IS NULL
              OR COALESCE(r.processed_at, r.created_at)::date >= :currentStartDate::date
          )
          AND (
              :currentEndDate IS NULL
              OR COALESCE(r.processed_at, r.created_at)::date <= :currentEndDate::date
          )
        GROUP BY r.order_id
    ),

    refund_txns AS (
        SELECT
            t.order_id,
            string_agg(
                DISTINCT t.gateway,
                CHR(44) || CHR(32)
            ) AS gateway,
            SUM(COALESCE(t.amount, 0)) AS transaction_amount
        FROM public.fact_order_transactions t
        JOIN public.fact_order_headers o
            ON o.id = t.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND t.test = FALSE
          AND t.kind = 'REFUND'
          AND t.status = 'SUCCESS'
          AND (
              :currentStartDate IS NULL
              OR t.processed_at::date >= :currentStartDate::date
          )
          AND (
              :currentEndDate IS NULL
              OR t.processed_at::date <= :currentEndDate::date
          )
        GROUP BY t.order_id
    )

    SELECT
        COALESCE(rr.refund_id, o.id::text) AS refund_id,
        o.id AS order_id,
        ROUND(COALESCE(rr.refund_amount, 0), 2) AS refund_amount,
        ROUND(COALESCE(tt.transaction_amount, 0), 2) AS transaction_amount,
        COALESCE(tt.gateway, o.source_name) AS gateway,
        ROUND(
            COALESCE(rr.refund_amount, 0)
            - COALESCE(tt.transaction_amount, 0),
            2
        ) AS difference,
        COUNT(*) OVER() AS total_records
    FROM refund_records rr
    FULL JOIN refund_txns tt
        ON tt.order_id = rr.order_id
    JOIN public.fact_order_headers o
        ON o.id = COALESCE(rr.order_id, tt.order_id)
    WHERE COALESCE(rr.refund_amount, 0) > 0
    ORDER BY
        ABS(
            COALESCE(rr.refund_amount, 0)
            - COALESCE(tt.transaction_amount, 0)
        ) DESC,
        COALESCE(rr.refund_amount, 0) DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'TABLE',
    30,
    'Granular reconciliation report matching refund entities against gateway transactions per order.',
    '{
      "filterMappings": {
        "shopId": {
          "source": "AUTH_CONTEXT",
          "contextKey": "shopGid"
        },
        "limit": {
          "source": "REQUEST_FILTER",
          "filterKey": "limit"
        },
        "offset": {
          "source": "REQUEST_FILTER",
          "filterKey": "offset"
        },
        "currentStartDate": {
          "source": "REQUEST_FILTER",
          "filterKey": "startDate"
        },
        "currentEndDate": {
          "source": "REQUEST_FILTER",
          "filterKey": "endDate"
        }
      },
      "excludeExtraParams": true
    }'
),
    (
    '019fff82-e31b-7b00-ac1b-c9fc8f9cd155',
    'Refund Shipping Report',
    'Refunds & Reversals/Revenue Impact/TABLE/Refund Shipping Report',
    $$
    WITH scoped_refunds AS (
        SELECT DISTINCT
            r.order_id
        FROM public.fact_order_refunds r
        JOIN public.fact_order_headers o
            ON o.id = r.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (
              :currentStartDate IS NULL
              OR COALESCE(r.processed_at, r.created_at)::date
                 >= :currentStartDate::date
          )
          AND (
              :currentEndDate IS NULL
              OR COALESCE(r.processed_at, r.created_at)::date
                 <= :currentEndDate::date
          )
    )
    SELECT
        o.id AS order_id,
        ROUND(
            COALESCE(o.total_shipping_price, 0),
            2
        ) AS shipping_paid,
        ROUND(
            COALESCE(o.total_refunded_shipping_amount, 0),
            2
        ) AS refunded_shipping,
        COALESCE(
            o.attribution_displayname,
            o.source_name,
            'unknown'
        ) AS channel,
        CONCAT_WS(
            CHR(44) || CHR(32),
            o.shipping_address #>> '{city}',
            o.shipping_address #>> '{province}',
            o.shipping_address #>> '{country}'
        ) AS customer_location,
        COUNT(*) OVER() AS total_records
    FROM scoped_refunds s
    JOIN public.fact_order_headers o
        ON o.id = s.order_id
    WHERE COALESCE(o.total_refunded_shipping_amount, 0) > 0
    ORDER BY
        refunded_shipping DESC,
        shipping_paid DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'TABLE',
    30,
    'Audit table comparing paid shipping vs refunded shipping per order.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
    '019fff82-e31b-713f-b4fc-231044934ca5',
    'Partial vs Full Refund Report',
    'Refunds & Reversals/Revenue Impact/TABLE/Partial vs Full Refund Report',
    $$
    WITH refunded_orders AS (
        SELECT r.order_id,
               SUM(COALESCE(r.total_refunded_amount, 0)) AS refunded_amount
        FROM public.fact_order_refunds r
        JOIN public.fact_order_headers o ON o.id = r.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (:currentStartDate IS NULL OR COALESCE(r.processed_at, r.created_at)::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR COALESCE(r.processed_at, r.created_at)::date <= :currentEndDate::date)
        GROUP BY r.order_id
        HAVING SUM(COALESCE(r.total_refunded_amount, 0)) > 0
    )
    SELECT o.id AS order_id,
           o.financialStatus AS financial_status,
           ROUND(COALESCE(o.total_price, 0), 2) AS total_price,
           ROUND(COALESCE(o.current_total_price, 0), 2) AS current_total_price,
           ROUND(ro.refunded_amount, 2) AS refunded_amount,
           ROUND(COALESCE(o.total_price, 0) - ro.refunded_amount, 2) AS remaining_value,
           COUNT(*) OVER() AS total_records
    FROM refunded_orders ro
    JOIN public.fact_order_headers o ON o.id = ro.order_id
    ORDER BY refunded_amount DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'TABLE',
    60,
    'Detailed report classifying partial vs full order refunds and remaining un-refunded order values.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
);

--changeset saugat:RW-36-3
--comment seed order refund analysis tab
INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31b-7f26-b6d9-e5be106a2e02',
    'Refunds by Financial Status',
    'Refunds & Reversals/Order Refund Analysis/PLOT/Refunds by Financial Status',
    '
    WITH filtered_orders AS (
        SELECT o.id,
               o.financialstatus AS financial_status,
               COALESCE(o.total_price, 0) AS total_price
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    order_refunds AS (
        SELECT r.order_id,
               SUM(COALESCE(r.total_refunded_amount, 0)) AS refunded
        FROM public.fact_order_refunds r
        JOIN filtered_orders f ON f.id = r.order_id
        GROUP BY r.order_id
    )
    SELECT f.financial_status AS financial_status,
           ROUND(SUM(orf.refunded), 2) AS refunded_value,
           ROUND(GREATEST(SUM(f.total_price) - SUM(orf.refunded), 0), 2) AS retained_value
    FROM filtered_orders f
    JOIN order_refunds orf ON orf.order_id = f.id
    GROUP BY f.financial_status
    ORDER BY refunded_value DESC
    ',
    NULL,
    'PLOT',
    60,
    'Distribution of refunded vs retained value grouped by order financial status.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate": { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
    '019fff82-e31b-72dd-a2be-2d371f692040',
    'Refund Severity Distribution',
    'Refunds & Reversals/Order Refund Analysis/PLOT/Refund Severity Distribution',
    $$
    WITH scoped_refunds AS (
        SELECT COALESCE(r.total_refunded_amount, 0) AS amount
        FROM public.fact_order_refunds r
        JOIN public.fact_order_headers o ON o.id = r.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.financialstatus != 'VOIDED'
          AND (:currentStartDate IS NULL OR COALESCE(r.processed_at, r.created_at)::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR COALESCE(r.processed_at, r.created_at)::date <= :currentEndDate::date)
    ),
    bucket_defs(ord, lo, hi) AS (
        VALUES (1, 0, 50), (2, 50, 100), (3, 100, 250), (4, 250, 500),
               (5, 500, 1000), (6, 1000, 2500), (7, 2500, NULL::int)
    )
    SELECT CASE WHEN b.hi IS NULL THEN b.lo::text || CHR(43)
                ELSE b.lo::text || CHR(45) || b.hi::text END AS refund_bucket,
           COUNT(s.amount) AS refund_count
    FROM bucket_defs b
    LEFT JOIN scoped_refunds s ON s.amount >= b.lo AND (b.hi IS NULL OR s.amount < b.hi)
    GROUP BY b.ord, b.lo, b.hi
    ORDER BY b.ord
    $$,
    NULL,
    'PLOT',
    60,
    'Frequency distribution of refund dollar sizes grouped into severity buckets.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
);

--changeset saugat:RW-36-4
--comment seed product refund analysis tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31b-7510-b989-6f45dce0489f',
    'Top Refunded Products / SKUs',
    'Refunds & Reversals/Product Refund Analysis/PLOT/Top Refunded Products / SKUs',
    $$
    WITH filtered_lines AS (
        SELECT li.product_variant_id,
               li.quantity - COALESCE(li.current_quantity, li.quantity) AS removed_units
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT COALESCE(pv.sku, pv.id) AS sku,
           SUM(f.removed_units) AS refund_removed_quantity
    FROM filtered_lines f
    JOIN public.dim_product_variants pv ON pv.id = f.product_variant_id
    GROUP BY COALESCE(pv.sku, pv.id)
    HAVING SUM(f.removed_units) > 0
    ORDER BY refund_removed_quantity DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'PLOT',
    60,
    'Top SKUs ranked by refund removed item quantity.',
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
    '019fff82-e31b-7f43-a957-21278090eb7f',
    'Top Refunded Products Report',
    'Refunds & Reversals/Product Refund Analysis/TABLE/Top Refunded Products Report',
    $$
    WITH filtered_lines AS (
        SELECT li.product_variant_id,
               li.quantity AS ordered_units,
               COALESCE(li.current_quantity, li.quantity) AS current_units,
               li.quantity - COALESCE(li.current_quantity, li.quantity) AS removed_units,
               COALESCE(li.refundable_quantity, 0) AS refundable_units
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT p.id AS product_id,
            p.title AS product,
           pv.sku AS sku,
           SUM(f.ordered_units) AS ordered_quantity,
           SUM(f.current_units) AS current_quantity,
           SUM(f.removed_units) AS refund_removed_quantity,
           SUM(f.refundable_units) AS refund_exposure,
           COUNT(*) OVER() AS total_records
    FROM filtered_lines f
    JOIN public.dim_product_variants pv ON pv.id = f.product_variant_id
    LEFT JOIN public.dim_products p ON p.id = pv.product_id
    GROUP BY p.id, p.title, pv.sku
    HAVING SUM(f.removed_units) > 0
    ORDER BY refund_removed_quantity DESC, sku
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'TABLE',
    30,
    'Detailed tabular breakdown per product evaluating ordered vs current vs removed and refundable item quantities.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
);

--changeset saugat:RW-36-5
--comment seed channel customer and geography analysis tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31b-7cc9-b447-68099ff903d1',
    'Refunds by Channel',
    'Refunds & Reversals/Channel Customer & Geography/PLOT/Refunds by Channel',
    $$
    WITH filtered_orders AS (
        SELECT o.id, COALESCE(o.attribution_displayname,o.source_name, 'unknown') AS channel
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    order_refunds AS (
        SELECT r.order_id, SUM(COALESCE(r.total_refunded_amount, 0)) AS refunded
        FROM public.fact_order_refunds r
        JOIN filtered_orders f ON f.id = r.order_id
        GROUP BY r.order_id
    ),
    order_gross AS (
        SELECT li.order_id,
               SUM(COALESCE(li.original_total_amount, li.original_unit_price * li.quantity, 0)) AS gross
        FROM public.fact_order_line_items li
        JOIN filtered_orders f ON f.id = li.order_id
        GROUP BY li.order_id
    )
    SELECT f.channel AS channel,
           ROUND(COALESCE(SUM(orf.refunded), 0), 2) AS refunded_amount,
           COALESCE(ROUND(100 * COALESCE(SUM(orf.refunded), 0) / NULLIF(SUM(og.gross), 0), 2), 0) AS refund_rate
    FROM filtered_orders f
    LEFT JOIN order_refunds orf ON orf.order_id = f.id
    LEFT JOIN order_gross og ON og.order_id = f.id
    GROUP BY f.channel
    ORDER BY refunded_amount DESC
    $$,
    NULL,
    'PLOT',
    60,
    'Refund dollar amount and refund % rate breakdown grouped by sales channel.',
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
    '019fff82-e31b-71ac-8d79-6ab5ac8211ba',
    'Refunds by Customer Segment',
    'Refunds & Reversals/Channel Customer & Geography/PLOT/Refunds by Customer Segment',
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
          AND o.financialstatus != 'VOIDED'
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    order_refunds AS (
        SELECT r.order_id, COUNT(*) AS refunds
        FROM public.fact_order_refunds r
        JOIN filtered_orders f ON f.id = r.order_id
        GROUP BY r.order_id
    ),
    segments(ord, segment) AS (
        VALUES (1, 'New'), (2, 'Repeat')
    )
    SELECT s.segment AS segment,
           COALESCE(SUM(orf.refunds), 0) AS refund_count,
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
    'Refund count and refund rate % breakdown between New and Repeat customer segments.',
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
    '019fff82-e31b-78da-a0cf-ee6e0c231283',
    'Refunds by Geography',
    'Refunds & Reversals/Channel Customer & Geography/PLOT/Refunds by Geography',
    '
    WITH filtered_orders AS (
        SELECT
            o.id,
            COALESCE(
                o.shipping_address #>> ''{country}'',
                o.shipping_address #>> ''{province}'',
                o.shipping_address #>> ''{city}''
            ) AS country
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (
              :currentStartDate IS NULL
              OR o.created_at::date >= :currentStartDate::date
          )
          AND (
              :currentEndDate IS NULL
              OR o.created_at::date <= :currentEndDate::date
          )
    ),
    order_refunds AS (
        SELECT
            r.order_id,
            SUM(COALESCE(r.total_refunded_amount, 0)) AS refunded
        FROM public.fact_order_refunds r
        JOIN filtered_orders f
            ON f.id = r.order_id
        GROUP BY r.order_id
    ),
    order_gross AS (
        SELECT
            li.order_id,
            SUM(
                COALESCE(
                    li.original_total_amount,
                    li.original_unit_price * li.quantity,
                    0
                )
            ) AS gross
        FROM public.fact_order_line_items li
        JOIN filtered_orders f
            ON f.id = li.order_id
        GROUP BY li.order_id
    )
    SELECT
        f.country AS country,
        ROUND(
            COALESCE(SUM(orf.refunded), 0),
            2
        ) AS refunded_amount,
        COALESCE(
            ROUND(
                100 * COALESCE(SUM(orf.refunded), 0)
                / NULLIF(SUM(og.gross), 0),
                2
            ),
            0
        ) AS refund_rate
    FROM filtered_orders f
    LEFT JOIN order_refunds orf
        ON orf.order_id = f.id
    LEFT JOIN order_gross og
        ON og.order_id = f.id
    WHERE f.country IS NOT NULL
    GROUP BY f.country
    ORDER BY refunded_amount DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Geographic breakdown of total refunded amounts and refund rate % per region.',
    '{
        "filterMappings": {
            "shopId": {
                "source": "AUTH_CONTEXT",
                "contextKey": "shopGid"
            },
            "userId": {
                "source": "AUTH_CONTEXT",
                "contextKey": "user_id"
            },
            "limit": {
                "source": "REQUEST_FILTER",
                "filterKey": "limit"
            },
            "offset": {
                "source": "REQUEST_FILTER",
                "filterKey": "offset"
            },
            "currentStartDate": {
                "source": "REQUEST_FILTER",
                "filterKey": "startDate"
            },
            "currentEndDate": {
                "source": "REQUEST_FILTER",
                "filterKey": "endDate"
            }
        },
        "excludeExtraParams": true
    }'
),
    (
    '019fff82-e31b-71db-8c0a-0fa0605c12d0',
    'Refunds by Payment Gateway',
    'Refunds & Reversals/Channel Customer & Geography/PLOT/Refunds by Payment Gateway',
    $$
    SELECT
    COALESCE(t.gateway, 'Unknown') AS gateway,
    ROUND(SUM(COALESCE(t.amount, 0)), 2) AS refund_transaction_amount
FROM public.fact_order_transactions t
JOIN public.fact_order_headers o
    ON o.id = t.order_id
WHERE o.seller_id = :shopId
  AND o.test = FALSE
  
  AND t.test = FALSE
  AND t.kind = 'REFUND'
  AND t.status = 'SUCCESS'
  AND (
      :currentStartDate IS NULL
      OR t.processed_at::date >= :currentStartDate::date
  )
  AND (
      :currentEndDate IS NULL
      OR t.processed_at::date <= :currentEndDate::date
  )
GROUP BY COALESCE(t.gateway, 'Unknown')
ORDER BY refund_transaction_amount DESC
LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0);
    $$,
    NULL,
    'PLOT',
    60,
    'Distribution of total refunded transaction values grouped by payment gateway.',
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
    '019fff82-e31b-7458-8319-42a3cd185f85',
    'Channel Refund Report',
    'Refunds & Reversals/Channel Customer & Geography/TABLE/Channel Refund Report',
    $$
    WITH filtered_orders AS (
        SELECT o.id,
               COALESCE(o.attribution_displayname,o.source_name, 'unknown') AS channel,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    order_refunds AS (
        SELECT r.order_id, SUM(COALESCE(r.total_refunded_amount, 0)) AS refunded
        FROM public.fact_order_refunds r
        JOIN filtered_orders f ON f.id = r.order_id
        WHERE r.total_refunded_amount > 0
        GROUP BY r.order_id
    ),
    order_gross AS (
        SELECT li.order_id,
               SUM(COALESCE(li.original_total_amount, li.original_unit_price * li.quantity, 0)) AS gross
        FROM public.fact_order_line_items li
        JOIN filtered_orders f ON f.id = li.order_id
        GROUP BY li.order_id
    )
    SELECT f.channel AS channel,
           COUNT(f.id) AS orders,
           ROUND(SUM(f.net_sales), 2) AS net_sales,
           COUNT(orf.order_id) AS refunded_orders,
           ROUND(COALESCE(SUM(orf.refunded), 0), 2) AS refunded_amount,
           COALESCE(ROUND(100 * COALESCE(SUM(orf.refunded), 0) / NULLIF(SUM(og.gross), 0), 2), 0) AS refund_rate,
           COUNT(*) OVER() AS total_records
    FROM filtered_orders f
    LEFT JOIN order_refunds orf ON orf.order_id = f.id
    LEFT JOIN order_gross og ON og.order_id = f.id
    GROUP BY f.channel
    ORDER BY refunded_amount DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'TABLE',
    60,
    'Comparative scorecard table per sales channel evaluating orders, net sales, refunded orders, and refund rate %.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
    '019fff82-e31b-7846-9d18-045c5f46bef8',
    'Customer Refund Risk Report',
    'Refunds & Reversals/Channel Customer & Geography/TABLE/Customer Refund Risk Report',
    $$
    WITH filtered_orders AS (
        SELECT o.id, o.customer_id
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    order_refunds AS (
        SELECT r.order_id,
               COUNT(*) AS refunds,
               SUM(COALESCE(r.total_refunded_amount, 0)) AS refunded
        FROM public.fact_order_refunds r
        JOIN filtered_orders f ON f.id = r.order_id
        WHERE r.total_refunded_amount > 0
        GROUP BY r.order_id
    ),
    order_gross AS (
        SELECT li.order_id,
               SUM(COALESCE(li.original_total_amount, li.original_unit_price * li.quantity, 0)) AS gross
        FROM public.fact_order_line_items li
        JOIN filtered_orders f ON f.id = li.order_id
        GROUP BY li.order_id
    ),
    per_customer AS (
        SELECT f.customer_id,
               COUNT(f.id) AS orders,
               COALESCE(SUM(orf.refunds), 0) AS refund_count,
               COALESCE(SUM(orf.refunded), 0) AS refunded_amount,
               SUM(og.gross) AS gross
        FROM filtered_orders f
        LEFT JOIN order_refunds orf ON orf.order_id = f.id
        LEFT JOIN order_gross og ON og.order_id = f.id
        GROUP BY f.customer_id
    )
    SELECT COALESCE(NULLIF(TRIM(CONCAT_WS(' ', cu.first_name, cu.last_name)), ''),
                    cu.email,
                    cu.id) AS customer,
           cu.number_of_orders AS orders,
           ROUND(COALESCE(cu.amount_spent, 0), 2) AS amount_spent,
           pc.refund_count AS refund_count,
           ROUND(pc.refunded_amount, 2) AS refunded_amount,
           COALESCE(ROUND(100 * pc.refunded_amount / NULLIF(pc.gross, 0), 2), 0) AS refund_rate,
           COUNT(*) OVER() AS total_records
    FROM per_customer pc
    JOIN public.dim_customers cu ON cu.id = pc.customer_id
    WHERE pc.refund_count > 0
    ORDER BY refunded_amount DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'TABLE',
    30,
    'Customer-level refund risk scorecard flagging high refund frequency and high refund value accounts.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
);

--changeset saugat:RW-36-6
--comment seed staff and audit controls tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31d-7e78-99f7-d8efbb717b07',
    'Refund Note Keyword Analysis',
    'Refunds & Reversals/Staff & Audit Controls/TABLE/Refund Note Keyword Analysis',
    $$
    WITH scoped_refunds AS (
        SELECT r.id,
               COALESCE(r.total_refunded_amount, 0) AS amount,
               r.note
        FROM public.fact_order_refunds r
        JOIN public.fact_order_headers o ON o.id = r.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND r.total_refunded_amount > 0
          AND r.note IS NOT NULL
          AND (:currentStartDate IS NULL OR COALESCE(r.processed_at, r.created_at)::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR COALESCE(r.processed_at, r.created_at)::date <= :currentEndDate::date)
    ),
    tokens AS (
        SELECT DISTINCT s.id AS refund_id,
               s.amount,
               l.lexeme AS keyword
        FROM scoped_refunds s,
             LATERAL unnest(to_tsvector('english', COALESCE(s.note, ''))) AS l
    )
    SELECT t.keyword AS keyword,
           COUNT(*) AS refund_count,
           ROUND(SUM(t.amount), 2) AS refunded_amount,
           COUNT(*) OVER() AS total_records
    FROM tokens t
    GROUP BY t.keyword
    ORDER BY refund_count DESC, refunded_amount DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'TABLE',
    30,
    'Audit text analysis ranking recurring keywords found in refund notes.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
    '019fff82-e31d-78ee-b15c-582a98b59a1f',
    'Refund Detail Report',
    'Refunds & Reversals/Staff & Audit Controls/TABLE/Refund Detail Report',
    $$
    SELECT r.id AS refund_id,
           o.id AS order_id,
           COALESCE(NULLIF(TRIM(CONCAT_WS(' ', cu.first_name, cu.last_name)), ''),
                    cu.email,
                    cu.id) AS customer,
           ROUND(COALESCE(r.total_refunded_amount, 0), 2) AS refunded_amount,
           r.note AS note,
           COALESCE(r.processed_at, r.created_at)::date AS processed_date,
           COUNT(*) OVER() AS total_records
    FROM public.fact_order_refunds r
    JOIN public.fact_order_headers o ON o.id = r.order_id
    LEFT JOIN public.dim_customers cu ON cu.id = o.customer_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND r.total_refunded_amount > 0
      AND (:currentStartDate IS NULL OR COALESCE(r.processed_at, r.created_at)::date >= :currentStartDate::date)
      AND (:currentEndDate IS NULL OR COALESCE(r.processed_at, r.created_at)::date <= :currentEndDate::date)
    ORDER BY refunded_amount DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'TABLE',
    30,
    'Detailed audit log listing individual refund transactions, notes, and customer info.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
    '019fff82-e31d-71d9-8086-eb0e7405032c',
    'Refund Notes Report',
    'Refunds & Reversals/Staff & Audit Controls/TABLE/Refund Notes Report',
    $$
    WITH scoped_refunds AS (
        SELECT r.id,
               r.note,
               COALESCE(r.total_refunded_amount, 0) AS amount,
               COALESCE(r.processed_at, r.created_at)::date AS refund_date
        FROM public.fact_order_refunds r
        JOIN public.fact_order_headers o ON o.id = r.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND r.total_refunded_amount > 0
          AND (:currentStartDate IS NULL OR COALESCE(r.processed_at, r.created_at)::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR COALESCE(r.processed_at, r.created_at)::date <= :currentEndDate::date)
    ),
    tokens AS (
        SELECT DISTINCT s.id AS refund_id,
               l.lexeme AS keyword
        FROM scoped_refunds s,
             LATERAL unnest(to_tsvector('english', COALESCE(s.note, ''))) AS l
    ),
    refund_keywords AS (
        SELECT t.refund_id,
               string_agg(t.keyword, ', ' ORDER BY t.keyword) AS keywords
        FROM tokens t
        GROUP BY t.refund_id
    )
    SELECT s.id AS refund_id,
           s.note AS note,
           rk.keywords AS keywords,
           ROUND(s.amount, 2) AS refunded_amount,
           s.refund_date::text AS refund_date,
           COUNT(*) OVER() AS total_records
    FROM scoped_refunds s
    LEFT JOIN refund_keywords rk ON rk.refund_id = s.id
    ORDER BY s.refund_date DESC, refunded_amount DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    $$,
    NULL,
    'TABLE',
    30,
    'Tabular report of refund notes mapped to extracted search keywords for compliance audit.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
);