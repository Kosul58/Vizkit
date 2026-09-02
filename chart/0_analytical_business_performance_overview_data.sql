INSERT INTO
    vizkit.chart (
        id,
        name,
        purpose,
        query,
        metadata,
        chart_type,
        cache_ttl,
        description,
        configuration
    )
VALUES (
        '77fb14df-6b12-4410-a54a-4225f1953790',
        'Business Performance KPIs',
        'Business Performance Overview/Overview/KPI/Business Performance KPIs',
        '
    WITH
    /*comparison_window_cte*/
    scoped_orders AS (
        SELECT * FROM (
            SELECT o.id,
                   o.customer_id,
                   ((w.cur_start IS NULL OR o.created_at::date >= w.cur_start)
                AND (w.cur_end   IS NULL OR o.created_at::date <= w.cur_end))  AS is_current,
                   (w.prv_start IS NOT NULL
                AND o.created_at::date BETWEEN w.prv_start AND w.prv_end)      AS is_prior,
                   COALESCE(o.current_total_price, 0)
                     - COALESCE(o.current_total_tax, 0)
                     - COALESCE(o.current_shipping_price, 0) AS net_sales
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
               COALESCE(SUM(net_sales) FILTER (WHERE is_current), 0) AS cur_net_sales,
               COALESCE(SUM(net_sales) FILTER (WHERE is_prior),   0) AS prv_net_sales,
               COUNT(DISTINCT customer_id) FILTER (WHERE is_current) AS cur_customers,
               COUNT(DISTINCT customer_id) FILTER (WHERE is_prior)   AS prv_customers
        FROM scoped_orders
    ),
    line_item_totals AS (
        SELECT COALESCE(SUM(li.original_unit_price * li.quantity)
                        FILTER (WHERE s.is_current), 0) AS cur_gross_sales,
               COALESCE(SUM(li.original_unit_price * li.quantity)
                        FILTER (WHERE s.is_prior),   0) AS prv_gross_sales
        FROM public.fact_order_line_items li
        JOIN scoped_orders s ON s.id = li.order_id
    ),
    inventory_totals AS (
        SELECT COALESCE(SUM(COALESCE(il.on_hand_quantity, 0) * COALESCE(ii.unit_cost, 0)), 0) AS inventory_value
        FROM public.dim_inventory_levels il
        JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
        WHERE il.seller_id = :shopId
          AND ii.seller_id = :shopId
          AND il.is_active = TRUE
    ),
    computed AS (
        SELECT ot.cur_net_sales, ot.prv_net_sales,
               ot.cur_orders, ot.prv_orders,
               ot.cur_customers, ot.prv_customers,
               lt.cur_gross_sales, lt.prv_gross_sales,
               ROUND(ot.cur_net_sales / NULLIF(ot.cur_orders, 0), 2) AS cur_aov,
               ROUND(ot.prv_net_sales / NULLIF(ot.prv_orders, 0), 2) AS prv_aov
        FROM order_totals ot
        CROSS JOIN line_item_totals lt
    )
    SELECT ROUND(c.cur_gross_sales, 2) AS total_revenue,
           ROUND(100 * (c.cur_gross_sales - c.prv_gross_sales)
                 / NULLIF(ABS(c.prv_gross_sales), 0), 2) AS total_revenue_divergence,
           ROUND(c.cur_net_sales, 2) AS net_sales,
           ROUND(100 * (c.cur_net_sales - c.prv_net_sales)
                 / NULLIF(ABS(c.prv_net_sales), 0), 2) AS net_sales_divergence,
           c.cur_aov AS average_order_value,
           ROUND(100 * (c.cur_aov - c.prv_aov)
                 / NULLIF(ABS(c.prv_aov), 0), 2) AS average_order_value_divergence,
           c.cur_orders AS orders,
           ROUND(100 * (c.cur_orders - c.prv_orders)
                 / NULLIF(ABS(c.prv_orders), 0), 2) AS orders_divergence,
           c.cur_customers AS total_customers,
           ROUND(100 * (c.cur_customers - c.prv_customers)
                 / NULLIF(ABS(c.prv_customers), 0), 2) AS total_customers_divergence,
           it.inventory_value AS inventory_value
    FROM computed c
    CROSS JOIN inventory_totals it
    ',
        NULL,
        'KPI',
        300,
        'Total Revenue, Net Sales, AOV, Orders, Total Customers, and Inventory Value KPI cards.',
        '{
      "filterMappings": {
        "shopId":          { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"      },
        "userId":          { "source": "AUTH_CONTEXT",   "contextKey": "user_id"      },
        "currentStartDate":{ "source": "REQUEST_FILTER", "filterKey": "startDate"     },
        "currentEndDate":  { "source": "REQUEST_FILTER", "filterKey": "endDate"       },
        "priorStartDate":  { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":    { "source": "REQUEST_FILTER", "filterKey": "prevEndDate"   }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        { "provider": "COMPARISON_WINDOW_CTE", "condition": "hasFilter:startDate", "placeholder": "/*comparison_window_cte*/",
          "args": { "currentStartParam": "currentStartDate", "currentEndParam": "currentEndDate", "priorStartParam": "priorStartDate", "priorEndParam": "priorEndDate" } }
      ]
    }'
    ),
    (
        'f7b7070e-9dff-408b-b882-ee53fb22359c',
        'Revenue & Sales Trend',
        'Business Performance Overview/Overview/PLOT/Revenue & Sales Trend',
        '
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
          AND o.cancelled_at IS NULL
          AND o.created_at >= dp.start_bucket
          AND o.created_at <= :currentEndDate::date
    ),
    daily AS (
        SELECT f.bucket,
               SUM(f.net_sales) AS net_sales,
               COUNT(*) AS orders
        FROM filtered_orders f
        GROUP BY f.bucket
    )
    SELECT CASE
               WHEN dp.g = ''DAY''     THEN to_char(df.bucket, ''Mon DD'')
               WHEN dp.g = ''WEEK''    THEN to_char(df.bucket, ''Mon DD'')
               WHEN dp.g = ''MONTH''   THEN to_char(df.bucket, ''Mon YYYY'')
               WHEN dp.g = ''QUARTER'' THEN ''Q'' || EXTRACT(QUARTER FROM df.bucket)::int || '' '' || EXTRACT(YEAR FROM df.bucket)::int
               WHEN dp.g = ''YEAR''    THEN to_char(df.bucket, ''YYYY'')
           END AS period,
           df.bucket,
           ROUND(COALESCE(d.net_sales, 0), 2) AS net_sales,
           COALESCE(d.orders, 0) AS orders
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily d ON d.bucket = df.bucket
    ORDER BY df.bucket ASC
    ',
        NULL,
        'PLOT',
        300,
        'Combo chart: net sales as bars, order count as a line, grouped by dynamic date granularity.',
        '{
      "filterMappings": {
        "shopId":          { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"  },
        "userId":          { "source": "AUTH_CONTEXT",   "contextKey": "user_id"  },
        "currentStartDate":{ "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":  { "source": "REQUEST_FILTER", "filterKey": "endDate"   },
        "granularity":     { "source": "REQUEST_FILTER", "filterKey": "granularity" }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        { "provider": "DATE_GRANULARITY_CTE", "condition": "hasFilter:startDate", "placeholder": "/*date_granularity_cte*/",
          "args": { "startDateParam": "currentStartDate", "endDateParam": "currentEndDate", "granularityParam": "granularity" } }
      ]
    }'
    ),
    (
        '96f2558c-40ab-400c-8f3c-692c8f3bfd7f',
        'Revenue by Category',
        'Business Performance Overview/Overview/PLOT/Revenue by Category',
        '
    WITH
    filtered_lines AS (
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
    SELECT COALESCE(tc.name, p.product_type, ''Uncategorized'') AS category,
           ROUND(SUM(f.net_sales), 2) AS net_sales
    FROM filtered_lines f
    JOIN public.dim_product_variants pv ON pv.id = f.product_variant_id
    LEFT JOIN public.dim_products p ON p.id = pv.product_id
    LEFT JOIN public.dim_taxonomy_categories tc ON tc.id = p.category_id
    GROUP BY COALESCE(tc.name, p.product_type, ''Uncategorized'')
    HAVING SUM(f.net_sales) > 0
    ORDER BY net_sales DESC
    LIMIT 10
    ',
        NULL,
        'PLOT',
        300,
        'Horizontal bar chart of net sales by category.',
        '{
      "filterMappings": {
        "shopId":          { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"  },
        "userId":          { "source": "AUTH_CONTEXT",   "contextKey": "user_id"  },
        "currentStartDate":{ "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":  { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
    ),
    (
        '56a463a9-99ca-4c5c-a186-cad73dd60df9',
        'Stock Status Mix',
        'Business Performance Overview/Overview/PLOT/Stock Status Mix',
        '
    WITH sku_inventory AS (
        SELECT pv.id AS variant_id,
               SUM(COALESCE(il.available_quantity, 0)) AS available_quantity,
               MAX(COALESCE(il.safety_stock_quantity, 0)) AS safety_per_location,
               BOOL_OR(COALESCE(il.available_quantity, 0)
                       <= COALESCE(il.safety_stock_quantity, 0)) AS any_location_low
        FROM public.dim_product_variants pv
        JOIN public.dim_inventory_items ii ON ii.id = pv.inventory_item_id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        WHERE pv.seller_id = :shopId
          AND ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.id
    ),
    classified AS (
        SELECT
            CASE
                WHEN available_quantity = 0 THEN ''Out of Stock''
                WHEN any_location_low THEN ''Low Stock''
                WHEN available_quantity > (safety_per_location * 3) THEN ''Overstock''
                ELSE ''In Stock''
            END AS status
        FROM sku_inventory
    ),
    bands(ord, status) AS (
        VALUES (1, ''In Stock''), (2, ''Low Stock''), (3, ''Out of Stock''), (4, ''Overstock'')
    )
    SELECT b.status AS name,
           COUNT(c.status) AS sku_count
    FROM bands b
    LEFT JOIN classified c ON c.status = b.status
    GROUP BY b.ord, b.status
    ORDER BY b.ord
    ',
        NULL,
        'PLOT',
        60,
        'Distribution of SKUs across stock status classifications (In Stock, Low Stock, Out of Stock, Overstock).',
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
        'c449c454-e9b6-41a0-8081-85360d32df5e',
        'Top Products Performance',
        'Business Performance Overview/Overview/PLOT/Top Products Performance',
        '
    WITH
    filtered_lines AS (
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
    SELECT COALESCE(p.title, pv.sku, pv.id) AS product,
           ROUND(SUM(f.net_sales), 2) AS net_sales
    FROM filtered_lines f
    JOIN public.dim_product_variants pv ON pv.id = f.product_variant_id
    LEFT JOIN public.dim_products p ON p.id = pv.product_id
    GROUP BY COALESCE(p.title, pv.sku, pv.id)
    HAVING SUM(f.net_sales) > 0
    ORDER BY net_sales DESC
    LIMIT 10
    ',
        NULL,
        'PLOT',
        300,
        'Bar chart of net sales by product.',
        '{
      "filterMappings": {
        "shopId":          { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"  },
        "userId":          { "source": "AUTH_CONTEXT",   "contextKey": "user_id"  },
        "currentStartDate":{ "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":  { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
    );