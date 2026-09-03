
-- ---------- 1. charts: value only ----------

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '01a066ff-3220-7568-b6d4-e05b3cb387ea',
    'Total Revenue',
    'Business Performance Overview/Overview/KPI/Total Revenue',
    $$
    SELECT ROUND(COALESCE(SUM(li.original_unit_price * li.quantity), 0), 2) AS total_revenue
    FROM public.fact_order_line_items li
    JOIN public.fact_order_headers o ON o.id = li.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    300,
    'Gross line item revenue before discounts, for the selected period vs the prior period.',
    '{
      "filterMappings": {
        "shopId":          { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"      },
        "userId":          { "source": "AUTH_CONTEXT",   "contextKey": "user_id"      },
        "currentStartDate":{ "source": "REQUEST_FILTER", "filterKey": "startDate"     },
        "currentEndDate":  { "source": "REQUEST_FILTER", "filterKey": "endDate"       },
        "priorStartDate":  { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":    { "source": "REQUEST_FILTER", "filterKey": "prevEndDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '01a066ff-3220-758f-ad5c-b90cb2f64666',
    'Net Sales',
    'Business Performance Overview/Overview/KPI/Net Sales',
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
    300,
    'Net sales (order total less tax and shipping) for the selected period vs the prior period.',
    '{
      "filterMappings": {
        "shopId":          { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"      },
        "userId":          { "source": "AUTH_CONTEXT",   "contextKey": "user_id"      },
        "currentStartDate":{ "source": "REQUEST_FILTER", "filterKey": "startDate"     },
        "currentEndDate":  { "source": "REQUEST_FILTER", "filterKey": "endDate"       },
        "priorStartDate":  { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":    { "source": "REQUEST_FILTER", "filterKey": "prevEndDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '01a066ff-3220-76b5-8e92-7dc335037216',
    'Average Order Value',
    'Business Performance Overview/Overview/KPI/Average Order Value',
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
    300,
    'Average order value (net sales per order) for the selected period vs the prior period.',
    '{
      "filterMappings": {
        "shopId":          { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"      },
        "userId":          { "source": "AUTH_CONTEXT",   "contextKey": "user_id"      },
        "currentStartDate":{ "source": "REQUEST_FILTER", "filterKey": "startDate"     },
        "currentEndDate":  { "source": "REQUEST_FILTER", "filterKey": "endDate"       },
        "priorStartDate":  { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":    { "source": "REQUEST_FILTER", "filterKey": "prevEndDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '01a066ff-3221-7556-9748-cc753f60c76d',
    'Orders',
    'Business Performance Overview/Overview/KPI/Orders',
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
    300,
    'Total order volume for the selected period vs the prior period.',
    '{
      "filterMappings": {
        "shopId":          { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"      },
        "userId":          { "source": "AUTH_CONTEXT",   "contextKey": "user_id"      },
        "currentStartDate":{ "source": "REQUEST_FILTER", "filterKey": "startDate"     },
        "currentEndDate":  { "source": "REQUEST_FILTER", "filterKey": "endDate"       },
        "priorStartDate":  { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":    { "source": "REQUEST_FILTER", "filterKey": "prevEndDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '01a066ff-3221-7ff4-ae68-efc4302669b9',
    'Total Customers',
    'Business Performance Overview/Overview/KPI/Total Customers',
    $$
    SELECT COUNT(DISTINCT o.customer_id) AS total_customers
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    300,
    'Distinct identified customers who ordered in the selected period vs the prior period.',
    '{
      "filterMappings": {
        "shopId":          { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"      },
        "userId":          { "source": "AUTH_CONTEXT",   "contextKey": "user_id"      },
        "currentStartDate":{ "source": "REQUEST_FILTER", "filterKey": "startDate"     },
        "currentEndDate":  { "source": "REQUEST_FILTER", "filterKey": "endDate"       },
        "priorStartDate":  { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":    { "source": "REQUEST_FILTER", "filterKey": "prevEndDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '01a066ff-3221-776b-81f5-871d7efd2380',
    'Inventory Value',
    'Business Performance Overview/Overview/KPI/Inventory Value',
    $$
    SELECT COALESCE(SUM(COALESCE(il.on_hand_quantity, 0)
                        * COALESCE(ii.unit_cost, 0)), 0) AS inventory_value
    FROM public.dim_inventory_levels il
    JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
    WHERE il.seller_id = :shopId
      AND ii.seller_id = :shopId
      AND il.is_active = TRUE
    $$,
    NULL,
    'KPI',
    300,
    'Total capital tied up in on-hand inventory at unit cost.',
    '{
      "filterMappings": {
        "shopId":          { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"      },
        "userId":          { "source": "AUTH_CONTEXT",   "contextKey": "user_id"      },
        "currentStartDate":{ "source": "REQUEST_FILTER", "filterKey": "startDate"     },
        "currentEndDate":  { "source": "REQUEST_FILTER", "filterKey": "endDate"       },
        "priorStartDate":  { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":    { "source": "REQUEST_FILTER", "filterKey": "prevEndDate"   }
      },
      "excludeExtraParams": true
    }'
);

-- ---------- 2. chart signals: divergence ----------

INSERT INTO vizkit.chart_signal (id, chart_id, name, query)
VALUES (
    '019fffa4-0a01-7b01-8c01-0a2b3c4d1001',
    '01a066ff-3220-7568-b6d4-e05b3cb387ea',
    'total_revenue',
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
    '019fffa4-0a01-7b02-8c02-0a2b3c4d1002',
    '01a066ff-3220-758f-ad5c-b90cb2f64666',
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
    '019fffa4-0a01-7b03-8c03-0a2b3c4d1003',
    '01a066ff-3220-76b5-8e92-7dc335037216',
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
    '019fffa4-0a01-7b04-8c04-0a2b3c4d1004',
    '01a066ff-3221-7556-9748-cc753f60c76d',
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
    '019fffa4-0a01-7b05-8c05-0a2b3c4d1005',
    '01a066ff-3221-7ff4-ae68-efc4302669b9',
    'total_customers',
    $$
    WITH order_totals AS (
        SELECT COUNT(DISTINCT customer_id) FILTER (WHERE is_current) AS cur_value,
               COUNT(DISTINCT customer_id) FILTER (WHERE is_prior)   AS prv_value
        FROM (
            SELECT o.customer_id,
                   ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
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
);
