INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '01a066f6-d33f-72a8-a617-bfb9c970d293',
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
    '01a066f6-d33f-76d1-987d-ac75dd8adcbf',
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
    '01a066f6-d33f-72bd-9ebc-8935c54853c0',
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
    '01a066f6-d33f-788f-8c25-b3df63a94137',
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
    '01a066f6-d340-7816-ba64-4eb04c76008e',
    'Refunded Amount',
    'Executive Store Health/Discount & Refund/KPI/Refunded Amount',
    $$
    SELECT ROUND(COALESCE(SUM(r.total_refunded_amount), 0), 2) AS refunded_amount
    FROM public.fact_order_refunds r
    JOIN public.fact_order_headers o ON o.id = r.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL OR r.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR r.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Total amount refunded for the selected period vs the prior period.',
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
    '01a066f6-d340-7fae-bf60-8ff352c35d84',
    'Refund Rate',
    'Executive Store Health/Discount & Refund/KPI/Refund Rate',
    $$
    WITH refund_totals AS (
        SELECT COALESCE(SUM(r.total_refunded_amount), 0) AS refunded
        FROM public.fact_order_refunds r
        JOIN public.fact_order_headers o ON o.id = r.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (:currentStartDate::date IS NULL OR r.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR r.created_at::date <= :currentEndDate::date)
    ),
    line_item_totals AS (
        SELECT COALESCE(SUM(li.original_unit_price * li.quantity), 0) AS gross_sales
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT ROUND(100 * rt.refunded / NULLIF(lt.gross_sales, 0), 2) AS refund_rate
    FROM refund_totals rt
    CROSS JOIN line_item_totals lt
    $$,
    NULL,
    'KPI',
    60,
    'Refunded amount as a percentage of gross sales for the selected period vs the prior period.',
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
    '01a066f6-d340-7390-80ca-c5e231f32816',
    'Discount Leakage',
    'Executive Store Health/Discount & Refund/KPI/Discount Leakage',
    $$
    SELECT ROUND(100 * COALESCE(SUM(li.total_discount_amount), 0)
                 / NULLIF(COALESCE(SUM(li.original_unit_price * li.quantity), 0), 0), 2) AS discount_leakage
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
    'Discounts as a percentage of gross sales for the selected period vs the prior period.',
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
    '01a066f6-d340-754c-9169-d19327a433d9',
    'Low Stock Revenue Risk',
    'Executive Store Health/Inventory & Operations/KPI/Low Stock Revenue Risk',
    $$
    WITH scoped_orders AS (
        SELECT o.id,
               o.created_at::date AS day
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    period AS (
        SELECT GREATEST(COALESCE(:currentEndDate::date,   (SELECT MAX(day) FROM scoped_orders))
                      - COALESCE(:currentStartDate::date, (SELECT MIN(day) FROM scoped_orders))
                      + 1, 1) AS days
    ),
    variant_sales AS (
        SELECT li.product_variant_id AS variant_id,
               COALESCE(SUM(li.quantity), 0) AS units,
               COALESCE(SUM(li.original_unit_price * li.quantity), 0) AS revenue
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
    )
    SELECT ROUND(COALESCE(SUM(vs.revenue) FILTER (
                     WHERE st.available / NULLIF(vs.units::numeric / p.days, 0) < 14), 0), 2)
           AS low_stock_revenue_risk
    FROM variant_sales vs
    JOIN variant_stock st ON st.variant_id = vs.variant_id
    CROSS JOIN period p
    $$,
    NULL,
    'KPI',
    60,
    'Revenue from variants with under 14 days of stock cover, for the selected period vs the prior period.',
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
    '01a066f6-d340-7bb4-aae6-6e1ce9936068',
    'Outstanding Amount',
    'Executive Store Health/Inventory & Operations/KPI/Outstanding Amount',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(o.total_outstanding_amount, 0)), 0), 2) AS outstanding_amount
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Total outstanding unpaid order balances for the selected period vs the prior period.',
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
    '01a066f6-d342-7ebe-9a07-3d54624dafce',
    'Gross Margin Estimate',
    'Executive Store Health/Payment & Business Risk/KPI/Gross Margin Estimate',
    $$
    WITH scoped_orders AS (
        SELECT o.id,
               COALESCE(o.current_total_price, 0)
                 - COALESCE(o.current_total_tax, 0)
                 - COALESCE(o.current_shipping_price, 0) AS net_sales
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
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
        SELECT COALESCE(SUM(net_sales), 0) AS net_sales
        FROM scoped_orders
    ),
    cogs_totals AS (
        SELECT COALESCE(SUM(li.quantity * vc.unit_cost), 0) AS cogs
        FROM public.fact_order_line_items li
        JOIN scoped_orders s ON s.id = li.order_id
        LEFT JOIN variant_cost vc ON vc.variant_id = li.product_variant_id
    )
    SELECT ROUND(ot.net_sales - ct.cogs, 2) AS gross_margin_estimate
    FROM order_totals ot
    CROSS JOIN cogs_totals ct
    $$,
    NULL,
    'KPI',
    60,
    'Estimated gross margin (net sales less COGS) for the selected period vs the prior period.',
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
);

-- ---------- 2. chart signals: divergence ----------

INSERT INTO vizkit.chart_signal (id, chart_id, name, query)
VALUES (
    '019fff82-e31a-7b01-8f11-1a2b3c4d1001',
    '01a066f6-d33f-72a8-a617-bfb9c970d293',
    'net_sales',
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
    '019fff82-e31a-7b02-8f12-1a2b3c4d1002',
    '01a066f6-d33f-76d1-987d-ac75dd8adcbf',
    'gross_sales',
    $$
    WITH line_item_totals AS (
        SELECT COALESCE(SUM(li.original_unit_price * li.quantity)
                        FILTER (WHERE t.is_current), 0) AS cur_value,
               COALESCE(SUM(li.original_unit_price * li.quantity)
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
    SELECT ROUND(lt.prv_value, 2) AS previous_value,
           ROUND(100 * (lt.cur_value - lt.prv_value)
                 / NULLIF(ABS(lt.prv_value), 0), 2) AS divergence
    FROM line_item_totals lt
    $$
),
(
    '019fff82-e31a-7b03-8f13-1a2b3c4d1003',
    '01a066f6-d33f-72bd-9ebc-8935c54853c0',
    'orders',
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
    '019fff82-e31a-7b04-8f14-1a2b3c4d1004',
    '01a066f6-d33f-788f-8c25-b3df63a94137',
    'average_order_value',
    $$
    WITH order_totals AS (
        SELECT COUNT(*) FILTER (WHERE is_current) AS cur_orders,
               COUNT(*) FILTER (WHERE is_prior)   AS prv_orders,
               COALESCE(SUM(net_sales) FILTER (WHERE is_current), 0) AS cur_net_sales,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior),   0) AS prv_net_sales
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
    '019fff82-e31a-7b05-8f15-1a2b3c4d1005',
    '01a066f6-d340-7816-ba64-4eb04c76008e',
    'refunded_amount',
    $$
    WITH refund_totals AS (
        SELECT COALESCE(SUM(amount) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(amount) FILTER (WHERE is_prior),   0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR r.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR r.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND r.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
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
    '019fff82-e31a-7b06-8f16-1a2b3c4d1006',
    '01a066f6-d340-7fae-bf60-8ff352c35d84',
    'refund_rate',
    $$
    WITH refund_totals AS (
        SELECT COALESCE(SUM(amount) FILTER (WHERE is_current), 0) AS cur_refunded,
               COALESCE(SUM(amount) FILTER (WHERE is_prior),   0) AS prv_refunded
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR r.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR r.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND r.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(r.total_refunded_amount, 0) AS amount
            FROM public.fact_order_refunds r
            JOIN public.fact_order_headers o ON o.id = r.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    line_item_totals AS (
        SELECT COALESCE(SUM(li.original_unit_price * li.quantity)
                        FILTER (WHERE t.is_current), 0) AS cur_gross_sales,
               COALESCE(SUM(li.original_unit_price * li.quantity)
                        FILTER (WHERE t.is_prior),   0) AS prv_gross_sales
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
        SELECT ROUND(100 * rt.cur_refunded / NULLIF(lt.cur_gross_sales, 0), 2) AS cur_rate,
               ROUND(100 * rt.prv_refunded / NULLIF(lt.prv_gross_sales, 0), 2) AS prv_rate
        FROM refund_totals rt
        CROSS JOIN line_item_totals lt
    )
    SELECT c.prv_rate AS previous_value,
           ROUND(100 * (c.cur_rate - c.prv_rate)
                 / NULLIF(ABS(c.prv_rate), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fff82-e31a-7b07-8f17-1a2b3c4d1007',
    '01a066f6-d340-7390-80ca-c5e231f32816',
    'discount_leakage',
    $$
    WITH line_item_totals AS (
        SELECT COALESCE(SUM(li.total_discount_amount)
                        FILTER (WHERE t.is_current), 0) AS cur_discounts,
               COALESCE(SUM(li.total_discount_amount)
                        FILTER (WHERE t.is_prior),   0) AS prv_discounts,
               COALESCE(SUM(li.original_unit_price * li.quantity)
                        FILTER (WHERE t.is_current), 0) AS cur_gross_sales,
               COALESCE(SUM(li.original_unit_price * li.quantity)
                        FILTER (WHERE t.is_prior),   0) AS prv_gross_sales
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
        SELECT ROUND(100 * lt.cur_discounts / NULLIF(lt.cur_gross_sales, 0), 2) AS cur_leakage,
               ROUND(100 * lt.prv_discounts / NULLIF(lt.prv_gross_sales, 0), 2) AS prv_leakage
        FROM line_item_totals lt
    )
    SELECT c.prv_leakage AS previous_value,
           ROUND(100 * (c.cur_leakage - c.prv_leakage)
                 / NULLIF(ABS(c.prv_leakage), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fff82-e31a-7b08-8f18-1a2b3c4d1008',
    '01a066f6-d340-754c-9169-d19327a433d9',
    'low_stock_revenue_risk',
    $$
    WITH scoped_orders AS (
        SELECT * FROM (
            SELECT o.id,
                   o.created_at::date AS day,
                   ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    period AS (
        SELECT GREATEST(COALESCE(:currentEndDate::date,   (SELECT MAX(day) FROM scoped_orders WHERE is_current))
                      - COALESCE(:currentStartDate::date, (SELECT MIN(day) FROM scoped_orders WHERE is_current))
                      + 1, 1) AS cur_days,
               GREATEST(:priorEndDate::date - :priorStartDate::date + 1, 1) AS prv_days
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
        SELECT COALESCE(SUM(cur_revenue) FILTER (WHERE cur_cover < 14), 0) AS cur_value,
               COALESCE(SUM(prv_revenue) FILTER (WHERE prv_cover < 14), 0) AS prv_value
        FROM variant_risk
    )
    SELECT ROUND(rt.prv_value, 2) AS previous_value,
           ROUND(100 * (rt.cur_value - rt.prv_value)
                 / NULLIF(ABS(rt.prv_value), 0), 2) AS divergence
    FROM risk_totals rt
    $$
),
(
    '019fff82-e31a-7b09-8f19-1a2b3c4d1009',
    '01a066f6-d340-7bb4-aae6-6e1ce9936068',
    'outstanding_amount',
    $$
    WITH outstanding_totals AS (
        SELECT COALESCE(SUM(outstanding) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(outstanding) FILTER (WHERE is_prior),   0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(o.total_outstanding_amount, 0) AS outstanding
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
    )
    SELECT ROUND(ot.prv_value, 2) AS previous_value,
           ROUND(100 * (ot.cur_value - ot.prv_value)
                 / NULLIF(ABS(ot.prv_value), 0), 2) AS divergence
    FROM outstanding_totals ot
    $$
),
(
    '019fff82-e31a-7b0a-8f1a-1a2b3c4d100a',
    '01a066f6-d342-7ebe-9a07-3d54624dafce',
    'gross_margin_estimate',
    $$
    WITH scoped_orders AS (
        SELECT * FROM (
            SELECT o.id,
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
    SELECT ROUND(c.prv_margin, 2) AS previous_value,
           ROUND(100 * (c.cur_margin - c.prv_margin)
                 / NULLIF(ABS(c.prv_margin), 0), 2) AS divergence
    FROM computed c
    $$
);
