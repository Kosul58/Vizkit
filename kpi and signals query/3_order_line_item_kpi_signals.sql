
-- ---------- 1. charts: value only ----------

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '01a066fa-17dd-7958-bd80-f6aac116cfe0',
    'Units Sold',
    'Order Line Item Analytics/Sales Performance/KPI/Units Sold',
    $$
    SELECT COALESCE(SUM(li.quantity), 0) AS units_sold
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
    'Total line item units sold for the selected period vs the prior period.',
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
    '01a066fa-17dd-7e00-9d02-d7ea58c808a3',
    'Line Item Net Sales',
    'Order Line Item Analytics/Sales Performance/KPI/Line Item Net Sales',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(li.discounted_total_amount, 0)), 0), 2) AS line_item_net_sales
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
    'Line item net sales (after discounts) for the selected period vs the prior period.',
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
    '01a066fa-17dd-7675-ae32-cb0f04b9e309',
    'Line Item Gross Sales',
    'Order Line Item Analytics/Sales Performance/KPI/Line Item Gross Sales',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(li.original_total_amount, 0)), 0), 2) AS line_item_gross_sales
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
    'Line item gross sales (before discounts) for the selected period vs the prior period.',
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
    '01a066fa-17dd-7eda-a698-a2eb80fecfd8',
    'Average Unit Price',
    'Order Line Item Analytics/Sales Performance/KPI/Average Unit Price',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(li.discounted_total_amount, 0)), 0)
                 / NULLIF(COALESCE(SUM(li.quantity), 0), 0), 2) AS average_unit_price
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
    'Average net price per unit sold for the selected period vs the prior period.',
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
    '01a066fa-17de-7aad-a770-b6c54ec7df92',
    'Total Line Discounts',
    'Order Line Item Analytics/Discount & Leakage/KPI/Total Line Discounts',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(li.total_discount_amount, 0)), 0), 2) AS total_line_discounts
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
    'Total line item discount amount for the selected period vs the prior period.',
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
    '01a066fa-17de-701e-9ae5-81920f8472d5',
    'Discount Rate',
    'Order Line Item Analytics/Discount & Leakage/KPI/Discount Rate',
    $$
    SELECT ROUND(100 * COALESCE(SUM(COALESCE(li.total_discount_amount, 0)), 0)
                 / NULLIF(COALESCE(SUM(COALESCE(li.original_total_amount, 0)), 0), 0), 2) AS discount_rate
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
    'Discounts as a percentage of original line item value for the selected period vs the prior period.',
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
    '01a066fa-17df-7db3-bfcd-4f96e88e3bb8',
    'Unfulfilled Quantity',
    'Order Line Item Analytics/Fulfillment & Backlog/KPI/Unfulfilled Quantity',
    $$
    SELECT COALESCE(SUM(COALESCE(li.unfulfilled_quantity, 0)), 0) AS unfulfilled_quantity
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
    'Unfulfilled item backlog volume for the selected period vs the prior period.',
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
    '01a066fa-17df-74b3-bae5-8af5414b8ed1',
    'Unfulfilled Value',
    'Order Line Item Analytics/Fulfillment & Backlog/KPI/Unfulfilled Value',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(li.unfulfilled_discounted_total_amount, 0)), 0), 2) AS unfulfilled_value
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
    'Total unfulfilled revenue value for the selected period vs the prior period.',
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
    '01a066fa-17df-7156-b4f0-12c52854674f',
    'Refund Removed Quantity',
    'Order Line Item Analytics/Returns & Refunds/KPI/Refund Removed Quantity',
    $$
    SELECT COALESCE(SUM(li.quantity - li.current_quantity), 0) AS refund_removed_quantity
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
    '01a066fa-17df-7f72-bc53-3e7e47c76ea7',
    'Refundable Quantity',
    'Order Line Item Analytics/Returns & Refunds/KPI/Refundable Quantity',
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
),
(
    '01a066fa-17e0-782d-a996-6ea0042f6dc7',
    'Top SKU Contribution',
    'Order Line Item Analytics/Product Portfolio/KPI/Top SKU Contribution',
    $$
    WITH sku_sales AS (
        SELECT COALESCE(SUM(COALESCE(li.discounted_total_amount, 0)), 0) AS net_sales
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        JOIN public.dim_product_variants pv ON pv.id = li.product_variant_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY COALESCE(pv.sku, pv.id)
    )
    SELECT ROUND(100 * MAX(net_sales) / NULLIF(SUM(net_sales), 0), 2) AS top_sku_contribution
    FROM sku_sales
    $$,
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
    '01a066fa-17e1-76a4-905d-c947176ef144',
    'Gift Card Line Sales',
    'Order Line Item Analytics/Vendor & Collection/KPI/Gift Card Line Sales',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(li.discounted_total_amount, 0))
                          FILTER (WHERE COALESCE(li.is_giftcard, FALSE)), 0), 2) AS gift_card_line_sales
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
);

-- ---------- 2. chart signals: divergence ----------

INSERT INTO vizkit.chart_signal (id, chart_id, name, query)
VALUES (
    '019fff82-e31b-7c01-8f51-3a2b3c4d1001',
    '01a066fa-17dd-7958-bd80-f6aac116cfe0',
    'units_sold',
    $$
    WITH totals AS (
        SELECT COALESCE(SUM(units) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(units) FILTER (WHERE is_prior),   0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   li.quantity AS units
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
    '019fff82-e31b-7c02-8f52-3a2b3c4d1002',
    '01a066fa-17dd-7e00-9d02-d7ea58c808a3',
    'line_item_net_sales',
    $$
    WITH totals AS (
        SELECT COALESCE(SUM(net_sales) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior),   0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(li.discounted_total_amount, 0) AS net_sales
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
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
    '019fff82-e31b-7c03-8f53-3a2b3c4d1003',
    '01a066fa-17dd-7675-ae32-cb0f04b9e309',
    'line_item_gross_sales',
    $$
    WITH totals AS (
        SELECT COALESCE(SUM(gross_sales) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(gross_sales) FILTER (WHERE is_prior),   0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(li.original_total_amount, 0) AS gross_sales
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
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
    '019fff82-e31b-7c04-8f54-3a2b3c4d1004',
    '01a066fa-17dd-7eda-a698-a2eb80fecfd8',
    'average_unit_price',
    $$
    WITH totals AS (
        SELECT COALESCE(SUM(units)     FILTER (WHERE is_current), 0) AS cur_units,
               COALESCE(SUM(units)     FILTER (WHERE is_prior),   0) AS prv_units,
               COALESCE(SUM(net_sales) FILTER (WHERE is_current), 0) AS cur_net,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior),   0) AS prv_net
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   li.quantity AS units,
                   COALESCE(li.discounted_total_amount, 0) AS net_sales
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    computed AS (
        SELECT ROUND(t.cur_net / NULLIF(t.cur_units, 0), 2) AS cur_aup,
               ROUND(t.prv_net / NULLIF(t.prv_units, 0), 2) AS prv_aup
        FROM totals t
    )
    SELECT c.prv_aup AS previous_value,
           ROUND(100 * (c.cur_aup - c.prv_aup)
                 / NULLIF(ABS(c.prv_aup), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fff82-e31b-7c05-8f55-3a2b3c4d1005',
    '01a066fa-17de-7aad-a770-b6c54ec7df92',
    'total_line_discounts',
    $$
    WITH totals AS (
        SELECT COALESCE(SUM(discounts) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(discounts) FILTER (WHERE is_prior),   0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(li.total_discount_amount, 0) AS discounts
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
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
    '019fff82-e31b-7c06-8f56-3a2b3c4d1006',
    '01a066fa-17de-701e-9ae5-81920f8472d5',
    'discount_rate',
    $$
    WITH totals AS (
        SELECT COALESCE(SUM(discounts)       FILTER (WHERE is_current), 0) AS cur_discounts,
               COALESCE(SUM(discounts)       FILTER (WHERE is_prior),   0) AS prv_discounts,
               COALESCE(SUM(original_amount) FILTER (WHERE is_current), 0) AS cur_original,
               COALESCE(SUM(original_amount) FILTER (WHERE is_prior),   0) AS prv_original
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(li.total_discount_amount, 0) AS discounts,
                   COALESCE(li.original_total_amount, 0) AS original_amount
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    computed AS (
        SELECT ROUND(100 * t.cur_discounts / NULLIF(t.cur_original, 0), 2) AS cur_rate,
               ROUND(100 * t.prv_discounts / NULLIF(t.prv_original, 0), 2) AS prv_rate
        FROM totals t
    )
    SELECT c.prv_rate AS previous_value,
           ROUND(100 * (c.cur_rate - c.prv_rate)
                 / NULLIF(ABS(c.prv_rate), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fff82-e31b-7c07-8f57-3a2b3c4d1007',
    '01a066fa-17df-7db3-bfcd-4f96e88e3bb8',
    'unfulfilled_quantity',
    $$
    WITH totals AS (
        SELECT COALESCE(SUM(unfulfilled_units) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(unfulfilled_units) FILTER (WHERE is_prior),   0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(li.unfulfilled_quantity, 0) AS unfulfilled_units
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
    '019fff82-e31b-7c08-8f58-3a2b3c4d1008',
    '01a066fa-17df-74b3-bae5-8af5414b8ed1',
    'unfulfilled_value',
    $$
    WITH totals AS (
        SELECT COALESCE(SUM(unfulfilled_value) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(unfulfilled_value) FILTER (WHERE is_prior),   0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(li.unfulfilled_discounted_total_amount, 0) AS unfulfilled_value
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
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
    '019fff82-e31b-7c09-8f59-3a2b3c4d1009',
    '01a066fa-17df-7156-b4f0-12c52854674f',
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
                   li.quantity - li.current_quantity AS removed_units
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
    '019fff82-e31b-7c0a-8f5a-3a2b3c4d100a',
    '01a066fa-17df-7f72-bc53-3e7e47c76ea7',
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
),
(
    '019fff82-e31b-7c0b-8f5b-3a2b3c4d100b',
    '01a066fa-17e0-782d-a996-6ea0042f6dc7',
    'top_sku_contribution',
    $$
    WITH sku_sales AS (
        SELECT COALESCE(SUM(t.net_sales) FILTER (WHERE t.is_current), 0) AS cur_net,
               COALESCE(SUM(t.net_sales) FILTER (WHERE t.is_prior),   0) AS prv_net
        FROM (
            SELECT li.product_variant_id,
                   ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(li.discounted_total_amount, 0) AS net_sales
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        JOIN public.dim_product_variants pv ON pv.id = t.product_variant_id
        WHERE t.is_current OR t.is_prior
        GROUP BY COALESCE(pv.sku, pv.id)
    ),
    computed AS (
        SELECT ROUND(100 * MAX(cur_net) / NULLIF(SUM(cur_net), 0), 2) AS cur_share,
               ROUND(100 * MAX(prv_net) / NULLIF(SUM(prv_net), 0), 2) AS prv_share
        FROM sku_sales
    )
    SELECT c.prv_share AS previous_value,
           ROUND(100 * (c.cur_share - c.prv_share)
                 / NULLIF(ABS(c.prv_share), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fff82-e31b-7c0c-8f5c-3a2b3c4d100c',
    '01a066fa-17e1-76a4-905d-c947176ef144',
    'gift_card_line_sales',
    $$
    WITH totals AS (
        SELECT COALESCE(SUM(net_sales) FILTER (WHERE is_current AND is_gift_card), 0) AS cur_value,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior   AND is_gift_card), 0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(li.is_giftcard, FALSE) AS is_gift_card,
                   COALESCE(li.discounted_total_amount, 0) AS net_sales
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
    )
    SELECT ROUND(t.prv_value, 2) AS previous_value,
           ROUND(100 * (t.cur_value - t.prv_value)
                 / NULLIF(ABS(t.prv_value), 0), 2) AS divergence
    FROM totals t
    $$
);
