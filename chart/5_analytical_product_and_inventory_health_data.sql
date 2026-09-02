--liquibase formatted sql logicalFilePath:20260804001_analytical_product_and_inventory_health_data.sql

--changeset saugat:RW-37-1
--comment seed Inventory Health tab

INSERT INTO chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31e-7982-a4ad-54e5b0b51284',
    'Inventory Health KPIs',
    'Product & Inventory Health/Inventory Health/KPI/Inventory Health KPIs',
    '
    WITH
    /*comparison_window_cte*/
    sku_inventory AS (
        SELECT pv.id AS variant_id,
               SUM(COALESCE(il.available_quantity, 0)) AS available_quantity,
               SUM(COALESCE(il.committed_quantity, 0)) AS committed_quantity,
               SUM(COALESCE(il.reserved_quantity, 0)) AS reserved_quantity,
               BOOL_OR(COALESCE(il.available_quantity, 0)
                       <= COALESCE(il.safety_stock_quantity, 0)) AS any_location_low
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.id
    ),
    scoped_lines AS (
        SELECT * FROM (
            SELECT li.product_variant_id,
                   li.quantity,
                   ((w.cur_start IS NULL OR o.created_at::date >= w.cur_start)
                AND (w.cur_end   IS NULL OR o.created_at::date <= w.cur_end))  AS is_current,
                   (w.prv_start IS NOT NULL
                AND o.created_at::date BETWEEN w.prv_start AND w.prv_end)      AS is_prior
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            CROSS JOIN windows w
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.cancelled_at IS NULL
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    sales AS (
        SELECT product_variant_id,
               COALESCE(SUM(quantity) FILTER (WHERE is_current), 0) AS cur_units,
               COALESCE(SUM(quantity) FILTER (WHERE is_prior),   0) AS prv_units
        FROM scoped_lines
        GROUP BY product_variant_id
    ),
    rolled AS (
        SELECT COALESCE(SUM(si.available_quantity + si.committed_quantity + si.reserved_quantity), 0)
                 AS total_inventory_units,
               COALESCE(SUM(si.available_quantity), 0) AS available_stock,
               COUNT(*) FILTER (WHERE si.available_quantity > 0 AND si.any_location_low) AS low_stock_skus,
               COUNT(*) FILTER (WHERE si.available_quantity = 0) AS out_of_stock_skus,
               COALESCE(SUM(s.cur_units), 0) AS cur_units,
               COALESCE(SUM(s.prv_units), 0) AS prv_units
         FROM sku_inventory si
         LEFT JOIN sales s ON s.product_variant_id = si.variant_id
    ),
    computed AS (
        SELECT r.total_inventory_units, r.available_stock, r.low_stock_skus, r.out_of_stock_skus,
               ROUND(100.0 * r.cur_units
                     / NULLIF(r.available_stock + r.cur_units, 0), 2) AS cur_sell_through,
               ROUND(100.0 * r.prv_units
                     / NULLIF(r.available_stock + r.prv_units, 0), 2) AS prv_sell_through
        FROM rolled r
    )
    SELECT c.total_inventory_units AS total_inventory_units,
           c.available_stock AS available_stock,
           c.low_stock_skus AS low_stock_skus,
           c.out_of_stock_skus AS out_of_stock_skus,
           c.cur_sell_through AS sell_through_rate,
           ROUND(100 * (c.cur_sell_through - c.prv_sell_through)
                 / NULLIF(ABS(c.prv_sell_through), 0), 2) AS sell_through_rate_divergence
    FROM computed c
    ',
    NULL,
    'KPI',
    60,
    'Overall inventory health metrics covering total units, available stock, low stock SKUs, out of stock SKUs, and sell-through rate %.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"      },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"      },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate"     },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"       },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate"   }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        {
          "provider": "COMPARISON_WINDOW_CTE",
          "condition": "hasFilter:startDate",
          "placeholder": "/*comparison_window_cte*/",
          "args": {
            "currentStartParam": "currentStartDate",
            "currentEndParam": "currentEndDate",
            "priorStartParam": "priorStartDate",
            "priorEndParam": "priorEndDate"
          }
        }
      ]
    }'
),
(
    '019fff82-e31e-7a30-9953-eb452bce7b85',
    'Stock Status Mix',
    'Product & Inventory Health/Inventory Health/PLOT/Stock Status Mix',
    '
    WITH sku_inventory AS (
        SELECT ii.id AS inventory_item_id,
               SUM(COALESCE(il.available_quantity, 0)) AS available_quantity,
               MAX(COALESCE(il.safety_stock_quantity, 0)) AS safety_per_location,
               BOOL_OR(COALESCE(il.available_quantity, 0)
                       <= COALESCE(il.safety_stock_quantity, 0)) AS any_location_low
        FROM public.dim_inventory_items ii
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY ii.id
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
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31e-7494-b147-e0825a13ad10',
    'Sell-Through by Product',
    'Product & Inventory Health/Inventory Health/PLOT/Sell-Through by Product',
    '
    WITH sku_inventory AS (
        SELECT pv.id AS variant_id,
               COALESCE(pv.sku, ii.sku) AS sku,
               p.title AS product_title,
               SUM(COALESCE(il.available_quantity, 0)) AS available_quantity
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        JOIN public.dim_products p ON p.id = pv.product_id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.id, pv.sku, ii.sku, p.title
    ),
    sales AS (
        SELECT li.product_variant_id,
               SUM(li.quantity) AS units_sold
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY li.product_variant_id
    )
    SELECT CASE WHEN LENGTH(CONCAT_WS(CHR(32) || CHR(45) || CHR(32), si.product_title, si.sku)) > 0
                THEN CONCAT_WS(CHR(32) || CHR(45) || CHR(32), si.product_title, si.sku)
                ELSE si.variant_id::text END AS name,
           ROUND(
               100.0 * COALESCE(s.units_sold, 0)
                 / NULLIF(si.available_quantity + COALESCE(s.units_sold, 0), 0),
               2
           ) AS sell_through_rate
    FROM sku_inventory si
    LEFT JOIN sales s ON s.product_variant_id = si.variant_id
    WHERE COALESCE(s.units_sold, 0) > 0
    ORDER BY sell_through_rate DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Products ranked by sell-through rate percentage.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31e-7a80-87d7-b73688031a3c',
    'Top Selling Products vs Available Stock',
    'Product & Inventory Health/Inventory Health/PLOT/Top Selling Products vs Available Stock',
    '
    WITH sku_inventory AS (
        SELECT pv.id AS variant_id,
               COALESCE(pv.sku, ii.sku) AS sku,
               p.title AS product_title,
               SUM(COALESCE(il.available_quantity, 0)) AS available_quantity
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        JOIN public.dim_products p ON p.id = pv.product_id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.id, pv.sku, ii.sku, p.title
    ),
    sales AS (
        SELECT li.product_variant_id,
               SUM(li.quantity) AS units_sold
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY li.product_variant_id
    )
    SELECT CASE WHEN LENGTH(CONCAT_WS(CHR(32) || CHR(45) || CHR(32), si.product_title, si.sku)) > 0
                THEN CONCAT_WS(CHR(32) || CHR(45) || CHR(32), si.product_title, si.sku)
                ELSE s.product_variant_id::text END AS name,
           COALESCE(s.units_sold, 0) AS units_sold,
           COALESCE(si.available_quantity, 0) AS available_stock
    FROM sales s
    LEFT JOIN sku_inventory si ON si.variant_id = s.product_variant_id
    ORDER BY units_sold DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Comparison of units sold vs available stock for top products.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31e-7c6d-8384-a1140a90563f',
    'Inventory Health Report',
    'Product & Inventory Health/Inventory Health/TABLE/Inventory Health Report',
    '
    WITH level_rows AS (
        SELECT COALESCE(pv.sku, ii.sku) AS sku,
               p.title AS product,
               loc.name AS location,
               il.available_quantity,
               il.committed_quantity,
               il.reserved_quantity,
               il.safety_stock_quantity,
               CASE
                   WHEN il.available_quantity = 0 THEN ''Out of Stock''
                   WHEN il.available_quantity <= il.safety_stock_quantity THEN ''Low Stock''
                   WHEN il.available_quantity > (il.safety_stock_quantity * 3) THEN ''Overstock''
                   ELSE ''In Stock''
               END AS stock_status
        FROM public.dim_inventory_levels il
        JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
        LEFT JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        LEFT JOIN public.dim_products p ON p.id = pv.product_id
        LEFT JOIN public.dim_inventory_locations loc ON loc.id = il.inventory_location_id
        WHERE il.seller_id = :shopId
          AND ii.seller_id = :shopId
          AND il.is_active = TRUE
    )
    SELECT sku,
           product,
           COALESCE(location, ''Unknown'') AS location,
           available_quantity,
           committed_quantity,
           reserved_quantity,
           safety_stock_quantity,
           stock_status,
           COUNT(*) OVER() AS total_records
    FROM level_rows
    ORDER BY available_quantity ASC, sku, location
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Detailed inventory audit report per SKU and location showing available, committed, reserved, and safety stock.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31e-7ada-8e58-b9818b23a2bc',
    'Fast-Moving SKU Report',
    'Product & Inventory Health/Inventory Health/TABLE/Fast-Moving SKU Report',
    '
    WITH sales_window AS (
        SELECT MIN(o.created_at::date) AS min_day,
               MAX(o.created_at::date) AS max_day
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    period AS (
        SELECT GREATEST(COALESCE(:currentEndDate::date, w.max_day)
                      - COALESCE(:currentStartDate::date, w.min_day) + 1, 1) AS days_in_period
        FROM sales_window w
    ),
    sku_inventory AS (
        SELECT pv.id AS variant_id,
               COALESCE(pv.sku, ii.sku) AS sku,
               p.title AS product,
               SUM(COALESCE(il.available_quantity, 0)) AS available_quantity
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        JOIN public.dim_products p ON p.id = pv.product_id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.id, pv.sku, ii.sku, p.title
    ),
    sales AS (
        SELECT li.product_variant_id,
               SUM(li.quantity) AS units_sold
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY li.product_variant_id
    )
    SELECT COALESCE(si.sku, s.product_variant_id::text) AS sku,
           si.product AS product,
           s.units_sold AS units_sold,
           ROUND(100.0 * s.units_sold
                 / NULLIF(COALESCE(si.available_quantity, 0) + s.units_sold, 0), 2) AS sell_through_rate,
           COALESCE(si.available_quantity, 0) AS available_stock,
           ROUND(COALESCE(si.available_quantity, 0)
                 / NULLIF(s.units_sold::numeric / per.days_in_period, 0), 1) AS stock_coverage_days,
           COUNT(*) OVER() AS total_records
    FROM sales s
    LEFT JOIN sku_inventory si ON si.variant_id = s.product_variant_id
    CROSS JOIN period per
    ORDER BY s.units_sold DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Report ranking fast-moving SKUs by units sold, sell-through rate %, and stock coverage days.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
);

--changeset saugat:RW-37-2
--comment seed Replenishment & Stock Risk tab

INSERT INTO chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31e-72ff-b56a-7858f69bc0bf',
    'Replenishment & Stock Risk KPIs',
    'Product & Inventory Health/Replenishment & Stock Risk/KPI/Replenishment & Stock Risk KPIs',
    '
    WITH
    /*comparison_window_cte*/
    period AS (
        SELECT GREATEST(COALESCE(w.cur_end, (SELECT MAX(o.created_at::date) FROM public.fact_order_headers o WHERE o.seller_id = :shopId AND o.test = FALSE AND o.cancelled_at IS NULL))
                      - COALESCE(w.cur_start, (SELECT MIN(o.created_at::date) FROM public.fact_order_headers o WHERE o.seller_id = :shopId AND o.test = FALSE AND o.cancelled_at IS NULL)) + 1, 1) AS cur_days,
               GREATEST(w.prv_end - w.prv_start + 1, 1) AS prv_days
        FROM windows w
    ),
    sku_inventory AS (
        SELECT pv.id AS variant_id,
               pv.price,
               SUM(COALESCE(il.available_quantity, 0)) AS available_quantity,
               BOOL_OR(COALESCE(il.available_quantity, 0)
                       <= COALESCE(il.safety_stock_quantity, 0)) AS any_location_low,
               SUM(COALESCE(il.incoming_quantity, 0)) AS incoming_quantity
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.id, pv.price
    ),
    scoped_lines AS (
        SELECT * FROM (
            SELECT li.product_variant_id,
                   li.quantity,
                   ((w.cur_start IS NULL OR o.created_at::date >= w.cur_start)
                AND (w.cur_end   IS NULL OR o.created_at::date <= w.cur_end))  AS is_current,
                   (w.prv_start IS NOT NULL
                AND o.created_at::date BETWEEN w.prv_start AND w.prv_end)      AS is_prior
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            CROSS JOIN windows w
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.cancelled_at IS NULL
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    sales AS (
        SELECT product_variant_id,
               COALESCE(SUM(quantity) FILTER (WHERE is_current), 0) AS cur_units,
               COALESCE(SUM(quantity) FILTER (WHERE is_prior),   0) AS prv_units
        FROM scoped_lines
        GROUP BY product_variant_id
    ),
    velocity AS (
        SELECT si.price,
               si.available_quantity,
               si.any_location_low,
               si.incoming_quantity,
               COALESCE(s.cur_units, 0)::numeric / per.cur_days AS cur_per_day,
               COALESCE(s.prv_units, 0)::numeric / per.prv_days AS prv_per_day
        FROM sku_inventory si
        CROSS JOIN period per
        LEFT JOIN sales s ON s.product_variant_id = si.variant_id
    ),
    computed AS (
        SELECT ROUND(COALESCE(SUM(
                   CASE WHEN any_location_low
                        THEN cur_per_day
                             * GREATEST(7 - available_quantity / NULLIF(cur_per_day, 0), 0)
                             * COALESCE(price, 0)
                        ELSE 0 END), 0), 2) AS cur_risk,
               ROUND(COALESCE(SUM(
                   CASE WHEN any_location_low
                        THEN prv_per_day
                             * GREATEST(7 - available_quantity / NULLIF(prv_per_day, 0), 0)
                             * COALESCE(price, 0)
                        ELSE 0 END), 0), 2) AS prv_risk,
               ROUND(SUM(available_quantity) / NULLIF(SUM(cur_per_day), 0), 1) AS cur_cover,
               ROUND(SUM(available_quantity) / NULLIF(SUM(prv_per_day), 0), 1) AS prv_cover,
               COALESCE(SUM(incoming_quantity), 0) AS incoming_stock
        FROM velocity
    )
    SELECT c.cur_risk AS low_stock_revenue_risk,
           ROUND(100 * (c.cur_risk - c.prv_risk)
                 / NULLIF(ABS(c.prv_risk), 0), 2) AS low_stock_revenue_risk_divergence,
           c.cur_cover AS stock_coverage_days,
           ROUND(100 * (c.cur_cover - c.prv_cover)
                 / NULLIF(ABS(c.prv_cover), 0), 2) AS stock_coverage_days_divergence,
           c.incoming_stock AS incoming_stock
    FROM computed c
    ',
    NULL,
    'KPI',
    60,
    'Replenishment risk KPIs tracking low stock revenue risk, overall stock coverage days, and incoming stock.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"      },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"      },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate"     },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"       },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate"   }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        {
          "provider": "COMPARISON_WINDOW_CTE",
          "condition": "hasFilter:startDate",
          "placeholder": "/*comparison_window_cte*/",
          "args": {
            "currentStartParam": "currentStartDate",
            "currentEndParam": "currentEndDate",
            "priorStartParam": "priorStartDate",
            "priorEndParam": "priorEndDate"
          }
        }
      ]
    }'
),
(
    '019fff82-e31e-7fec-a16b-dd174e41fe83',
    'Low Stock Revenue Risk by SKU',
    'Product & Inventory Health/Replenishment & Stock Risk/PLOT/Low Stock Revenue Risk by SKU',
    '
    WITH sales_window AS (
        SELECT MIN(o.created_at::date) AS min_day,
               MAX(o.created_at::date) AS max_day
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    period AS (
        SELECT GREATEST(COALESCE(:currentEndDate::date, w.max_day)
                      - COALESCE(:currentStartDate::date, w.min_day) + 1, 1) AS days_in_period
        FROM sales_window w
    ),
    sku_inventory AS (
        SELECT pv.id AS variant_id,
               COALESCE(pv.sku, ii.sku) AS sku,
               p.title AS product_title,
               pv.price,
               SUM(COALESCE(il.available_quantity, 0)) AS available_quantity,
               BOOL_OR(COALESCE(il.available_quantity, 0)
                       <= COALESCE(il.safety_stock_quantity, 0)) AS any_location_low
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        JOIN public.dim_products p ON p.id = pv.product_id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.id, pv.sku, ii.sku, p.title, pv.price
    ),
    sales AS (
        SELECT li.product_variant_id,
               SUM(li.quantity) AS units_sold
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY li.product_variant_id
    ),
    risk AS (
        SELECT CASE WHEN LENGTH(CONCAT_WS(CHR(32) || CHR(45) || CHR(32), si.product_title, si.sku)) > 0
                    THEN CONCAT_WS(CHR(32) || CHR(45) || CHR(32), si.product_title, si.sku)
                    ELSE si.variant_id::text END AS name,
               ROUND(
                   (COALESCE(s.units_sold, 0)::numeric / per.days_in_period)
                     * GREATEST(7 - si.available_quantity
                         / NULLIF(COALESCE(s.units_sold, 0)::numeric / per.days_in_period, 0), 0)
                     * COALESCE(si.price, 0),
                   2
               ) AS revenue_at_risk
        FROM sku_inventory si
        CROSS JOIN period per
        LEFT JOIN sales s ON s.product_variant_id = si.variant_id
        WHERE si.any_location_low
          AND si.available_quantity > 0
    )
    SELECT r.name AS name,
           r.revenue_at_risk AS revenue_at_risk
    FROM risk r
    WHERE r.revenue_at_risk > 0
    ORDER BY r.revenue_at_risk DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Low stock SKUs ranked by estimated potential revenue loss at risk.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31e-7c77-934f-8e50724277f0',
    'Stock Coverage Days by SKU',
    'Product & Inventory Health/Replenishment & Stock Risk/PLOT/Stock Coverage Days by SKU',
    '
    WITH sales_window AS (
        SELECT MIN(o.created_at::date) AS min_day,
               MAX(o.created_at::date) AS max_day
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    period AS (
        SELECT GREATEST(COALESCE(:currentEndDate::date, w.max_day)
                      - COALESCE(:currentStartDate::date, w.min_day) + 1, 1) AS days_in_period
        FROM sales_window w
    ),
    sku_inventory AS (
        SELECT pv.id AS variant_id,
               COALESCE(pv.sku, ii.sku) AS sku,
               p.title AS product_title,
               SUM(COALESCE(il.available_quantity, 0)) AS available_quantity
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        JOIN public.dim_products p ON p.id = pv.product_id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.id, pv.sku, ii.sku, p.title
    ),
    sales AS (
        SELECT li.product_variant_id,
               SUM(li.quantity) AS units_sold
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY li.product_variant_id
    )
    SELECT CASE WHEN LENGTH(CONCAT_WS(CHR(32) || CHR(45) || CHR(32), si.product_title, si.sku)) > 0
                THEN CONCAT_WS(CHR(32) || CHR(45) || CHR(32), si.product_title, si.sku)
                ELSE si.variant_id::text END AS name,
           ROUND(si.available_quantity / NULLIF(s.units_sold::numeric / per.days_in_period, 0), 1) AS stock_coverage_days
    FROM sku_inventory si
    CROSS JOIN period per
    JOIN sales s ON s.product_variant_id = si.variant_id
    WHERE s.units_sold > 0
    ORDER BY stock_coverage_days ASC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'SKUs ranked by remaining stock coverage days based on recent sales velocity.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31e-7a3e-859a-6ba09f321cc8',
    'Inventory Movement Trend',
    'Product & Inventory Health/Replenishment & Stock Risk/PLOT/Inventory Movement Trend',
    '
    WITH
    /*date_granularity_cte*/
    filtered_sales AS (
        SELECT date_trunc(LOWER(dp.g), o.created_at) AS bucket,
               SUM(li.quantity) AS units_sold
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND o.created_at >= dp.start_bucket
          AND o.created_at <= dp.end_bucket
        GROUP BY date_trunc(LOWER(dp.g), o.created_at)
    ),
    current_stock AS (
        SELECT COALESCE(SUM(il.available_quantity), 0) AS available_quantity
        FROM public.dim_inventory_levels il
        WHERE il.seller_id = :shopId
          AND il.is_active = TRUE
      ),
    sold_after AS (
        SELECT df.bucket,
               COALESCE(fs.units_sold, 0) AS units_sold,
               COALESCE(SUM(COALESCE(fs.units_sold, 0)) OVER (
                   ORDER BY df.bucket ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING), 0) AS units_sold_after
        FROM date_filler df
        LEFT JOIN filtered_sales fs ON fs.bucket = df.bucket
    )
    SELECT CASE
               WHEN dp.g = ''DAY''     THEN to_char(sa.bucket, ''Mon DD'')
               WHEN dp.g = ''WEEK''    THEN to_char(sa.bucket, ''Mon DD'')
               WHEN dp.g = ''MONTH''   THEN to_char(sa.bucket, ''Mon YYYY'')
               WHEN dp.g = ''QUARTER'' THEN ''Q'' || EXTRACT(QUARTER FROM sa.bucket)::int || '' '' || EXTRACT(YEAR FROM sa.bucket)::int
               WHEN dp.g = ''YEAR''    THEN to_char(sa.bucket, ''YYYY'')
           END AS period,
           sa.bucket,
           sa.units_sold AS units_sold,
           cs.available_quantity + sa.units_sold_after AS available_stock
    FROM sold_after sa
    CROSS JOIN date_params dp
    CROSS JOIN current_stock cs
    ORDER BY sa.bucket ASC
    ',
    NULL,
    'PLOT',
    60,
    'Movement trend of units sold vs available stock trajectory grouped by dynamic date granularity.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"    },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate"   },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"     },
        "granularity":      { "source": "REQUEST_FILTER", "filterKey": "granularity" }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        {
          "provider": "DATE_GRANULARITY_CTE",
          "condition": "hasFilter:startDate",
          "placeholder": "/*date_granularity_cte*/",
          "args": {
            "startDateParam": "currentStartDate",
            "endDateParam": "currentEndDate",
            "granularityParam": "granularity"
          }
        }
      ]
    }'
),
(
    '019fff82-e31e-7fbe-8a1d-8005aaea2a53',
    'Low Stock Report',
    'Product & Inventory Health/Replenishment & Stock Risk/TABLE/Low Stock Report',
    '
    WITH sales_window AS (
        SELECT MIN(o.created_at::date) AS min_day,
               MAX(o.created_at::date) AS max_day
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    period AS (
        SELECT GREATEST(COALESCE(:currentEndDate::date, w.max_day)
                      - COALESCE(:currentStartDate::date, w.min_day) + 1, 1) AS days_in_period
        FROM sales_window w
    ),
    sku_inventory AS (
        SELECT pv.id AS variant_id,
               COALESCE(pv.sku, ii.sku) AS sku,
               p.title AS product,
               pv.price,
               SUM(COALESCE(il.available_quantity, 0)) AS available_quantity,
               MAX(COALESCE(il.safety_stock_quantity, 0)) AS safety_stock_quantity,
               BOOL_OR(COALESCE(il.available_quantity, 0)
                       <= COALESCE(il.safety_stock_quantity, 0)) AS any_location_low
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        JOIN public.dim_products p ON p.id = pv.product_id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.id, pv.sku, ii.sku, p.title, pv.price
    ),
    sales AS (
        SELECT li.product_variant_id,
               SUM(li.quantity) AS units_sold
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY li.product_variant_id
    )
    SELECT si.sku AS sku,
           si.product AS product,
           si.available_quantity AS available_quantity,
           si.safety_stock_quantity AS safety_stock,
           ROUND(COALESCE(s.units_sold, 0)::numeric / per.days_in_period, 2) AS sales_velocity,
           ROUND(si.available_quantity / NULLIF(COALESCE(s.units_sold, 0)::numeric / per.days_in_period, 0), 1) AS days_of_stock_left,
           ROUND((COALESCE(s.units_sold, 0)::numeric / per.days_in_period)
                   * GREATEST(7 - si.available_quantity
                       / NULLIF(COALESCE(s.units_sold, 0)::numeric / per.days_in_period, 0), 0)
                   * COALESCE(si.price, 0), 2) AS revenue_at_risk,
           COUNT(*) OVER() AS total_records
    FROM sku_inventory si
    CROSS JOIN period per
    LEFT JOIN sales s ON s.product_variant_id = si.variant_id
    WHERE si.any_location_low
      AND si.available_quantity > 0
    ORDER BY revenue_at_risk DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Audit table listing low stock SKUs with sales velocity, stockout horizon, and revenue at risk.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31e-748e-b205-28aafe15d0e8',
    'Out of Stock Report',
    'Product & Inventory Health/Replenishment & Stock Risk/TABLE/Out of Stock Report',
    '
    WITH sales_window AS (
        SELECT MIN(o.created_at::date) AS min_day,
               MAX(o.created_at::date) AS max_day
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    period AS (
        SELECT GREATEST(COALESCE(:currentEndDate::date, w.max_day)
                      - COALESCE(:currentStartDate::date, w.min_day) + 1, 1) AS days_in_period
        FROM sales_window w
    ),
    sales_hist AS (
        SELECT li.product_variant_id,
               MAX(o.created_at) AS last_sold_at
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
        GROUP BY li.product_variant_id
    ),
    recent_velocity AS (
        SELECT li.product_variant_id,
               SUM(li.quantity)::numeric / per.days_in_period AS units_per_day
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        CROSS JOIN period per
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY li.product_variant_id, per.days_in_period
    ),
    sku_stock AS (
        SELECT pv.id AS variant_id,
               COALESCE(pv.sku, ii.sku) AS sku,
               STRING_AGG(DISTINCT COALESCE(loc.name, ''Unknown''), CHR(44) || CHR(32)) AS location
        FROM public.dim_inventory_levels il
        JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        LEFT JOIN public.dim_inventory_locations loc ON loc.id = il.inventory_location_id
        WHERE il.seller_id = :shopId
          AND ii.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.id, pv.sku, ii.sku
        HAVING SUM(COALESCE(il.available_quantity, 0)) = 0
    )
    SELECT ss.sku AS sku,
           p.title AS product,
           p.vendor AS vendor,
           sh.last_sold_at::date::text AS last_sold_date,
           ROUND(COALESCE(rv.units_per_day, 0) * COALESCE(pv.price, 0) * 7, 2) AS lost_revenue_proxy,
           ss.location AS location,
           COUNT(*) OVER() AS total_records
    FROM sku_stock ss
    JOIN public.dim_product_variants pv ON pv.id = ss.variant_id
    JOIN public.dim_products p ON p.id = pv.product_id
    LEFT JOIN sales_hist sh ON sh.product_variant_id = ss.variant_id
    LEFT JOIN recent_velocity rv ON rv.product_variant_id = ss.variant_id
    ORDER BY lost_revenue_proxy DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Out of stock SKU report showing last sold date, affected locations, and estimated lost revenue.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
);

--changeset saugat:RW-37-3
--comment seed Inventory Value & Capital Management tab (P0/P1)

INSERT INTO chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31e-744a-b513-00f6ebae2e7e',
    'Inventory Value & Capital KPIs',
    'Product & Inventory Health/Inventory Value & Capital/KPI/Inventory Value & Capital KPIs',
    '
    WITH
    /*comparison_window_cte*/
    sku_inventory AS (
        SELECT pv.id AS variant_id,
               ii.unit_cost,
               SUM(COALESCE(il.on_hand_quantity, 0)) AS on_hand_quantity,
               SUM(COALESCE(il.damaged_quantity, 0)) AS damaged_quantity
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.id, ii.unit_cost
    ),
    scoped_lines AS (
        SELECT * FROM (
            SELECT li.product_variant_id,
                   li.quantity,
                   ((w.cur_start IS NULL OR o.created_at::date >= w.cur_start)
                AND (w.cur_end   IS NULL OR o.created_at::date <= w.cur_end))  AS is_current,
                   (w.prv_start IS NOT NULL
                AND o.created_at::date BETWEEN w.prv_start AND w.prv_end)      AS is_prior
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            CROSS JOIN windows w
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.cancelled_at IS NULL
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    sales AS (
        SELECT product_variant_id,
               SUM(quantity) FILTER (WHERE is_current) AS cur_units,
               SUM(quantity) FILTER (WHERE is_prior)   AS prv_units
        FROM scoped_lines
        GROUP BY product_variant_id
    ),
    computed AS (
        SELECT ROUND(COALESCE(SUM(si.on_hand_quantity * COALESCE(si.unit_cost, 0)), 0), 2)
                 AS inventory_value,
               ROUND(COALESCE(SUM(si.on_hand_quantity * COALESCE(si.unit_cost, 0))
                              FILTER (WHERE s.cur_units IS NULL), 0), 2) AS cur_dead,
               ROUND(COALESCE(SUM(si.on_hand_quantity * COALESCE(si.unit_cost, 0))
                              FILTER (WHERE s.prv_units IS NULL), 0), 2) AS prv_dead,
               ROUND(COALESCE(SUM(si.damaged_quantity * COALESCE(si.unit_cost, 0)), 0), 2)
                 AS damaged_stock_value
        FROM sku_inventory si
        LEFT JOIN sales s ON s.product_variant_id = si.variant_id
    )
    SELECT c.inventory_value AS inventory_value,
           c.cur_dead AS dead_stock_value,
           ROUND(100 * (c.cur_dead - c.prv_dead)
                 / NULLIF(ABS(c.prv_dead), 0), 2) AS dead_stock_value_divergence,
           c.damaged_stock_value AS damaged_stock_value
    FROM computed c
    ',
    NULL,
    'KPI',
    60,
    'Capital valuation metrics tracking total inventory value, dead stock capital, and damaged stock value vs prior period.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"      },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"      },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate"     },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"       },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate"   }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        {
          "provider": "COMPARISON_WINDOW_CTE",
          "condition": "hasFilter:startDate",
          "placeholder": "/*comparison_window_cte*/",
          "args": {
            "currentStartParam": "currentStartDate",
            "currentEndParam": "currentEndDate",
            "priorStartParam": "priorStartDate",
            "priorEndParam": "priorEndDate"
          }
        }
      ]
    }'
),
(
    '019fff82-e31e-78ef-874d-087573437963',
    'Inventory Value by Product',
    'Product & Inventory Health/Inventory Value & Capital/PLOT/Inventory Value by Product',
    '
    WITH sku_inventory AS (
        SELECT pv.product_id,
               p.title AS product_title,
               SUM(COALESCE(il.on_hand_quantity, 0) * COALESCE(ii.unit_cost, 0)) AS inventory_value
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        JOIN public.dim_products p ON p.id = pv.product_id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.product_id, p.title
    )
    SELECT product_title AS name,
           ROUND(inventory_value, 2) AS inventory_value
    FROM sku_inventory
    WHERE inventory_value > 0
    ORDER BY inventory_value DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Valuation of inventory on hand per product.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31e-742f-b74d-ffe5fc4f9a83',
    'Dead Stock by Product',
    'Product & Inventory Health/Inventory Value & Capital/PLOT/Dead Stock by Product',
    '
    WITH sku_inventory AS (
        SELECT pv.id AS variant_id,
               pv.product_id,
               p.title AS product_title,
               SUM(COALESCE(il.on_hand_quantity, 0) * COALESCE(ii.unit_cost, 0)) AS inventory_value
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        JOIN public.dim_products p ON p.id = pv.product_id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.id, pv.product_id, p.title
    ),
    sales AS (
        SELECT li.product_variant_id
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY li.product_variant_id
    )
    SELECT si.product_title AS name,
           ROUND(SUM(si.inventory_value), 2) AS dead_stock_value
    FROM sku_inventory si
    LEFT JOIN sales s ON s.product_variant_id = si.variant_id
    WHERE s.product_variant_id IS NULL
    GROUP BY si.product_title
    HAVING SUM(si.inventory_value) > 0
    ORDER BY dead_stock_value DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Dead stock capital valuation tied up in unsold products during the period.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31e-7dd0-8698-7e4c4a02a4c7',
    'Inventory Value Report',
    'Product & Inventory Health/Inventory Value & Capital/TABLE/Inventory Value Report',
    '
    WITH level_rows AS (
        SELECT p.title AS product,
               COALESCE(pv.sku, ii.sku) AS sku,
               ii.unit_cost AS unit_cost,
               COALESCE(il.on_hand_quantity, 0) AS on_hand_quantity,
               ROUND(COALESCE(il.on_hand_quantity, 0) * COALESCE(ii.unit_cost, 0), 2) AS inventory_value,
               p.vendor AS vendor,
               COALESCE(loc.name, ''Unknown'') AS location
        FROM public.dim_inventory_levels il
        JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
        LEFT JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        LEFT JOIN public.dim_products p ON p.id = pv.product_id
        LEFT JOIN public.dim_inventory_locations loc ON loc.id = il.inventory_location_id
        WHERE il.seller_id = :shopId
          AND ii.seller_id = :shopId
          AND il.is_active = TRUE
    )
    SELECT product, sku, unit_cost, on_hand_quantity, inventory_value, vendor, location,
           COUNT(*) OVER() AS total_records
    FROM level_rows
    ORDER BY inventory_value DESC, sku, location
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Detailed valuation audit report listing product, SKU, unit cost, on-hand quantity, and total inventory value.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31e-71c6-b90c-0940ff0790c1',
    'Dead Stock Report',
    'Product & Inventory Health/Inventory Value & Capital/TABLE/Dead Stock Report',
    '
    WITH sku_inventory AS (
        SELECT pv.id AS variant_id,
               COALESCE(pv.sku, ii.sku) AS sku,
               p.title AS product,
               SUM(COALESCE(il.on_hand_quantity, 0) * COALESCE(ii.unit_cost, 0)) AS inventory_value,
               SUM(COALESCE(il.available_quantity, 0)) AS available_quantity
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        JOIN public.dim_products p ON p.id = pv.product_id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.id, pv.sku, ii.sku, p.title
    ),
    last_sale AS (
        SELECT li.product_variant_id,
               MAX(o.created_at) AS last_sold_at
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
        GROUP BY li.product_variant_id
    ),
    period_sales AS (
        SELECT li.product_variant_id
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY li.product_variant_id
    )
    SELECT si.sku AS sku,
           si.product AS product,
           ROUND(si.inventory_value, 2) AS inventory_value,
           si.available_quantity AS available_stock,
           ls.last_sold_at::date::text AS last_sold_date,
           (CURRENT_DATE - ls.last_sold_at::date) AS days_without_sale,
           COUNT(*) OVER() AS total_records
    FROM sku_inventory si
    LEFT JOIN last_sale ls ON ls.product_variant_id = si.variant_id
    LEFT JOIN period_sales ps ON ps.product_variant_id = si.variant_id
    WHERE ps.product_variant_id IS NULL
    ORDER BY inventory_value DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Report listing dead stock SKUs, tied-up capital value, last sold date, and days without sale.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
);

--changeset saugat:RW-37-4
--comment seed Fulfillment & Demand tab (P0/P1)

INSERT INTO chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31e-76cf-8717-df6af72da7c4',
    'Fulfillment & Demand KPIs',
    'Product & Inventory Health/Fulfillment & Demand/KPI/Fulfillment & Demand KPIs',
    '
    WITH
    /*comparison_window_cte*/
    inv AS (
        SELECT SUM(COALESCE(il.committed_quantity, 0)) AS committed_quantity,
               SUM(COALESCE(il.reserved_quantity, 0)) AS reserved_quantity
        FROM public.dim_inventory_levels il
        WHERE il.seller_id = :shopId
          AND il.is_active = TRUE
    ),
    scoped_lines AS (
        SELECT * FROM (
            SELECT COALESCE(li.unfulfilled_quantity, 0) AS unfulfilled_quantity,
                   ((w.cur_start IS NULL OR o.created_at::date >= w.cur_start)
                AND (w.cur_end   IS NULL OR o.created_at::date <= w.cur_end))  AS is_current,
                   (w.prv_start IS NOT NULL
                AND o.created_at::date BETWEEN w.prv_start AND w.prv_end)      AS is_prior
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            CROSS JOIN windows w
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND o.cancelled_at IS NULL
        ) t
        WHERE t.is_current OR t.is_prior
    ),
    unfulfilled AS (
        SELECT COALESCE(SUM(unfulfilled_quantity) FILTER (WHERE is_current), 0) AS cur_unfulfilled,
               COALESCE(SUM(unfulfilled_quantity) FILTER (WHERE is_prior),   0) AS prv_unfulfilled
        FROM scoped_lines
    )
    SELECT COALESCE(inv.committed_quantity, 0) AS committed_stock,
           COALESCE(inv.reserved_quantity, 0) AS reserved_stock,
           u.cur_unfulfilled AS unfulfilled_stock_demand,
           ROUND(100 * (u.cur_unfulfilled - u.prv_unfulfilled)
                 / NULLIF(ABS(u.prv_unfulfilled), 0), 2) AS unfulfilled_stock_demand_divergence
    FROM inv
    CROSS JOIN unfulfilled u
    ',
    NULL,
    'KPI',
    60,
    'Demand KPIs evaluating committed stock, reserved stock, and unfulfilled stock demand volume vs prior period.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"      },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"      },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate"     },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"       },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate"   }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        {
          "provider": "COMPARISON_WINDOW_CTE",
          "condition": "hasFilter:startDate",
          "placeholder": "/*comparison_window_cte*/",
          "args": {
            "currentStartParam": "currentStartDate",
            "currentEndParam": "currentEndDate",
            "priorStartParam": "priorStartDate",
            "priorEndParam": "priorEndDate"
          }
        }
      ]
    }'
),
(
    '019fff82-e31e-7ab0-8fde-619cbe1d3f63',
    'Unfulfilled Quantity by Product',
    'Product & Inventory Health/Fulfillment & Demand/PLOT/Unfulfilled Quantity by Product',
    '
    WITH filtered_line_items AS (
        SELECT li.product_variant_id,
               li.unfulfilled_quantity
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT COALESCE(p.title, pv.sku, pv.id::text) AS name,
           SUM(COALESCE(fli.unfulfilled_quantity, 0)) AS unfulfilled_quantity
    FROM filtered_line_items fli
    JOIN public.dim_product_variants pv ON pv.id = fli.product_variant_id
    LEFT JOIN public.dim_products p ON p.id = pv.product_id
    GROUP BY COALESCE(p.title, pv.sku, pv.id::text)
    HAVING SUM(COALESCE(fli.unfulfilled_quantity, 0)) > 0
    ORDER BY unfulfilled_quantity DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Products ranked by total unfulfilled item quantity backlog.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31e-7bfd-a6b5-2777df9b07ba',
    'Unfulfilled Inventory Report',
    'Product & Inventory Health/Fulfillment & Demand/TABLE/Unfulfilled Inventory Report',
    '
    WITH filtered_line_items AS (
        SELECT li.id AS line_id,
               o.id AS order_id,
               li.product_variant_id,
               li.unfulfilled_quantity,
               li.unfulfilled_discounted_total_amount
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND li.unfulfilled_quantity > 0
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    sku_stock AS (
        SELECT pv.id AS variant_id,
               SUM(COALESCE(il.available_quantity, 0)) AS available_quantity
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.id
    ),
    primary_location AS (
        SELECT DISTINCT ON (pv.id)
               pv.id AS variant_id,
               loc.name AS location
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        LEFT JOIN public.dim_inventory_locations loc ON loc.id = il.inventory_location_id
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        ORDER BY pv.id, il.available_quantity DESC, loc.name
    )
    SELECT fli.order_id,
           COALESCE(pv.sku, pv.id::text) AS sku,
           fli.unfulfilled_quantity AS unfulfilled_quantity,
           ROUND(COALESCE(fli.unfulfilled_discounted_total_amount, 0), 2) AS unfulfilled_value,
           COALESCE(ss.available_quantity, 0) AS available_stock,
           COALESCE(pl.location, ''Unknown'') AS location,
           COUNT(*) OVER() AS total_records
    FROM filtered_line_items fli
    JOIN public.dim_product_variants pv ON pv.id = fli.product_variant_id
    LEFT JOIN sku_stock ss ON ss.variant_id = fli.product_variant_id
    LEFT JOIN primary_location pl ON pl.variant_id = fli.product_variant_id
    ORDER BY fli.unfulfilled_quantity DESC, fli.line_id
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Audit table listing unfulfilled orders, item quantity, backlog value, available stock, and location.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
);

--changeset saugat:RW-37-5
--comment seed Locations & Operations tab (P0/P1)

INSERT INTO chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31e-766d-bf1f-31a4dc974d0b',
    'Locations & Operations KPIs',
    'Product & Inventory Health/Locations & Operations/KPI/Locations & Operations KPIs',
    '
    SELECT COUNT(*) AS active_inventory_locations
    FROM (
        SELECT loc.id
        FROM public.dim_inventory_locations loc
        JOIN public.dim_inventory_levels il ON il.inventory_location_id = loc.id
        WHERE loc.seller_id = :shopId
          AND loc.is_active = TRUE
          AND il.is_active = TRUE
        GROUP BY loc.id
        HAVING SUM(COALESCE(il.available_quantity, 0)
                 + COALESCE(il.committed_quantity, 0)
                 + COALESCE(il.reserved_quantity, 0)) > 0
    ) stocked_locations
    ',
    NULL,
    'KPI',
    60,
    'Count of active fulfillment locations holding active inventory stock.',
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
    '019fff82-e31e-741a-9b77-036f24795d55',
    'Inventory by Location',
    'Product & Inventory Health/Locations & Operations/PLOT/Inventory by Location',
    '
    SELECT COALESCE(loc.name, ''Unknown'') AS name,
           COALESCE(SUM(il.available_quantity), 0) AS available_quantity,
           COALESCE(SUM(il.committed_quantity), 0) AS committed_quantity,
           COALESCE(SUM(il.reserved_quantity), 0) AS reserved_quantity
    FROM public.dim_inventory_levels il
    LEFT JOIN public.dim_inventory_locations loc ON loc.id = il.inventory_location_id
    WHERE il.seller_id = :shopId
      AND il.is_active = TRUE
    GROUP BY loc.id, loc.name
    ORDER BY available_quantity DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Inventory breakdown across locations showing available, committed, and reserved quantities.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31e-7b01-8e90-b7e72ea47d3d',
    'Damaged / QC / Safety Stock Mix',
    'Product & Inventory Health/Locations & Operations/PLOT/Damaged / QC / Safety Stock Mix',
    '
    SELECT COALESCE(loc.name, ''Unknown'') AS name,
           COALESCE(SUM(il.damaged_quantity), 0) AS damaged_quantity,
           COALESCE(SUM(il.quality_control_quantity), 0) AS quality_control_quantity,
           COALESCE(SUM(il.safety_stock_quantity), 0) AS safety_stock_quantity
    FROM public.dim_inventory_levels il
    LEFT JOIN public.dim_inventory_locations loc ON loc.id = il.inventory_location_id
    WHERE il.seller_id = :shopId
      AND il.is_active = TRUE
    GROUP BY loc.id, loc.name
    ORDER BY (COALESCE(SUM(il.damaged_quantity), 0)
              + COALESCE(SUM(il.quality_control_quantity), 0)
              + COALESCE(SUM(il.safety_stock_quantity), 0)) DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Non-sellable stock breakdown per location covering damaged, quality control, and safety stock.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31e-7f12-862d-2a71d90c903a',
    'Location Stock Report',
    'Product & Inventory Health/Locations & Operations/TABLE/Location Stock Report',
    '
    SELECT COALESCE(loc.name, ''Unknown'') AS location,
           COALESCE(loc.is_active, FALSE) AS active_status,
           COALESCE(SUM(il.available_quantity), 0) AS available_stock,
           COALESCE(SUM(il.committed_quantity), 0) AS committed_stock,
           COALESCE(SUM(il.reserved_quantity), 0) AS reserved_stock,
           COALESCE(SUM(il.damaged_quantity), 0) AS damaged_stock,
           COUNT(*) OVER() AS total_records
    FROM public.dim_inventory_levels il
    LEFT JOIN public.dim_inventory_locations loc ON loc.id = il.inventory_location_id
    WHERE il.seller_id = :shopId
      AND il.is_active = TRUE
    GROUP BY loc.id, loc.name, loc.is_active
    ORDER BY available_stock DESC, location
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Detailed audit table per location showing active status, available stock, committed stock, reserved stock, and damaged stock.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
);

--changeset saugat:RW-37-6
--comment seed Vendor & Collection Analysis tab (P1/P2, no KPI cards)

INSERT INTO chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff82-e31e-7444-b17e-549809be2b6b',
    'Inventory Value by Vendor',
    'Product & Inventory Health/Vendor & Collection Analysis/PLOT/Inventory Value by Vendor',
    '
    SELECT COALESCE(p.vendor, ''Unknown'') AS name,
           ROUND(COALESCE(SUM(COALESCE(il.on_hand_quantity, 0) * COALESCE(ii.unit_cost, 0)), 0), 2) AS inventory_value
    FROM public.dim_inventory_levels il
    JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
    JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
    JOIN public.dim_products p ON p.id = pv.product_id
    WHERE il.seller_id = :shopId
      AND ii.seller_id = :shopId
      AND il.is_active = TRUE
    GROUP BY p.vendor
    HAVING SUM(COALESCE(il.on_hand_quantity, 0) * COALESCE(ii.unit_cost, 0)) > 0
    ORDER BY inventory_value DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Inventory valuation distribution grouped by product vendor.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31e-752c-8bf6-3c3f866777c0',
    'Inventory Value by Collection',
    'Product & Inventory Health/Vendor & Collection Analysis/PLOT/Inventory Value by Collection',
    '
    SELECT COALESCE(col.title, ''Uncategorized'') AS name,
           ROUND(COALESCE(SUM(COALESCE(il.on_hand_quantity, 0) * COALESCE(ii.unit_cost, 0)), 0), 2) AS inventory_value
    FROM public.dim_inventory_levels il
    JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
    JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
    JOIN public.dim_products p ON p.id = pv.product_id
    LEFT JOIN public.dim_collection_products cp ON cp.product_id = p.id
    LEFT JOIN public.dim_collections col ON col.id = cp.collection_id AND col.seller_id = :shopId
    WHERE il.seller_id = :shopId
      AND ii.seller_id = :shopId
      AND il.is_active = TRUE
    GROUP BY col.id, col.title
    HAVING SUM(COALESCE(il.on_hand_quantity, 0) * COALESCE(ii.unit_cost, 0)) > 0
    ORDER BY inventory_value DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Inventory valuation distribution grouped by product collection.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31e-7603-b866-cadd19d65482',
    'Origin Country Stock Mix',
    'Product & Inventory Health/Vendor & Collection Analysis/PLOT/Origin Country Stock Mix',
    '
    SELECT COALESCE(ii.country_code_of_origin, ''Unknown'') AS name,
           COALESCE(SUM(COALESCE(il.on_hand_quantity, 0)), 0) AS units,
           ROUND(COALESCE(SUM(COALESCE(il.on_hand_quantity, 0) * COALESCE(ii.unit_cost, 0)), 0), 2) AS inventory_value
    FROM public.dim_inventory_levels il
    JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
    WHERE il.seller_id = :shopId
      AND ii.seller_id = :shopId
      AND il.is_active = TRUE
    GROUP BY ii.country_code_of_origin
    HAVING SUM(COALESCE(il.on_hand_quantity, 0)) > 0
    ORDER BY inventory_value DESC
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Stock units and inventory valuation distribution grouped by country of origin.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31e-706d-838e-ee315b8dde04',
    'Vendor Inventory Report',
    'Product & Inventory Health/Vendor & Collection Analysis/TABLE/Vendor Inventory Report',
    '
    WITH sku_inventory AS (
        SELECT pv.id AS variant_id,
               p.vendor,
               SUM(COALESCE(il.on_hand_quantity, 0)) AS on_hand_quantity,
               SUM(COALESCE(il.available_quantity, 0)) AS available_quantity,
               SUM(COALESCE(il.on_hand_quantity, 0) * COALESCE(ii.unit_cost, 0)) AS inventory_value
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        JOIN public.dim_products p ON p.id = pv.product_id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.id, p.vendor
    ),
    sales AS (
        SELECT li.product_variant_id,
               SUM(li.quantity) AS units_sold
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY li.product_variant_id
    )
    SELECT COALESCE(si.vendor, ''Unknown'') AS vendor,
           COUNT(DISTINCT si.variant_id) AS skus,
           SUM(si.on_hand_quantity) AS inventory_units,
           ROUND(SUM(si.inventory_value), 2) AS inventory_value,
           ROUND(100.0 * COALESCE(SUM(s.units_sold), 0) / NULLIF(SUM(si.available_quantity) + COALESCE(SUM(s.units_sold), 0), 0), 2) AS sell_through,
           ROUND(COALESCE(SUM(si.inventory_value) FILTER (WHERE s.units_sold IS NULL), 0), 2) AS dead_stock_value,
           COUNT(*) OVER() AS total_records
    FROM sku_inventory si
    LEFT JOIN sales s ON s.product_variant_id = si.variant_id
    GROUP BY si.vendor
    ORDER BY inventory_value DESC, vendor
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Comprehensive scorecard table per vendor listing SKUs, inventory units, inventory value, sell-through %, and dead stock value.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff82-e31e-7e78-8f78-8a4b440e0b84',
    'Collection Inventory Report',
    'Product & Inventory Health/Vendor & Collection Analysis/TABLE/Collection Inventory Report',
    '
    WITH sales_window AS (
        SELECT MIN(o.created_at::date) AS min_day,
               MAX(o.created_at::date) AS max_day
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    period AS (
        SELECT GREATEST(COALESCE(:currentEndDate::date, w.max_day)
                      - COALESCE(:currentStartDate::date, w.min_day) + 1, 1) AS days_in_period
        FROM sales_window w
    ),
    sku_inventory AS (
        SELECT pv.id AS variant_id,
               pv.product_id,
               col.id AS collection_id,
               col.title AS collection_title,
               SUM(COALESCE(il.available_quantity, 0)) AS available_quantity,
               BOOL_OR(COALESCE(il.available_quantity, 0)
                       <= COALESCE(il.safety_stock_quantity, 0)) AS any_location_low,
               SUM(COALESCE(il.on_hand_quantity, 0) * COALESCE(ii.unit_cost, 0)) AS inventory_value
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        JOIN public.dim_products p ON p.id = pv.product_id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        LEFT JOIN public.dim_collection_products cp ON cp.product_id = p.id
        LEFT JOIN public.dim_collections col ON col.id = cp.collection_id AND col.seller_id = :shopId
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.id, pv.product_id, col.id, col.title
    ),
    sales AS (
        SELECT li.product_variant_id,
               SUM(li.quantity) AS units_sold
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND o.cancelled_at IS NULL
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY li.product_variant_id
    )
    SELECT COALESCE(si.collection_title, ''Uncategorized'') AS collection,
           COUNT(DISTINCT si.product_id) AS products,
           SUM(si.available_quantity) AS available_stock,
           ROUND(SUM(si.inventory_value), 2) AS inventory_value,
           ROUND(COALESCE(SUM(s.units_sold), 0)::numeric / per.days_in_period, 2) AS sales_velocity,
           COUNT(DISTINCT si.variant_id) FILTER (WHERE si.any_location_low) AS stock_risk_skus,
           COUNT(*) OVER() AS total_records
    FROM sku_inventory si
    CROSS JOIN period per
    LEFT JOIN sales s ON s.product_variant_id = si.variant_id
    GROUP BY si.collection_id, si.collection_title, per.days_in_period
    ORDER BY inventory_value DESC, collection
    LIMIT COALESCE(:limit, 10)
    OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Comprehensive scorecard table per collection listing products count, available stock, inventory value, sales velocity, and stock risk SKUs.',
    '{
      "filterMappings": {
        "shopId":           { "source": "AUTH_CONTEXT",   "contextKey": "shopGid"   },
        "userId":           { "source": "AUTH_CONTEXT",   "contextKey": "user_id"   },
        "limit":            { "source": "REQUEST_FILTER", "filterKey": "limit"     },
        "offset":           { "source": "REQUEST_FILTER", "filterKey": "offset"    },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate"   }
      },
      "excludeExtraParams": true
    }'
);