--liquibase formatted sql logicalFilePath:20260729001_analytical_order_line_item_analytics_data.sql

--changeset saugat:RW-35-1
--comment seed sales performance tab

INSERT INTO chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31b-719e-9ef4-3c9253becb87',
    'Sales Performance KPIs',
    'Order Line Item Analytics/Sales Performance/KPI/Sales Performance KPIs',
    '
    WITH scoped_lines AS (
        SELECT * FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date))  AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)          AS is_prior,
                   li.quantity AS units,
                   COALESCE(li.original_total_amount, li.original_unit_price * li.quantity, 0) AS gross_sales,
                   COALESCE(li.discounted_total_amount, 0) AS net_sales
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.cancelled_at IS NULL
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    totals AS (
        SELECT COALESCE(SUM(units)       FILTER (WHERE is_current), 0) AS cur_units,
               COALESCE(SUM(units)       FILTER (WHERE is_prior),   0) AS prv_units,
               COALESCE(SUM(net_sales)   FILTER (WHERE is_current), 0) AS cur_net,
               COALESCE(SUM(net_sales)   FILTER (WHERE is_prior),   0) AS prv_net,
               COALESCE(SUM(gross_sales) FILTER (WHERE is_current), 0) AS cur_gross,
               COALESCE(SUM(gross_sales) FILTER (WHERE is_prior),   0) AS prv_gross
        FROM scoped_lines
    ),
    computed AS (
        SELECT t.cur_units, t.prv_units, t.cur_net, t.prv_net, t.cur_gross, t.prv_gross,
               ROUND(t.cur_net / NULLIF(t.cur_units, 0), 2) AS cur_aup,
               ROUND(t.prv_net / NULLIF(t.prv_units, 0), 2) AS prv_aup
        FROM totals t
    )
    SELECT c.cur_units AS units_sold,
           ROUND(100 * (c.cur_units - c.prv_units)
                 / NULLIF(ABS(c.prv_units), 0), 2) AS units_sold_divergence,
           ROUND(c.cur_net, 2) AS line_item_net_sales,
           ROUND(100 * (c.cur_net - c.prv_net)
                 / NULLIF(ABS(c.prv_net), 0), 2) AS line_item_net_sales_divergence,
           ROUND(c.cur_gross, 2) AS line_item_gross_sales,
           ROUND(100 * (c.cur_gross - c.prv_gross)
                 / NULLIF(ABS(c.prv_gross), 0), 2) AS line_item_gross_sales_divergence,
           c.cur_aup AS average_unit_price,
           ROUND(100 * (c.cur_aup - c.prv_aup)
                 / NULLIF(ABS(c.prv_aup), 0), 2) AS average_unit_price_divergence
    FROM computed c
    ',
    NULL,
    'KPI',
    60,
    'Key line item sales performance metrics including units sold, net sales, gross sales, and average unit price vs prior period.',
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
    '019fff82-e31b-723e-9094-490488aabe62',
    'Top Products by Units Sold',
    'Order Line Item Analytics/Sales Performance/PLOT/Top Products by Units Sold',
    '
    WITH filtered_lines AS (
        SELECT li.product_variant_id,
               li.quantity AS units,
               COALESCE(li.discounted_total_amount, 0) AS net_sales
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT COALESCE(p.title, pv.sku, pv.id) AS product,
           SUM(f.units) AS units_sold,
           ROUND(SUM(f.net_sales), 2) AS net_sales
    FROM filtered_lines f
    JOIN public.dim_product_variants pv ON pv.id = f.product_variant_id
    LEFT JOIN public.dim_products p ON p.id = pv.product_id
    GROUP BY COALESCE(p.title, pv.sku, pv.id)
    ORDER BY units_sold DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Top products ranked by total volume of units sold.',
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
    '019fff82-e31b-7324-a5ca-7bc57b9bc509',
    'SKU Sales Trend',
    'Order Line Item Analytics/Sales Performance/PLOT/SKU Sales Trend',
    $$
    WITH
    date_params AS (
        SELECT
            g,
            CASE WHEN g = 'DAY'   THEN date_trunc('day',   :currentStartDate::date)
                 WHEN g = 'WEEK'  THEN date_trunc('week',  :currentStartDate::date)
                 WHEN g = 'MONTH' THEN date_trunc('month', :currentStartDate::date)
                 WHEN g = 'YEAR'  THEN date_trunc('year',  :currentStartDate::date)
            END AS start_bucket,
            CASE WHEN g = 'DAY'   THEN date_trunc('day',   :currentEndDate::date)
                 WHEN g = 'WEEK'  THEN date_trunc('week',  :currentEndDate::date)
                 WHEN g = 'MONTH' THEN date_trunc('month', :currentEndDate::date)
                 WHEN g = 'YEAR'  THEN date_trunc('year',  :currentEndDate::date)
            END AS end_bucket,
            CASE WHEN g = 'DAY'   THEN interval '1 day'
                 WHEN g = 'WEEK'  THEN interval '1 week'
                 WHEN g = 'MONTH' THEN interval '1 month'
                 WHEN g = 'YEAR'  THEN interval '1 year'
            END AS step
        FROM (
            SELECT COALESCE(
                NULLIF(:granularity, ''),
                CASE WHEN (:currentEndDate::date - :currentStartDate::date) > 730 THEN 'YEAR'
                     WHEN (:currentEndDate::date - :currentStartDate::date) > 180 THEN 'MONTH'
                     WHEN (:currentEndDate::date - :currentStartDate::date) > 31  THEN 'WEEK'
                     ELSE 'DAY'
                END
            ) AS g
        ) sub
    ),
    date_filler AS (
        SELECT generate_series(dp.start_bucket, dp.end_bucket, dp.step) AS bucket
        FROM date_params dp
    ),
    filtered_lines AS (
        SELECT date_trunc(LOWER(dp.g), o.created_at) AS bucket,
               li.quantity AS units,
               COALESCE(li.discounted_total_amount, 0) AS net_sales
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND o.created_at >= dp.start_bucket
          AND o.created_at <= :currentEndDate::date
    ),
    daily AS (
        SELECT f.bucket,
               SUM(f.net_sales) AS net_sales,
               SUM(f.units) AS units_sold
        FROM filtered_lines f
        GROUP BY f.bucket
    )
    SELECT to_char(df.bucket,
               CASE WHEN dp.g = 'DAY'   THEN 'Mon DD, YYYY'
                    WHEN dp.g = 'WEEK'  THEN 'Mon DD, YYYY'
                    WHEN dp.g = 'MONTH' THEN 'Mon YYYY'
                    WHEN dp.g = 'YEAR'  THEN 'YYYY'
               END
           ) AS period,
           df.bucket,
           ROUND(COALESCE(d.net_sales, 0), 2) AS net_sales,
           COALESCE(d.units_sold, 0) AS units_sold
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily d ON d.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Line item net sales and units sold trends grouped by dynamic date granularity.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "granularity":    { "source": "REQUEST_FILTER", "filterKey": "granularity" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31b-753d-8e10-ec059dcda45d',
    'Top SKUs by Net Sales',
    'Order Line Item Analytics/Sales Performance/PLOT/Top SKUs by Net Sales',
    '
    WITH filtered_lines AS (
        SELECT li.product_variant_id,
               li.quantity AS units,
               COALESCE(li.discounted_total_amount, 0) AS net_sales
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT COALESCE(pv.sku, pv.id) AS sku,
           ROUND(SUM(f.net_sales), 2) AS net_sales,
           SUM(f.units) AS units_sold
    FROM filtered_lines f
    JOIN public.dim_product_variants pv ON pv.id = f.product_variant_id
    GROUP BY COALESCE(pv.sku, pv.id)
    ORDER BY net_sales DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Top SKUs ranked by total net sales revenue.',
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
    '019fff82-e31b-7e27-9197-0666f3b361fd',
    'SKU Performance Report',
    'Order Line Item Analytics/Sales Performance/TABLE/SKU Performance Report',
    '
    WITH filtered_lines AS (
        SELECT li.product_variant_id,
               li.quantity AS units,
               COALESCE(li.unfulfilled_quantity, 0) AS unfulfilled_units,
               COALESCE(li.original_total_amount, li.original_unit_price * li.quantity, 0) AS gross_sales,
               COALESCE(li.discounted_total_amount, 0) AS net_sales,
               COALESCE(li.total_discount_amount, 0) AS discounts
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT COALESCE(pv.sku, pv.id) AS sku,
           COALESCE(p.title, pv.id) AS product,
           pv.id AS variant,
           SUM(f.units) AS units_sold,
           ROUND(SUM(f.gross_sales), 2) AS gross_sales,
           ROUND(SUM(f.discounts), 2) AS discounts,
           ROUND(SUM(f.net_sales), 2) AS net_sales,
           ROUND(SUM(f.net_sales) / NULLIF(SUM(f.units), 0), 2) AS average_unit_price,
           SUM(f.unfulfilled_units) AS unfulfilled_quantity,
           COUNT(*) OVER() AS total_records
    FROM filtered_lines f
    JOIN public.dim_product_variants pv ON pv.id = f.product_variant_id
    LEFT JOIN public.dim_products p ON p.id = pv.product_id
    GROUP BY pv.sku, pv.id, p.title
    ORDER BY net_sales DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Detailed tabular breakdown of performance per SKU evaluating units sold, gross/net sales, discounts, and AUP.',
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
    '019fff82-e31b-7a36-b194-45c103600439',
    'Product Performance Report',
    'Order Line Item Analytics/Sales Performance/TABLE/Product Performance Report',
    '
    WITH filtered_lines AS (
        SELECT li.order_id,
               li.product_variant_id,
               li.quantity AS units,
               COALESCE(li.original_total_amount, li.original_unit_price * li.quantity, 0) AS gross_sales,
               COALESCE(li.discounted_total_amount, 0) AS net_sales
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    product_lines AS (
        SELECT COALESCE(p.title, pv.sku, pv.id) AS product,
               p.vendor AS vendor,
               p.product_type AS product_type,
               tc.name AS category,
               f.order_id,
               f.units,
               f.gross_sales,
               f.net_sales
        FROM filtered_lines f
        JOIN public.dim_product_variants pv ON pv.id = f.product_variant_id
        LEFT JOIN public.dim_products p ON p.id = pv.product_id
        LEFT JOIN public.dim_taxonomy_categories tc ON tc.id = p.category_id
    )
    SELECT pl.product AS product,
           pl.vendor AS vendor,
           pl.product_type AS product_type,
           pl.category AS category,
           COUNT(DISTINCT pl.order_id) AS orders,
           SUM(pl.units) AS units_sold,
           ROUND(SUM(pl.gross_sales), 2) AS gross_sales,
           ROUND(SUM(pl.net_sales), 2) AS net_sales,
           ROUND(100 * (SUM(pl.gross_sales) - SUM(pl.net_sales)) / NULLIF(SUM(pl.gross_sales), 0), 2) AS discount_rate,
           COUNT(*) OVER() AS total_records
    FROM product_lines pl
    GROUP BY pl.product, pl.vendor, pl.product_type, pl.category
    ORDER BY net_sales DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Detailed tabular breakdown of product-level sales performance, vendor, category, and discount rates.',
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

--changeset saugat:RW-35-2
--comment seed discount and revenue leakage tab

INSERT INTO chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31b-7e1a-8714-74c60f69072e',
    'Discount & Leakage KPIs',
    'Order Line Item Analytics/Discount & Leakage/KPI/Discount & Leakage KPIs',
    '
    WITH scoped_lines AS (
        SELECT * FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date))  AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)          AS is_prior,
                   COALESCE(li.total_discount_amount, 0) AS discounts,
                   COALESCE(li.original_total_amount, li.original_unit_price * li.quantity, 0) AS original_amount
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.cancelled_at IS NULL
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    totals AS (
        SELECT COALESCE(SUM(discounts)       FILTER (WHERE is_current), 0) AS cur_discounts,
               COALESCE(SUM(discounts)       FILTER (WHERE is_prior),   0) AS prv_discounts,
               COALESCE(SUM(original_amount) FILTER (WHERE is_current), 0) AS cur_original,
               COALESCE(SUM(original_amount) FILTER (WHERE is_prior),   0) AS prv_original
        FROM scoped_lines
    ),
    computed AS (
        SELECT t.cur_discounts, t.prv_discounts,
               ROUND(100 * t.cur_discounts / NULLIF(t.cur_original, 0), 2) AS cur_rate,
               ROUND(100 * t.prv_discounts / NULLIF(t.prv_original, 0), 2) AS prv_rate
        FROM totals t
    )
    SELECT ROUND(c.cur_discounts, 2) AS total_line_discounts,
           ROUND(100 * (c.cur_discounts - c.prv_discounts)
                 / NULLIF(ABS(c.prv_discounts), 0), 2) AS total_line_discounts_divergence,
           c.cur_rate AS discount_rate,
           ROUND(100 * (c.cur_rate - c.prv_rate)
                 / NULLIF(ABS(c.prv_rate), 0), 2) AS discount_rate_divergence
    FROM computed c
    ',
    NULL,
    'KPI',
    60,
    'Total line item discount amounts and discount rate percentage vs prior period.',
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
    '019fff82-e31b-7c5d-ae47-dd60a34e7dc7',
    'Discount Leakage by SKU',
    'Order Line Item Analytics/Discount & Leakage/PLOT/Discount Leakage by SKU',
    '
    WITH filtered_lines AS (
        SELECT li.product_variant_id,
               COALESCE(li.total_discount_amount, 0) AS discounts
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT COALESCE(pv.sku, pv.id) AS sku,
           ROUND(SUM(f.discounts), 2) AS discount_amount
    FROM filtered_lines f
    JOIN public.dim_product_variants pv ON pv.id = f.product_variant_id
    GROUP BY COALESCE(pv.sku, pv.id)
    HAVING SUM(f.discounts) > 0
    ORDER BY discount_amount DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'SKUs ranked by total discount dollar leakage.',
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
    '019fff82-e31b-702b-8871-b4a7b41f48ed',
    'Discount Leakage Report',
    'Order Line Item Analytics/Discount & Leakage/TABLE/Discount Leakage Report',
    '
    WITH filtered_lines AS (
        SELECT li.id AS line_id,
               li.product_variant_id,
               o.id AS order_id,
               COALESCE(li.original_total_amount, li.original_unit_price * li.quantity, 0) AS original_amount,
               COALESCE(li.discounted_total_amount, 0) AS discounted_amount,
               COALESCE(li.total_discount_amount, 0) AS discount_amount
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND COALESCE(li.total_discount_amount, 0) > 0
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT COALESCE(pv.sku, pv.id) AS sku,
           COALESCE(p.title, pv.id) AS product,
           f.order_id,
           ROUND(f.original_amount, 2) AS original_amount,
           ROUND(f.discounted_amount, 2) AS discounted_amount,
           ROUND(f.discount_amount, 2) AS discount_amount,
           ROUND(100 * f.discount_amount / NULLIF(f.original_amount, 0), 2) AS discount_rate,
           COUNT(*) OVER() AS total_records
    FROM filtered_lines f
    JOIN public.dim_product_variants pv ON pv.id = f.product_variant_id
    LEFT JOIN public.dim_products p ON p.id = pv.product_id
    ORDER BY f.discount_amount DESC, f.line_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Granular tabular audit of individual line item discount leakage per order.',
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

--changeset saugat:RW-35-3
--comment seed fulfillment and backlog tab

INSERT INTO chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31b-7369-bc64-833156976630',
    'Fulfillment & Backlog KPIs',
    'Order Line Item Analytics/Fulfillment & Backlog/KPI/Fulfillment & Backlog KPIs',
    '
    WITH scoped_lines AS (
        SELECT * FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date))  AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)          AS is_prior,
                   COALESCE(li.unfulfilled_quantity, 0) AS unfulfilled_units,
                   COALESCE(li.unfulfilled_discounted_total_amount, 0) AS unfulfilled_value
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.cancelled_at IS NULL
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    totals AS (
        SELECT COALESCE(SUM(unfulfilled_units) FILTER (WHERE is_current), 0) AS cur_units,
               COALESCE(SUM(unfulfilled_units) FILTER (WHERE is_prior),   0) AS prv_units,
               COALESCE(SUM(unfulfilled_value) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(unfulfilled_value) FILTER (WHERE is_prior),   0) AS prv_value
        FROM scoped_lines
    )
    SELECT t.cur_units AS unfulfilled_quantity,
           ROUND(100 * (t.cur_units - t.prv_units)
                 / NULLIF(ABS(t.prv_units), 0), 2) AS unfulfilled_quantity_divergence,
           ROUND(t.cur_value, 2) AS unfulfilled_value,
           ROUND(100 * (t.cur_value - t.prv_value)
                 / NULLIF(ABS(t.prv_value), 0), 2) AS unfulfilled_value_divergence
    FROM totals t
    ',
    NULL,
    'KPI',
    60,
    'Unfulfilled item backlog volume and total unfulfilled revenue value vs prior period.',
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
    '019fff82-e31b-7ea2-96e7-94369d8d22a0',
    'Unfulfilled Quantity by SKU',
    'Order Line Item Analytics/Fulfillment & Backlog/PLOT/Unfulfilled Quantity by SKU',
    '
    WITH filtered_lines AS (
        SELECT li.product_variant_id,
               COALESCE(li.unfulfilled_quantity, 0) AS unfulfilled_units
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT COALESCE(pv.sku, pv.id) AS sku,
           SUM(f.unfulfilled_units) AS unfulfilled_quantity
    FROM filtered_lines f
    JOIN public.dim_product_variants pv ON pv.id = f.product_variant_id
    GROUP BY COALESCE(pv.sku, pv.id)
    HAVING SUM(f.unfulfilled_units) > 0
    ORDER BY unfulfilled_quantity DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'SKUs ranked by total unfulfilled item quantity backlog.',
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
    '019fff82-e31b-786f-9d94-810596bff3e8',
    'Unfulfilled Line Items Report',
    'Order Line Item Analytics/Fulfillment & Backlog/TABLE/Unfulfilled Line Items Report',
    '
    WITH filtered_lines AS (
        SELECT li.id AS line_id,
               li.product_variant_id,
               o.id AS order_id,
               o.fulfillmentstatus AS fulfillment_status,
               li.quantity AS units,
               COALESCE(li.unfulfilled_quantity, 0) AS unfulfilled_units,
               COALESCE(li.unfulfilled_discounted_total_amount, 0) AS unfulfilled_value
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND COALESCE(li.unfulfilled_quantity, 0) > 0
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT f.order_id,
           COALESCE(pv.sku, pv.id) AS sku,
           COALESCE(p.title, pv.id) AS product,
           f.units AS quantity,
           f.unfulfilled_units AS unfulfilled_quantity,
           ROUND(f.unfulfilled_value, 2) AS unfulfilled_value,
           f.fulfillment_status AS fulfillment_status,
           COUNT(*) OVER() AS total_records
    FROM filtered_lines f
    JOIN public.dim_product_variants pv ON pv.id = f.product_variant_id
    LEFT JOIN public.dim_products p ON p.id = pv.product_id
    ORDER BY f.unfulfilled_value DESC, f.line_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Granular tabular audit of individual unfulfilled line items per order.',
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

--changeset saugat:RW-35-4
--comment seed returns and refunds tab

INSERT INTO chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31b-7c4f-b65d-bdeb64328a28',
    'Returns & Refunds KPIs',
    'Order Line Item Analytics/Returns & Refunds/KPI/Returns & Refunds KPIs',
    '
    WITH scoped_lines AS (
        SELECT * FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date))  AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)          AS is_prior,
                   li.quantity - COALESCE(li.current_quantity, li.quantity) AS removed_units,
                   COALESCE(li.refundable_quantity, 0) AS refundable_units
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.cancelled_at IS NULL
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    totals AS (
        SELECT COALESCE(SUM(removed_units)    FILTER (WHERE is_current), 0) AS cur_removed,
               COALESCE(SUM(removed_units)    FILTER (WHERE is_prior),   0) AS prv_removed,
               COALESCE(SUM(refundable_units) FILTER (WHERE is_current), 0) AS cur_refundable,
               COALESCE(SUM(refundable_units) FILTER (WHERE is_prior),   0) AS prv_refundable
        FROM scoped_lines
    )
    SELECT t.cur_removed AS refund_removed_quantity,
           ROUND(100 * (t.cur_removed - t.prv_removed)
                 / NULLIF(ABS(t.prv_removed), 0), 2) AS refund_removed_quantity_divergence,
           t.cur_refundable AS refundable_quantity,
           ROUND(100 * (t.cur_refundable - t.prv_refundable)
                 / NULLIF(ABS(t.prv_refundable), 0), 2) AS refundable_quantity_divergence
    FROM totals t
    ',
    NULL,
    'KPI',
    60,
    'Line item refund removed quantity and refundable item totals vs prior period.',
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
    '019fff82-e31b-7505-ba36-3c1dd912477f',
    'Refund / Removed Quantity by SKU',
    'Order Line Item Analytics/Returns & Refunds/PLOT/Refund / Removed Quantity by SKU',
    '
    WITH filtered_lines AS (
        SELECT li.product_variant_id,
               li.quantity - COALESCE(li.current_quantity, li.quantity) AS removed_units
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
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
    ',
    NULL,
    'PLOT',
    60,
    'SKUs ranked by total quantity of units removed due to refunds.',
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
    '019fff82-e31b-77da-849c-4dcfb1d0ab6f',
    'Refund / Removed Quantity Report',
    'Order Line Item Analytics/Returns & Refunds/TABLE/Refund / Removed Quantity Report',
    '
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
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT COALESCE(pv.sku, pv.id) AS sku,
           COALESCE(p.title, pv.id) AS product,
           SUM(f.ordered_units) AS ordered_quantity,
           SUM(f.current_units) AS current_quantity,
           SUM(f.removed_units) AS refund_removed_quantity,
           SUM(f.refundable_units) AS refundable_quantity,
           COUNT(*) OVER() AS total_records
    FROM filtered_lines f
    JOIN public.dim_product_variants pv ON pv.id = f.product_variant_id
    LEFT JOIN public.dim_products p ON p.id = pv.product_id
    GROUP BY COALESCE(pv.sku, pv.id), COALESCE(p.title, pv.id)
    HAVING SUM(f.removed_units) > 0
    ORDER BY refund_removed_quantity DESC, sku
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Detailed tabular breakdown of ordered vs current vs removed and refundable item quantities per SKU.',
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

--changeset saugat:RW-35-5
--comment seed product portfolio analysis tab

INSERT INTO chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31b-70e4-8f9e-3c0c9472932d',
    'Product Portfolio KPIs',
    'Order Line Item Analytics/Product Portfolio/KPI/Product Portfolio KPIs',
    '
    WITH scoped_lines AS (
        SELECT * FROM (
            SELECT li.product_variant_id,
                   ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date))  AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)          AS is_prior,
                   COALESCE(li.discounted_total_amount, 0) AS net_sales
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.cancelled_at IS NULL
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    sku_sales AS (
        SELECT COALESCE(SUM(l.net_sales) FILTER (WHERE l.is_current), 0) AS cur_net,
               COALESCE(SUM(l.net_sales) FILTER (WHERE l.is_prior),   0) AS prv_net
        FROM scoped_lines l
        JOIN public.dim_product_variants pv ON pv.id = l.product_variant_id
        GROUP BY COALESCE(pv.sku, pv.id)
    ),
    computed AS (
        SELECT ROUND(100 * MAX(cur_net) / NULLIF(SUM(cur_net), 0), 2) AS cur_share,
               ROUND(100 * MAX(prv_net) / NULLIF(SUM(prv_net), 0), 2) AS prv_share
        FROM sku_sales
    )
    SELECT c.cur_share AS top_sku_contribution,
           ROUND(100 * (c.cur_share - c.prv_share)
                 / NULLIF(ABS(c.prv_share), 0), 2) AS top_sku_contribution_divergence
    FROM computed c
    ',
    NULL,
    'KPI',
    60,
    'Revenue contribution percentage of the single top-performing SKU vs prior period.',
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
    '019fff82-e31b-7bfb-ae14-6b2e4c98ee78',
    'Product Revenue Pareto',
    'Order Line Item Analytics/Product Portfolio/PLOT/Product Revenue Pareto',
    '
    WITH filtered_lines AS (
        SELECT li.product_variant_id,
               COALESCE(li.discounted_total_amount, 0) AS net_sales
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    product_sales AS (
        SELECT COALESCE(p.title, pv.sku, pv.id) AS product,
               SUM(f.net_sales) AS net_sales
        FROM filtered_lines f
        JOIN public.dim_product_variants pv ON pv.id = f.product_variant_id
        LEFT JOIN public.dim_products p ON p.id = pv.product_id
        GROUP BY COALESCE(p.title, pv.sku, pv.id)
        HAVING SUM(f.net_sales) > 0
    )
    SELECT ps.product AS product,
           ROUND(100 * ps.net_sales / SUM(ps.net_sales) OVER (), 2) AS contribution_pct,
           ROUND(100 * SUM(ps.net_sales) OVER (ORDER BY ps.net_sales DESC ROWS UNBOUNDED PRECEDING)
                 / SUM(ps.net_sales) OVER (), 2) AS cumulative_pct
    FROM product_sales ps
    ORDER BY ps.net_sales DESC
    ',
    NULL,
    'PLOT',
    60,
    'Pareto chart showing individual product revenue contribution % and cumulative % concentration.',
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
    '019fff82-e31b-7e59-932d-1541b1ecf67e',
    'Average Unit Price Trend',
    'Order Line Item Analytics/Product Portfolio/PLOT/Average Unit Price Trend',
    $$
    WITH
    date_params AS (
        SELECT
            g,
            CASE WHEN g = 'DAY'   THEN date_trunc('day',   :currentStartDate::date)
                 WHEN g = 'WEEK'  THEN date_trunc('week',  :currentStartDate::date)
                 WHEN g = 'MONTH' THEN date_trunc('month', :currentStartDate::date)
                 WHEN g = 'YEAR'  THEN date_trunc('year',  :currentStartDate::date)
            END AS start_bucket,
            CASE WHEN g = 'DAY'   THEN date_trunc('day',   :currentEndDate::date)
                 WHEN g = 'WEEK'  THEN date_trunc('week',  :currentEndDate::date)
                 WHEN g = 'MONTH' THEN date_trunc('month', :currentEndDate::date)
                 WHEN g = 'YEAR'  THEN date_trunc('year',  :currentEndDate::date)
            END AS end_bucket,
            CASE WHEN g = 'DAY'   THEN interval '1 day'
                 WHEN g = 'WEEK'  THEN interval '1 week'
                 WHEN g = 'MONTH' THEN interval '1 month'
                 WHEN g = 'YEAR'  THEN interval '1 year'
            END AS step
        FROM (
            SELECT COALESCE(
                NULLIF(:granularity, ''),
                CASE WHEN (:currentEndDate::date - :currentStartDate::date) > 730 THEN 'YEAR'
                     WHEN (:currentEndDate::date - :currentStartDate::date) > 180 THEN 'MONTH'
                     WHEN (:currentEndDate::date - :currentStartDate::date) > 31  THEN 'WEEK'
                     ELSE 'DAY'
                END
            ) AS g
        ) sub
    ),
    date_filler AS (
        SELECT generate_series(dp.start_bucket, dp.end_bucket, dp.step) AS bucket
        FROM date_params dp
    ),
    filtered_lines AS (
        SELECT date_trunc(LOWER(dp.g), o.created_at) AS bucket,
               li.quantity AS units,
               COALESCE(li.discounted_total_amount, 0) AS net_sales
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND o.created_at >= dp.start_bucket
          AND o.created_at <= :currentEndDate::date
    ),
    daily AS (
        SELECT f.bucket,
               ROUND(SUM(f.net_sales) / NULLIF(SUM(f.units), 0), 2) AS average_unit_price
        FROM filtered_lines f
        GROUP BY f.bucket
    )
    SELECT to_char(df.bucket,
               CASE WHEN dp.g = 'DAY'   THEN 'Mon DD, YYYY'
                    WHEN dp.g = 'WEEK'  THEN 'Mon DD, YYYY'
                    WHEN dp.g = 'MONTH' THEN 'Mon YYYY'
                    WHEN dp.g = 'YEAR'  THEN 'YYYY'
               END
           ) AS period,
           df.bucket,
           d.average_unit_price AS average_unit_price
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily d ON d.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Trend of Average Unit Price (AUP) grouped by dynamic date granularity.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "granularity":    { "source": "REQUEST_FILTER", "filterKey": "granularity" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31b-7a43-a257-44955fedfa5b',
    'Sales by Category',
    'Order Line Item Analytics/Product Portfolio/PLOT/Sales by Category',
    '
    WITH filtered_lines AS (
        SELECT li.product_variant_id,
               COALESCE(li.discounted_total_amount, 0) AS net_sales
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT COALESCE(tc.name, p.product_type, pv.sku) AS category,
           ROUND(SUM(f.net_sales), 2) AS net_sales
    FROM filtered_lines f
    JOIN public.dim_product_variants pv ON pv.id = f.product_variant_id
    LEFT JOIN public.dim_products p ON p.id = pv.product_id
    LEFT JOIN public.dim_taxonomy_categories tc ON tc.id = p.category_id
    GROUP BY COALESCE(tc.name, p.product_type, pv.sku)
    HAVING SUM(f.net_sales) > 0
    ORDER BY net_sales DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Net sales breakdown grouped across taxonomy categories and product types.',
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
    '019fff82-e31b-7d85-9cd5-abac703c0eab',
    'Gross vs Net Sales by Product',
    'Order Line Item Analytics/Product Portfolio/PLOT/Gross vs Net Sales by Product',
    '
    WITH filtered_lines AS (
        SELECT li.product_variant_id,
               COALESCE(li.original_total_amount, li.original_unit_price * li.quantity, 0) AS gross_sales,
               COALESCE(li.discounted_total_amount, 0) AS net_sales
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT COALESCE(p.title, pv.sku, pv.id) AS product,
           ROUND(SUM(f.gross_sales), 2) AS gross_sales,
           ROUND(SUM(f.net_sales), 2) AS net_sales
    FROM filtered_lines f
    JOIN public.dim_product_variants pv ON pv.id = f.product_variant_id
    LEFT JOIN public.dim_products p ON p.id = pv.product_id
    GROUP BY COALESCE(p.title, pv.sku, pv.id)
    HAVING SUM(f.gross_sales) > 0
    ORDER BY net_sales DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Comparison of gross sales vs net sales per product.',
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
    '019fff82-e31b-7046-ab17-44ababdc75de',
    'Collection Performance Report',
    'Order Line Item Analytics/Vendor & Collection/TABLE/Collection Performance Report',
    '
    WITH filtered_lines AS (
        SELECT li.product_variant_id,
               li.quantity AS units,
               COALESCE(li.original_total_amount, li.original_unit_price * li.quantity, 0) AS gross_sales,
               COALESCE(li.discounted_total_amount, 0) AS net_sales
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    period_total AS (
        SELECT SUM(f.net_sales) AS total_net_sales
        FROM filtered_lines f
    ),
    collection_lines AS (
        SELECT c.title AS collection,
               pv.product_id AS product_id,
               f.units,
               f.gross_sales,
               f.net_sales
        FROM filtered_lines f
        JOIN public.dim_product_variants pv ON pv.id = f.product_variant_id
        JOIN public.dim_collection_products cp ON cp.product_id = pv.product_id
        JOIN public.dim_collections c ON c.id = cp.collection_id
        WHERE c.seller_id = :shopId
    )
    SELECT cl.collection AS collection,
           COUNT(DISTINCT cl.product_id) AS products,
           SUM(cl.units) AS units_sold,
           ROUND(SUM(cl.net_sales), 2) AS net_sales,
           ROUND(100 * SUM(cl.net_sales) / NULLIF(pt.total_net_sales, 0), 2) AS sales_contribution,
           ROUND(100 * (SUM(cl.gross_sales) - SUM(cl.net_sales)) / NULLIF(SUM(cl.gross_sales), 0), 2) AS discount_rate,
           COUNT(*) OVER() AS total_records
    FROM collection_lines cl
    CROSS JOIN period_total pt
    GROUP BY cl.collection, pt.total_net_sales
    ORDER BY net_sales DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Performance scorecard per collection evaluating products count, units sold, net sales, contribution %, and discount %.',
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

--changeset saugat:RW-35-6
--comment seed vendor and collection performance tab

INSERT INTO chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31b-7db6-9794-777cfa9aefdc',
    'Gift Card Line Sales',
    'Order Line Item Analytics/Vendor & Collection/KPI/Gift Card Line Sales',
    '
    WITH scoped_lines AS (
    SELECT *
    FROM (
        SELECT
            (
                (:currentStartDate::date IS NULL
                 OR o.created_at::date >= :currentStartDate::date)
                AND
                (:currentEndDate::date IS NULL
                 OR o.created_at::date <= :currentEndDate::date)
            ) AS is_current,
            (
                :priorStartDate::date IS NOT NULL
                AND o.created_at::date
                    BETWEEN :priorStartDate::date AND :priorEndDate::date
            ) AS is_prior,
            COALESCE(li.is_giftcard, FALSE) AS is_gift_card,
            COALESCE(li.discounted_total_amount, 0) AS net_sales
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o
            ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
    ) t
    WHERE t.is_current OR t.is_prior
),
totals AS (
    SELECT
        COALESCE(
            SUM(net_sales)
            FILTER (WHERE is_current AND is_gift_card),
            0
        ) AS cur_gift,
        COALESCE(
            SUM(net_sales)
            FILTER (WHERE is_prior AND is_gift_card),
            0
        ) AS prv_gift
    FROM scoped_lines
)
SELECT
    ROUND(t.cur_gift, 2) AS gift_card_line_sales,
    ROUND(
        100 * (t.cur_gift - t.prv_gift)
        / NULLIF(ABS(t.prv_gift), 0),
        2
    ) AS gift_card_line_sales_divergence
FROM totals t
    ',
    NULL,
    'KPI',
    60,
    'Total net sales generated from gift card line items vs prior period.',
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
    '019fff82-e31b-793a-8fcc-6877cfc039bf',
    'Sales by Vendor',
    'Order Line Item Analytics/Vendor & Collection/PLOT/Sales by Vendor',
    '
    WITH filtered_lines AS (
        SELECT li.product_variant_id,
               li.quantity AS units,
               COALESCE(li.discounted_total_amount, 0) AS net_sales
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT COALESCE(p.vendor, pv.sku, pv.id) AS vendor,
           ROUND(SUM(f.net_sales), 2) AS net_sales,
           SUM(f.units) AS units_sold
    FROM filtered_lines f
    JOIN public.dim_product_variants pv ON pv.id = f.product_variant_id
    LEFT JOIN public.dim_products p ON p.id = pv.product_id
    GROUP BY COALESCE(p.vendor, pv.sku, pv.id)
    HAVING SUM(f.net_sales) > 0
    ORDER BY net_sales DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Net sales breakdown grouped by product vendor.',
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
    '019fff82-e31b-7e3a-a503-265f777d3aa1',
    'Sales by Collection',
    'Order Line Item Analytics/Vendor & Collection/PLOT/Sales by Collection',
    '
    WITH filtered_lines AS (
        SELECT li.product_variant_id,
               li.quantity AS units,
               COALESCE(li.discounted_total_amount, 0) AS net_sales
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT c.title AS collection,
           ROUND(SUM(f.net_sales), 2) AS net_sales,
           SUM(f.units) AS units_sold
    FROM filtered_lines f
    JOIN public.dim_product_variants pv ON pv.id = f.product_variant_id
    JOIN public.dim_collection_products cp ON cp.product_id = pv.product_id
    JOIN public.dim_collections c ON c.id = cp.collection_id
    WHERE c.seller_id = :shopId
    GROUP BY c.title
    HAVING SUM(f.net_sales) > 0
    ORDER BY net_sales DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Net sales breakdown grouped by product collection.',
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
    '019fff82-e31b-7b9d-b376-960a16cbf47a',
    'Gift Card vs Merchandise Sales',
    'Order Line Item Analytics/Vendor & Collection/PLOT/Gift Card vs Merchandise Sales',
    '
    WITH filtered_lines AS (
        SELECT COALESCE(li.is_giftcard, FALSE) AS is_gift_card,
               COALESCE(li.discounted_total_amount, 0) AS net_sales
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    segments AS (
        SELECT ROUND(COALESCE(SUM(f.net_sales) FILTER (WHERE f.is_gift_card), 0), 2)     AS "Gift Cards",
               ROUND(COALESCE(SUM(f.net_sales) FILTER (WHERE NOT f.is_gift_card), 0), 2) AS "Merchandise"
        FROM filtered_lines f
    )
    SELECT e.segment AS segment,
           e.amount::numeric AS sales_value
    FROM segments s,
         json_each_text(row_to_json(s)) WITH ORDINALITY AS e(segment, amount, ord)
    ORDER BY e.ord
    ',
    NULL,
    'PLOT',
    60,
    'Comparison of net sales between gift card items and standard merchandise.',
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
    '019fff82-e31b-76e0-bf62-575b5d09b4da',
    'Vendor Sales Report',
    'Order Line Item Analytics/Vendor & Collection/TABLE/Vendor Sales Report',
    '
    WITH filtered_lines AS (
        SELECT li.product_variant_id,
               li.quantity AS units,
               COALESCE(li.original_total_amount, li.original_unit_price * li.quantity, 0) AS gross_sales,
               COALESCE(li.discounted_total_amount, 0) AS net_sales
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT COALESCE(p.vendor, pv.sku, pv.id) AS vendor,
           COUNT(DISTINCT pv.product_id) AS products,
           COUNT(DISTINCT pv.id) AS skus,
           SUM(f.units) AS units_sold,
           ROUND(SUM(f.gross_sales), 2) AS gross_sales,
           ROUND(SUM(f.net_sales), 2) AS net_sales,
           ROUND(100 * (SUM(f.gross_sales) - SUM(f.net_sales)) / NULLIF(SUM(f.gross_sales), 0), 2) AS discount_rate,
           COUNT(*) OVER() AS total_records
    FROM filtered_lines f
    JOIN public.dim_product_variants pv ON pv.id = f.product_variant_id
    LEFT JOIN public.dim_products p ON p.id = pv.product_id
    GROUP BY COALESCE(p.vendor, pv.sku, pv.id)
    ORDER BY net_sales DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Detailed tabular breakdown per vendor showing products, skus, units sold, gross/net sales, and discount %.',
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
