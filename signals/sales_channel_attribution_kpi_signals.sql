
-- ---------- 1. charts: value only ----------

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '01a066fd-afac-7622-ab73-0b0e37a80b05',
    'Total Channel Revenue',
    'Sales Channel Attribution/Channel Performance/KPI/Total Channel Revenue',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(o.current_total_price, 0)
                            - COALESCE(o.current_total_tax, 0)
                            - COALESCE(o.current_shipping_price, 0)), 0), 2) AS total_channel_revenue
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Net sales across all sales channels for the selected period vs the prior period.',
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
    '01a066fd-afac-7e68-a78a-7a23a4f4ca1c',
    'Channel Orders',
    'Sales Channel Attribution/Channel Performance/KPI/Channel Orders',
    $$
    SELECT COUNT(*) AS channel_orders
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Order volume across all sales channels for the selected period vs the prior period.',
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
    '01a066fd-afac-71ff-87c5-5ba7788f23b7',
    'Channel AOV',
    'Sales Channel Attribution/Channel Performance/KPI/Channel AOV',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(o.current_total_price, 0)
                            - COALESCE(o.current_total_tax, 0)
                            - COALESCE(o.current_shipping_price, 0)), 0)
                 / NULLIF(COUNT(*), 0), 2) AS channel_aov
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Average order value across all channels for the selected period vs the prior period.',
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
    '01a066fd-afad-7274-9b32-2b2c56f24ad2',
    'Top Revenue Channel',
    'Sales Channel Attribution/Channel Performance/KPI/Top Revenue Channel',
    $$
    WITH channel_current AS (
        SELECT COALESCE(o.attribution_displayname,
                        o.order_app_name,
                        o.source_name,
                        'Unattributed') AS channel,
               SUM(COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0)) AS net_sales
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY 1
    )
    SELECT COALESCE((SELECT channel FROM channel_current
                     ORDER BY net_sales DESC NULLS LAST, channel ASC
                     LIMIT 1), 'No data') AS top_revenue_channel
    $$,
    NULL,
    'KPI',
    60,
    'Sales channel with the highest net sales in the selected period.',
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
    '01a066fd-afad-74f0-9cf3-a1e9bf4f1dde',
    'Top AOV Channel',
    'Sales Channel Attribution/Channel Performance/KPI/Top AOV Channel',
    $$
    WITH channel_current AS (
        SELECT COALESCE(o.attribution_displayname,
                        o.order_app_name,
                        o.source_name,
                        'Unattributed') AS channel,
               SUM(COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0))
                 / NULLIF(COUNT(*), 0) AS aov
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY 1
    )
    SELECT COALESCE((SELECT channel FROM channel_current
                     ORDER BY aov DESC NULLS LAST, channel ASC
                     LIMIT 1), 'No data') AS top_aov_channel
    $$,
    NULL,
    'KPI',
    60,
    'Sales channel with the highest average order value in the selected period.',
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
    '01a066fd-afaf-7563-9850-9601e44abdf3',
    'Net Revenue After Refunds',
    'Sales Channel Attribution/Channel Quality & Profitability/KPI/Net Revenue After Refunds',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(o.current_total_price, 0)
                            - COALESCE(o.current_total_tax, 0)
                            - COALESCE(o.current_shipping_price, 0)), 0), 2)
           AS net_revenue_after_refunds
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Net sales after refunds for the selected period vs the prior period.',
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
    '01a066fd-afaf-7028-be5d-39aafa87d673',
    'Channel Refund Rate',
    'Sales Channel Attribution/Channel Quality & Profitability/KPI/Channel Refund Rate',
    $$
    WITH scoped_orders AS (
        SELECT o.id,
               COALESCE(o.subtotal_price, 0) + COALESCE(o.total_discounts_amount, 0) AS gross_sales
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    order_totals AS (
        SELECT COALESCE(SUM(gross_sales), 0) AS gross FROM scoped_orders
    ),
    refund_totals AS (
        SELECT COALESCE(SUM(COALESCE(r.total_refunded_amount, 0)), 0) AS refunded
        FROM public.fact_order_refunds r
        JOIN scoped_orders s ON s.id = r.order_id
    )
    SELECT ROUND(100 * rt.refunded / NULLIF(ot.gross, 0), 2) AS channel_refund_rate
    FROM order_totals ot
    CROSS JOIN refund_totals rt
    $$,
    NULL,
    'KPI',
    60,
    'Refunds as a percentage of gross sales for the selected period vs the prior period.',
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
    '01a066fd-afaf-7f08-aaf1-445483a0784f',
    'Channel Discount Rate',
    'Sales Channel Attribution/Channel Quality & Profitability/KPI/Channel Discount Rate',
    $$
    SELECT ROUND(100 * COALESCE(SUM(COALESCE(o.total_discounts_amount, 0)), 0)
                 / NULLIF(COALESCE(SUM(COALESCE(o.subtotal_price, 0)
                                     + COALESCE(o.total_discounts_amount, 0)), 0), 0), 2)
           AS channel_discount_rate
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Discounts as a percentage of gross sales for the selected period vs the prior period.',
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
    '01a066fd-afb0-7fbe-9777-56bcb916d543',
    'UTM Revenue',
    'Sales Channel Attribution/Marketing Attribution/KPI/UTM Revenue',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(o.current_total_price, 0)
                            - COALESCE(o.current_total_tax, 0)
                            - COALESCE(o.current_shipping_price, 0)), 0), 2) AS utm_revenue
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (NULLIF(TRIM(o.customer_journey_summary #>> '{lastVisit,utmParameters,source}'), '') IS NOT NULL
        OR NULLIF(TRIM(o.customer_journey_summary #>> '{lastVisit,utmParameters,medium}'), '') IS NOT NULL
        OR NULLIF(TRIM(o.customer_journey_summary #>> '{lastVisit,utmParameters,campaign}'), '') IS NOT NULL)
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Net sales from UTM-tagged orders for the selected period vs the prior period.',
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
    '01a066fd-afb0-7d9c-947f-eb70e4b5713d',
    'UTM AOV',
    'Sales Channel Attribution/Marketing Attribution/KPI/UTM AOV',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(o.current_total_price, 0)
                            - COALESCE(o.current_total_tax, 0)
                            - COALESCE(o.current_shipping_price, 0)), 0)
                 / NULLIF(COUNT(*), 0), 2) AS utm_aov
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (NULLIF(TRIM(o.customer_journey_summary #>> '{lastVisit,utmParameters,source}'), '') IS NOT NULL
        OR NULLIF(TRIM(o.customer_journey_summary #>> '{lastVisit,utmParameters,medium}'), '') IS NOT NULL
        OR NULLIF(TRIM(o.customer_journey_summary #>> '{lastVisit,utmParameters,campaign}'), '') IS NOT NULL)
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Average order value of UTM-tagged orders for the selected period vs the prior period.',
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
    '01a066fd-afb0-7b96-95b0-c8c3d55bbec3',
    'Referral Revenue',
    'Sales Channel Attribution/Marketing Attribution/KPI/Referral Revenue',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(o.current_total_price, 0)
                            - COALESCE(o.current_total_tax, 0)
                            - COALESCE(o.current_shipping_price, 0)), 0), 2) AS referral_revenue
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND o.customer_journey_summary #>> '{lastVisit,referrerUrl}' IS NOT NULL
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Net sales from orders with a referring site for the selected period vs the prior period.',
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
    '01a066fd-afb1-7b89-adf5-f12628dbc974',
    'Paid Revenue Share',
    'Sales Channel Attribution/Marketing Attribution/KPI/Paid Revenue Share',
    $$
    WITH classified AS (
        SELECT COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales,
               LOWER(NULLIF(TRIM(o.customer_journey_summary #>> '{lastVisit,utmParameters,medium}'), ''))
                 IN ('cpc', 'ppc', 'paid', 'paidsearch', 'paid_search',
                     'paid-search', 'cpm', 'cpv', 'display', 'banner',
                     'retargeting') AS is_paid
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT COALESCE(ROUND(100 * COALESCE(SUM(net_sales) FILTER (WHERE is_paid), 0)
                          / NULLIF(COALESCE(SUM(net_sales), 0), 0), 2), 0) AS paid_revenue_share
    FROM classified
    $$,
    NULL,
    'KPI',
    60,
    'Paid media net sales as a percentage of total net sales, for the selected period vs the prior period.',
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
    '01a066fd-afb2-7213-8945-c5ce7d0ab71f',
    'Orders Without Attribution',
    'Sales Channel Attribution/Attribution Health/KPI/Orders Without Attribution',
    $$
    SELECT COUNT(*) AS orders_without_attribution
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND ((NULLIF(TRIM(o.customer_journey_summary #>> '{lastVisit,utmParameters,source}'), '') IS NULL
        AND NULLIF(TRIM(o.customer_journey_summary #>> '{lastVisit,utmParameters,medium}'), '') IS NULL
        AND NULLIF(TRIM(o.customer_journey_summary #>> '{lastVisit,utmParameters,campaign}'), '') IS NULL)
        OR o.customer_journey_summary #>> '{lastVisit,referrerUrl}' IS NULL
        OR (o.attribution_displayname IS NULL
        AND o.order_app_id IS NULL
        AND NULLIF(TRIM(o.source_name), '') IS NULL))
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Orders missing UTM, referrer, or channel attribution for the selected period vs the prior period.',
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
    '01a066fd-afb3-7a51-941d-d59484127990',
    'Channel Tax Collected',
    'Sales Channel Attribution/Operations & Fulfillment/KPI/Channel Tax Collected',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(o.current_total_tax, 0)), 0), 2) AS channel_tax_collected
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Tax collected across all channels for the selected period vs the prior period.',
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
    '01a066fd-afb3-7015-a8d7-4bb3b1b69458',
    'Channel Fulfillment Risk',
    'Sales Channel Attribution/Operations & Fulfillment/KPI/Channel Fulfillment Risk',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(li.unfulfilled_discounted_total_amount, 0)), 0), 2)
           AS channel_fulfillment_risk
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
    'Unfulfilled order value at risk for the selected period vs the prior period.',
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
    '019fffa2-0f81-7b01-8fd1-7a2b3c4d1001',
    '01a066fd-afac-7622-ab73-0b0e37a80b05',
    'total_channel_revenue',
    $$
    WITH order_totals AS (
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
        ) t
        WHERE t.is_current OR t.is_prior
    )
    SELECT ROUND(ot.prv_value, 2) AS previous_value,
           ROUND(100 * (ot.cur_value - ot.prv_value)
                 / NULLIF(ABS(ot.prv_value), 0), 2) AS divergence
    FROM order_totals ot
    $$
),
(
    '019fffa2-0f81-7b02-8fd2-7a2b3c4d1002',
    '01a066fd-afac-7e68-a78a-7a23a4f4ca1c',
    'channel_orders',
    $$
    WITH order_totals AS (
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
        ) t
        WHERE t.is_current OR t.is_prior
    )
    SELECT ot.prv_value AS previous_value,
           ROUND(100.0 * (ot.cur_value - ot.prv_value)
                 / NULLIF(ABS(ot.prv_value), 0), 2) AS divergence
    FROM order_totals ot
    $$
),
(
    '019fffa2-0f81-7b03-8fd3-7a2b3c4d1003',
    '01a066fd-afac-71ff-87c5-5ba7788f23b7',
    'channel_aov',
    $$
    WITH order_totals AS (
        SELECT COALESCE(SUM(net_sales) FILTER (WHERE is_current), 0) AS cur_net_sales,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior),   0) AS prv_net_sales,
               COUNT(*) FILTER (WHERE is_current) AS cur_orders,
               COUNT(*) FILTER (WHERE is_prior)   AS prv_orders
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
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    computed AS (
        SELECT ROUND(ot.cur_net_sales / NULLIF(ot.cur_orders, 0), 2) AS cur_aov,
               ROUND(ot.prv_net_sales / NULLIF(ot.prv_orders, 0), 2) AS prv_aov
        FROM order_totals ot
    )
    SELECT c.prv_aov AS previous_value,
           ROUND(100 * (c.cur_aov - c.prv_aov)
                 / NULLIF(ABS(c.prv_aov), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fffa2-0f81-7b04-8fd4-7a2b3c4d1004',
    '01a066fd-afaf-7563-9850-9601e44abdf3',
    'net_revenue_after_refunds',
    $$
    WITH order_totals AS (
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
        ) t
        WHERE t.is_current OR t.is_prior
    )
    SELECT ROUND(ot.prv_value, 2) AS previous_value,
           ROUND(100 * (ot.cur_value - ot.prv_value)
                 / NULLIF(ABS(ot.prv_value), 0), 2) AS divergence
    FROM order_totals ot
    $$
),
(
    '019fffa2-0f81-7b05-8fd5-7a2b3c4d1005',
    '01a066fd-afaf-7028-be5d-39aafa87d673',
    'channel_refund_rate',
    $$
    WITH scoped_orders AS (
        SELECT * FROM (
            SELECT o.id,
                   ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(o.subtotal_price, 0) + COALESCE(o.total_discounts_amount, 0) AS gross_sales
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    order_totals AS (
        SELECT COALESCE(SUM(gross_sales) FILTER (WHERE is_current), 0) AS cur_gross,
               COALESCE(SUM(gross_sales) FILTER (WHERE is_prior),   0) AS prv_gross
        FROM scoped_orders
    ),
    refund_totals AS (
        SELECT COALESCE(SUM(COALESCE(r.total_refunded_amount, 0))
                        FILTER (WHERE s.is_current), 0) AS cur_refunded,
               COALESCE(SUM(COALESCE(r.total_refunded_amount, 0))
                        FILTER (WHERE s.is_prior),   0) AS prv_refunded
        FROM public.fact_order_refunds r
        JOIN scoped_orders s ON s.id = r.order_id
    ),
    computed AS (
        SELECT ROUND(100 * rt.cur_refunded / NULLIF(ot.cur_gross, 0), 2) AS cur_rate,
               ROUND(100 * rt.prv_refunded / NULLIF(ot.prv_gross, 0), 2) AS prv_rate
        FROM order_totals ot
        CROSS JOIN refund_totals rt
    )
    SELECT c.prv_rate AS previous_value,
           ROUND(100 * (c.cur_rate - c.prv_rate)
                 / NULLIF(ABS(c.prv_rate), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fffa2-0f81-7b06-8fd6-7a2b3c4d1006',
    '01a066fd-afaf-7f08-aaf1-445483a0784f',
    'channel_discount_rate',
    $$
    WITH order_totals AS (
        SELECT COALESCE(SUM(gross_sales) FILTER (WHERE is_current), 0) AS cur_gross,
               COALESCE(SUM(gross_sales) FILTER (WHERE is_prior),   0) AS prv_gross,
               COALESCE(SUM(discounts) FILTER (WHERE is_current), 0) AS cur_discounts,
               COALESCE(SUM(discounts) FILTER (WHERE is_prior),   0) AS prv_discounts
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(o.subtotal_price, 0) + COALESCE(o.total_discounts_amount, 0) AS gross_sales,
                   COALESCE(o.total_discounts_amount, 0) AS discounts
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    computed AS (
        SELECT ROUND(100 * ot.cur_discounts / NULLIF(ot.cur_gross, 0), 2) AS cur_rate,
               ROUND(100 * ot.prv_discounts / NULLIF(ot.prv_gross, 0), 2) AS prv_rate
        FROM order_totals ot
    )
    SELECT c.prv_rate AS previous_value,
           ROUND(100 * (c.cur_rate - c.prv_rate)
                 / NULLIF(ABS(c.prv_rate), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fffa2-0f81-7b07-8fd7-7a2b3c4d1007',
    '01a066fd-afb0-7fbe-9777-56bcb916d543',
    'utm_revenue',
    $$
    WITH totals AS (
        SELECT COALESCE(SUM(net_sales) FILTER (WHERE is_current AND has_utm), 0) AS cur_value,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior   AND has_utm), 0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   (NULLIF(TRIM(o.customer_journey_summary #>> '{lastVisit,utmParameters,source}'), '') IS NOT NULL
                 OR NULLIF(TRIM(o.customer_journey_summary #>> '{lastVisit,utmParameters,medium}'), '') IS NOT NULL
                 OR NULLIF(TRIM(o.customer_journey_summary #>> '{lastVisit,utmParameters,campaign}'), '') IS NOT NULL) AS has_utm,
                   COALESCE(o.current_total_price, 0)
                     - COALESCE(o.current_total_tax, 0)
                     - COALESCE(o.current_shipping_price, 0) AS net_sales
            FROM public.fact_order_headers o
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
    '019fffa2-0f81-7b08-8fd8-7a2b3c4d1008',
    '01a066fd-afb0-7d9c-947f-eb70e4b5713d',
    'utm_aov',
    $$
    WITH totals AS (
        SELECT COALESCE(SUM(net_sales) FILTER (WHERE is_current AND has_utm), 0) AS cur_rev,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior   AND has_utm), 0) AS prv_rev,
               COUNT(*) FILTER (WHERE is_current AND has_utm) AS cur_orders,
               COUNT(*) FILTER (WHERE is_prior   AND has_utm) AS prv_orders
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   (NULLIF(TRIM(o.customer_journey_summary #>> '{lastVisit,utmParameters,source}'), '') IS NOT NULL
                 OR NULLIF(TRIM(o.customer_journey_summary #>> '{lastVisit,utmParameters,medium}'), '') IS NOT NULL
                 OR NULLIF(TRIM(o.customer_journey_summary #>> '{lastVisit,utmParameters,campaign}'), '') IS NOT NULL) AS has_utm,
                   COALESCE(o.current_total_price, 0)
                     - COALESCE(o.current_total_tax, 0)
                     - COALESCE(o.current_shipping_price, 0) AS net_sales
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    computed AS (
        SELECT ROUND(t.cur_rev / NULLIF(t.cur_orders, 0), 2) AS cur_aov,
               ROUND(t.prv_rev / NULLIF(t.prv_orders, 0), 2) AS prv_aov
        FROM totals t
    )
    SELECT c.prv_aov AS previous_value,
           ROUND(100 * (c.cur_aov - c.prv_aov)
                 / NULLIF(ABS(c.prv_aov), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fffa2-0f81-7b09-8fd9-7a2b3c4d1009',
    '01a066fd-afb0-7b96-95b0-c8c3d55bbec3',
    'referral_revenue',
    $$
    WITH totals AS (
        SELECT COALESCE(SUM(net_sales) FILTER (WHERE is_current AND has_referral), 0) AS cur_value,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior   AND has_referral), 0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   (o.customer_journey_summary #>> '{lastVisit,referrerUrl}' IS NOT NULL) AS has_referral,
                   COALESCE(o.current_total_price, 0)
                     - COALESCE(o.current_total_tax, 0)
                     - COALESCE(o.current_shipping_price, 0) AS net_sales
            FROM public.fact_order_headers o
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
    '019fffa2-0f81-7b0a-8fda-7a2b3c4d100a',
    '01a066fd-afb1-7b89-adf5-f12628dbc974',
    'paid_revenue_share',
    $$
    WITH totals AS (
        SELECT COALESCE(SUM(net_sales) FILTER (WHERE is_current AND is_paid), 0) AS cur_paid,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior   AND is_paid), 0) AS prv_paid,
               COALESCE(SUM(net_sales) FILTER (WHERE is_current), 0) AS cur_total,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior),   0) AS prv_total
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   LOWER(NULLIF(TRIM(o.customer_journey_summary #>> '{lastVisit,utmParameters,medium}'), ''))
                     IN ('cpc', 'ppc', 'paid', 'paidsearch', 'paid_search',
                         'paid-search', 'cpm', 'cpv', 'display', 'banner',
                         'retargeting') AS is_paid,
                   COALESCE(o.current_total_price, 0)
                     - COALESCE(o.current_total_tax, 0)
                     - COALESCE(o.current_shipping_price, 0) AS net_sales
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    computed AS (
        SELECT ROUND(100 * t.cur_paid / NULLIF(t.cur_total, 0), 2) AS cur_share,
               ROUND(100 * t.prv_paid / NULLIF(t.prv_total, 0), 2) AS prv_share
        FROM totals t
    )
    SELECT c.prv_share AS previous_value,
           ROUND(100 * (c.cur_share - c.prv_share)
                 / NULLIF(ABS(c.prv_share), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fffa2-0f81-7b0b-8fdb-7a2b3c4d100b',
    '01a066fd-afb2-7213-8945-c5ce7d0ab71f',
    'orders_without_attribution',
    $$
    WITH totals AS (
        SELECT COUNT(*) FILTER (WHERE is_current
                            AND (missing_utm OR missing_referring_site OR missing_channel)) AS cur_value,
               COUNT(*) FILTER (WHERE is_prior
                            AND (missing_utm OR missing_referring_site OR missing_channel)) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   (NULLIF(TRIM(o.customer_journey_summary #>> '{lastVisit,utmParameters,source}'), '') IS NULL
                AND NULLIF(TRIM(o.customer_journey_summary #>> '{lastVisit,utmParameters,medium}'), '') IS NULL
                AND NULLIF(TRIM(o.customer_journey_summary #>> '{lastVisit,utmParameters,campaign}'), '') IS NULL) AS missing_utm,
                   (o.customer_journey_summary #>> '{lastVisit,referrerUrl}' IS NULL) AS missing_referring_site,
                   (o.attribution_displayname IS NULL
                AND o.order_app_id IS NULL
                AND NULLIF(TRIM(o.source_name), '') IS NULL) AS missing_channel
            FROM public.fact_order_headers o
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
    '019fffa2-0f81-7b0c-8fdc-7a2b3c4d100c',
    '01a066fd-afb3-7a51-941d-d59484127990',
    'channel_tax_collected',
    $$
    WITH tax_totals AS (
        SELECT COALESCE(SUM(tax) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(tax) FILTER (WHERE is_prior),   0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(o.current_total_tax, 0) AS tax
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
    )
    SELECT ROUND(t.prv_value, 2) AS previous_value,
           ROUND(100 * (t.cur_value - t.prv_value)
                 / NULLIF(ABS(t.prv_value), 0), 2) AS divergence
    FROM tax_totals t
    $$
),
(
    '019fffa2-0f81-7b0d-8fdd-7a2b3c4d100d',
    '01a066fd-afb3-7015-a8d7-4bb3b1b69458',
    'channel_fulfillment_risk',
    $$
    WITH unfulfilled_totals AS (
        SELECT COALESCE(SUM(COALESCE(li.unfulfilled_discounted_total_amount, 0))
                        FILTER (WHERE t.is_current), 0) AS cur_value,
               COALESCE(SUM(COALESCE(li.unfulfilled_discounted_total_amount, 0))
                        FILTER (WHERE t.is_prior),   0) AS prv_value
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
    SELECT ROUND(u.prv_value, 2) AS previous_value,
           ROUND(100 * (u.cur_value - u.prv_value)
                 / NULLIF(ABS(u.prv_value), 0), 2) AS divergence
    FROM unfulfilled_totals u
    $$
);
