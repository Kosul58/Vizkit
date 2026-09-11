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
        'f7b7070e-9dff-408b-b882-ee53fb22359c',
        'Revenue & Sales Trend',
        'Business Performance Overview/Overview/PLOT/Revenue & Sales Trend',
        $$
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
          AND o.created_at >= dp.start_bucket
          AND o.created_at < dp.end_bucket + dp.step
    ),
    daily AS (
        SELECT f.bucket,
               SUM(f.net_sales) AS net_sales,
               COUNT(*) AS orders
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
           ROUND(COALESCE(d.net_sales, 0), 2) AS net_sales,
           COALESCE(d.orders, 0) AS orders
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily d ON d.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
        NULL,
        'PLOT',
        30,
        'Combo chart: net sales as bars, order count as a line, grouped by dynamic date granularity.',
        '{
      "filterMappings": {
        "shopId":          { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"  },
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
        $$
    WITH
    filtered_lines AS (
        SELECT li.product_variant_id,
               COALESCE(li.discounted_total_amount, 0) AS net_sales
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT COALESCE(tc.name, p.product_type, 'Uncategorized') AS category,
           ROUND(SUM(f.net_sales), 2) AS net_sales
    FROM filtered_lines f
    JOIN public.dim_product_variants pv ON pv.id = f.product_variant_id
    LEFT JOIN public.dim_products p ON p.id = pv.product_id
    LEFT JOIN public.dim_taxonomy_categories tc ON tc.id = p.category_id AND tc.seller_id = p.seller_id
    GROUP BY COALESCE(tc.name, p.product_type, 'Uncategorized')
    HAVING SUM(f.net_sales) > 0
    ORDER BY net_sales DESC
    LIMIT 10
    $$,
        NULL,
        'PLOT',
        30,
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
        $$
    WITH sku_inventory AS (
        SELECT pv.id AS variant_id,
               SUM(COALESCE(il.available_quantity, 0)) AS available_quantity,
               SUM(COALESCE(il.safety_stock_quantity, 0)) AS safety_total
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
                WHEN si.available_quantity <= 0                          THEN 'Out of Stock'
                WHEN si.safety_total > 0
                 AND si.available_quantity <= si.safety_total            THEN 'Low Stock'
                WHEN si.safety_total > 0
                 AND si.available_quantity > si.safety_total * 3         THEN 'Overstock'
                ELSE 'In Stock'
            END AS status
        FROM sku_inventory si
    ),
    bands(ord, status) AS (
        VALUES (1, 'In Stock'), (2, 'Low Stock'), (3, 'Out of Stock'), (4, 'Overstock')
    )
    SELECT b.status AS name,
           COUNT(c.status) AS sku_count
    FROM bands b
    LEFT JOIN classified c ON c.status = b.status
    GROUP BY b.ord, b.status
    ORDER BY b.ord
    $$,
        NULL,
        'PLOT',
        60,
        'Distribution of SKUs across stock status classifications (In Stock, Low Stock, Out of Stock, Overstock), measured against configured safety stock summed across active locations. Where a SKU has no safety stock configured, only Out of Stock and In Stock are determinable.',
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
        $$
    WITH
    filtered_lines AS (
        SELECT li.product_variant_id,
               COALESCE(li.discounted_total_amount, 0) AS net_sales
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
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
    $$,
        NULL,
        'PLOT',
        30,
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