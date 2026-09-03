-- ---------- 1. charts: value only ----------

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '01a066fc-a9b9-753a-877f-f49b74366a3b',
    'Net Sales',
    'Order Reports/Sales & Revenue/KPI/Net Sales',
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
    '01a066fc-a9b9-7a9c-bce8-8179fd07b051',
    'Gross Sales',
    'Order Reports/Sales & Revenue/KPI/Gross Sales',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(o.subtotal_price, 0)
                            + COALESCE(o.total_discounts_amount, 0)), 0), 2) AS gross_sales
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Gross sales (subtotal before discounts) for the selected period vs the prior period.',
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
    '01a066fc-a9ba-7c66-bb34-708bcd948a61',
    'Average Order Value',
    'Order Reports/Sales & Revenue/KPI/Average Order Value',
    $$
    SELECT ROUND(COALESCE(COALESCE(SUM(COALESCE(o.current_total_price, 0)
                                     - COALESCE(o.current_total_tax, 0)
                                     - COALESCE(o.current_shipping_price, 0)), 0)
                          / NULLIF(COUNT(*), 0), 0), 2) AS average_order_value
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
    '01a066fc-a9ba-7fc0-a00d-7778344ae6b0',
    'Discount Amount',
    'Order Reports/Sales & Revenue/KPI/Discount Amount',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(o.total_discounts_amount, 0)), 0), 2) AS discount_amount
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Total discounts applied for the selected period vs the prior period.',
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
    '01a066fc-a9ba-7bec-9612-640941cda264',
    'Refunded Order Value',
    'Order Reports/Sales & Revenue/KPI/Refunded Order Value',
    $$
    SELECT ROUND(COALESCE(SUM(r.total_refunded_amount), 0), 2) AS refunded_order_value
    FROM public.fact_order_refunds r
    JOIN public.fact_order_headers o ON o.id = r.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Refunded value on orders placed in the selected period vs the prior period.',
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
    '01a066fc-a9ba-7e43-bd9c-fc29b7879642',
    'Tax Collected',
    'Order Reports/Sales & Revenue/KPI/Tax Collected',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(o.current_total_tax, 0)), 0), 2) AS tax_collected
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Total tax collected for the selected period vs the prior period.',
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
    '01a066fc-a9bb-70d2-8554-8a69d923b309',
    'Total Orders',
    'Order Reports/Orders & Fulfillment/KPI/Total Orders',
    $$
    SELECT COUNT(*) AS total_orders
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
    '01a066fc-a9bb-7a4b-8e08-2ac2c37e556f',
    'Fulfillment Pending Orders',
    'Order Reports/Orders & Fulfillment/KPI/Fulfillment Pending Orders',
    $$
    SELECT COUNT(*) AS fulfillment_pending_orders
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND UPPER(o.fulfillmentStatus) IS DISTINCT FROM 'FULFILLED'
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Orders not yet fulfilled for the selected period vs the prior period.',
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
    '01a066fc-a9bc-7ad0-b589-6ef07964b7b3',
    'Cancelled Orders',
    'Order Reports/Orders & Fulfillment/KPI/Cancelled Orders',
    $$
    SELECT COUNT(*) AS cancelled_orders
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND o.cancelled_at IS NOT NULL
      AND (:currentStartDate::date IS NULL OR o.cancelled_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.cancelled_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Orders cancelled in the selected period vs the prior period.',
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
    '01a066fc-a9bc-79c2-8074-c6911364c32e',
    'Outstanding Amount',
    'Order Reports/Payments & Collections/KPI/Outstanding Amount',
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
    'Total unpaid outstanding order balance for the selected period vs the prior period.',
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
    '01a066fc-a9bc-71e7-ab1a-0109d09923fe',
    'Paid Order Rate',
    'Order Reports/Payments & Collections/KPI/Paid Order Rate',
    $$
    SELECT ROUND(COALESCE(100.0 * COUNT(*) FILTER (WHERE UPPER(o.financialstatus) = 'PAID')
                          / NULLIF(COUNT(*), 0), 0), 2) AS paid_order_rate
    FROM public.fact_order_headers o
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Share of orders marked paid for the selected period vs the prior period.',
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
    '01a066fc-a9bd-710e-b098-dc842579efff',
    'New Orders',
    'Order Reports/Customers/KPI/New Orders',
    $$
    WITH customer_order_ranks AS (
        SELECT o.created_at::date AS day,
               ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.created_at ASC, o.id ASC) AS order_rank
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
    ),
    known AS (
        SELECT COUNT(*) AS new_known
        FROM customer_order_ranks r
        WHERE r.order_rank = 1
          AND (:currentStartDate::date IS NULL OR r.day >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR r.day <= :currentEndDate::date)
    ),
    guests AS (
        SELECT COUNT(*) AS new_guest
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NULL
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT k.new_known + g.new_guest AS new_orders
    FROM known k
    CROSS JOIN guests g
    $$,
    NULL,
    'KPI',
    60,
    'Orders from first-time customers, including guest checkouts, for the selected period vs the prior period.',
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
    '01a066fc-a9bd-7660-b37e-2cb2c1ca9145',
    'Repeat Orders',
    'Order Reports/Customers/KPI/Repeat Orders',
    $$
    WITH customer_order_ranks AS (
        SELECT o.created_at::date AS day,
               ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.created_at ASC, o.id ASC) AS order_rank
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
    )
    SELECT COUNT(*) AS repeat_orders
    FROM customer_order_ranks r
    WHERE r.order_rank > 1
      AND (:currentStartDate::date IS NULL OR r.day >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL OR r.day <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Orders from returning customers for the selected period vs the prior period.',
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
    '019fff82-e31d-7c01-8f31-2a2b3c4d1001',
    '01a066fc-a9b9-753a-877f-f49b74366a3b',
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
    '019fff82-e31d-7c02-8f32-2a2b3c4d1002',
    '01a066fc-a9b9-7a9c-bce8-8179fd07b051',
    'gross_sales',
    $$
    WITH order_totals AS (
        SELECT COALESCE(SUM(gross_sales) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(gross_sales) FILTER (WHERE is_prior),   0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(o.subtotal_price, 0)
                     + COALESCE(o.total_discounts_amount, 0) AS gross_sales
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
    '019fff82-e31d-7c03-8f33-2a2b3c4d1003',
    '01a066fc-a9ba-7c66-bb34-708bcd948a61',
    'average_order_value',
    $$
    WITH order_totals AS (
        SELECT COUNT(*) FILTER (WHERE is_current) AS cur_orders,
               COUNT(*) FILTER (WHERE is_prior)   AS prv_orders,
               COALESCE(SUM(net_sales) FILTER (WHERE is_current), 0) AS cur_net,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior),   0) AS prv_net
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
        SELECT ROUND(COALESCE(ot.cur_net / NULLIF(ot.cur_orders, 0), 0), 2) AS cur_aov,
               ROUND(COALESCE(ot.prv_net / NULLIF(ot.prv_orders, 0), 0), 2) AS prv_aov
        FROM order_totals ot
    )
    SELECT c.prv_aov AS previous_value,
           ROUND(100 * (c.cur_aov - c.prv_aov)
                 / NULLIF(ABS(c.prv_aov), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fff82-e31d-7c04-8f34-2a2b3c4d1004',
    '01a066fc-a9ba-7fc0-a00d-7778344ae6b0',
    'discount_amount',
    $$
    WITH order_totals AS (
        SELECT COALESCE(SUM(discount_amount) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(discount_amount) FILTER (WHERE is_prior),   0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(o.total_discounts_amount, 0) AS discount_amount
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
    '019fff82-e31d-7c05-8f35-2a2b3c4d1005',
    '01a066fc-a9ba-7bec-9612-640941cda264',
    'refunded_order_value',
    $$
    WITH refund_totals AS (
        SELECT COALESCE(SUM(r.total_refunded_amount) FILTER (WHERE t.is_current), 0) AS cur_value,
               COALESCE(SUM(r.total_refunded_amount) FILTER (WHERE t.is_prior),   0) AS prv_value
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
        JOIN public.fact_order_refunds r ON r.order_id = t.id
        WHERE t.is_current OR t.is_prior
    )
    SELECT ROUND(rt.prv_value, 2) AS previous_value,
           ROUND(100 * (rt.cur_value - rt.prv_value)
                 / NULLIF(ABS(rt.prv_value), 0), 2) AS divergence
    FROM refund_totals rt
    $$
),
(
    '019fff82-e31d-7c06-8f36-2a2b3c4d1006',
    '01a066fc-a9ba-7e43-bd9c-fc29b7879642',
    'tax_collected',
    $$
    WITH order_totals AS (
        SELECT COALESCE(SUM(tax_collected) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(tax_collected) FILTER (WHERE is_prior),   0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(o.current_total_tax, 0) AS tax_collected
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
    '019fff82-e31d-7c07-8f37-2a2b3c4d1007',
    '01a066fc-a9bb-70d2-8554-8a69d923b309',
    'total_orders',
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
    '019fff82-e31d-7c08-8f38-2a2b3c4d1008',
    '01a066fc-a9bb-7a4b-8e08-2ac2c37e556f',
    'fulfillment_pending_orders',
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
              AND UPPER(o.fulfillmentStatus) IS DISTINCT FROM 'FULFILLED'
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
    '019fff82-e31d-7c09-8f39-2a2b3c4d1009',
    '01a066fc-a9bc-7ad0-b589-6ef07964b7b3',
    'cancelled_orders',
    $$
    WITH cancellation_totals AS (
        SELECT COUNT(*) FILTER (WHERE is_current) AS cur_value,
               COUNT(*) FILTER (WHERE is_prior)   AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.cancelled_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.cancelled_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.cancelled_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.cancelled_at IS NOT NULL
        ) t
        WHERE t.is_current OR t.is_prior
    )
    SELECT ct.prv_value AS previous_value,
           ROUND(100.0 * (ct.cur_value - ct.prv_value)
                 / NULLIF(ABS(ct.prv_value), 0), 2) AS divergence
    FROM cancellation_totals ct
    $$
),
(
    '019fff82-e31d-7c0a-8f3a-2a2b3c4d100a',
    '01a066fc-a9bc-79c2-8074-c6911364c32e',
    'outstanding_amount',
    $$
    WITH order_totals AS (
        SELECT COALESCE(SUM(outstanding_amount) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(outstanding_amount) FILTER (WHERE is_prior),   0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior,
                   COALESCE(o.total_outstanding_amount, 0) AS outstanding_amount
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
    '019fff82-e31d-7c0b-8f3b-2a2b3c4d100b',
    '01a066fc-a9bc-71e7-ab1a-0109d09923fe',
    'paid_order_rate',
    $$
    WITH computed AS (
        SELECT ROUND(COALESCE(100.0 * COUNT(*) FILTER (WHERE is_current AND financial_status = 'PAID')
                              / NULLIF(COUNT(*) FILTER (WHERE is_current), 0), 0), 2) AS cur_rate,
               ROUND(COALESCE(100.0 * COUNT(*) FILTER (WHERE is_prior AND financial_status = 'PAID')
                              / NULLIF(COUNT(*) FILTER (WHERE is_prior), 0), 0), 2) AS prv_rate
        FROM (
            SELECT UPPER(o.financialstatus) AS financial_status,
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
    SELECT c.prv_rate AS previous_value,
           ROUND(100 * (c.cur_rate - c.prv_rate)
                 / NULLIF(ABS(c.prv_rate), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fff82-e31d-7c0c-8f3c-2a2b3c4d100c',
    '01a066fc-a9bd-710e-b098-dc842579efff',
    'new_orders',
    $$
    WITH customer_order_ranks AS (
        SELECT o.created_at::date AS day,
               ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.created_at ASC, o.id ASC) AS order_rank
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
    ),
    known AS (
        SELECT COUNT(*) FILTER (WHERE is_current AND order_rank = 1) AS cur_new,
               COUNT(*) FILTER (WHERE is_prior   AND order_rank = 1) AS prv_new
        FROM (
            SELECT r.order_rank,
                   ((:currentStartDate::date IS NULL OR r.day >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR r.day <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND r.day BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM customer_order_ranks r
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    guests AS (
        SELECT COUNT(*) FILTER (WHERE is_current) AS cur_guest,
               COUNT(*) FILTER (WHERE is_prior)   AS prv_guest
        FROM (
            SELECT ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM public.fact_order_headers o
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.customer_id IS NULL
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    computed AS (
        SELECT k.cur_new + g.cur_guest AS cur_value,
               k.prv_new + g.prv_guest AS prv_value
        FROM known k
        CROSS JOIN guests g
    )
    SELECT c.prv_value AS previous_value,
           ROUND(100.0 * (c.cur_value - c.prv_value)
                 / NULLIF(ABS(c.prv_value), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fff82-e31d-7c0d-8f3d-2a2b3c4d100d',
    '01a066fc-a9bd-7660-b37e-2cb2c1ca9145',
    'repeat_orders',
    $$
    WITH customer_order_ranks AS (
        SELECT o.created_at::date AS day,
               ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.created_at ASC, o.id ASC) AS order_rank
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.customer_id IS NOT NULL
    ),
    repeat_totals AS (
        SELECT COUNT(*) FILTER (WHERE is_current AND order_rank > 1) AS cur_value,
               COUNT(*) FILTER (WHERE is_prior   AND order_rank > 1) AS prv_value
        FROM (
            SELECT r.order_rank,
                   ((:currentStartDate::date IS NULL OR r.day >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR r.day <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND r.day BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM customer_order_ranks r
        ) t
        WHERE t.is_current OR t.is_prior
    )
    SELECT rt.prv_value AS previous_value,
           ROUND(100.0 * (rt.cur_value - rt.prv_value)
                 / NULLIF(ABS(rt.prv_value), 0), 2) AS divergence
    FROM repeat_totals rt
    $$
);
