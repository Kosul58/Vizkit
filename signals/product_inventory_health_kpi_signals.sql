
-- ---------- 1. charts: value only ----------

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '01a066fd-0699-78bd-bcc3-412229f90361',
    'Total Inventory Units',
    'Product & Inventory Health/Inventory Health/KPI/Total Inventory Units',
    $$
    SELECT COALESCE(SUM(COALESCE(il.available_quantity, 0)
                      + COALESCE(il.committed_quantity, 0)
                      + COALESCE(il.reserved_quantity, 0)), 0) AS total_inventory_units
    FROM public.dim_inventory_items ii
    JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
    JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
    WHERE ii.seller_id = :shopId
      AND il.seller_id = :shopId
      AND il.is_active = TRUE
    $$,
    NULL,
    'KPI',
    60,
    'Total inventory units on hand across available, committed, and reserved stock.',
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
    '01a066fd-0699-72dc-bbfd-50e66a196f6c',
    'Available Stock',
    'Product & Inventory Health/Inventory Health/KPI/Available Stock',
    $$
    SELECT COALESCE(SUM(COALESCE(il.available_quantity, 0)), 0) AS available_stock
    FROM public.dim_inventory_items ii
    JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
    JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
    WHERE ii.seller_id = :shopId
      AND il.seller_id = :shopId
      AND il.is_active = TRUE
    $$,
    NULL,
    'KPI',
    60,
    'Total stock currently available to sell.',
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
    '01a066fd-0699-76dd-8098-33eab0b24a89',
    'Low Stock SKUs',
    'Product & Inventory Health/Inventory Health/KPI/Low Stock SKUs',
    $$
    WITH sku_inventory AS (
        SELECT SUM(COALESCE(il.available_quantity, 0)) AS available_quantity,
               BOOL_OR(COALESCE(il.available_quantity, 0)
                       <= COALESCE(il.safety_stock_quantity, 0)) AS any_location_low
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.id
    )
    SELECT COUNT(*) FILTER (WHERE available_quantity > 0 AND any_location_low) AS low_stock_skus
    FROM sku_inventory
    $$,
    NULL,
    'KPI',
    60,
    'SKUs still in stock but at or below safety stock in at least one location.',
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
    '01a066fd-0699-74c4-84f5-3464a9c6ea18',
    'Out of Stock SKUs',
    'Product & Inventory Health/Inventory Health/KPI/Out of Stock SKUs',
    $$
    WITH sku_inventory AS (
        SELECT SUM(COALESCE(il.available_quantity, 0)) AS available_quantity
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.id
    )
    SELECT COUNT(*) FILTER (WHERE available_quantity = 0) AS out_of_stock_skus
    FROM sku_inventory
    $$,
    NULL,
    'KPI',
    60,
    'SKUs with no available stock remaining.',
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
    '01a066fd-0699-7cb0-8588-23b2f7ce82e2',
    'Sell Through Rate',
    'Product & Inventory Health/Inventory Health/KPI/Sell Through Rate',
    $$
    WITH sku_inventory AS (
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
    sales AS (
        SELECT li.product_variant_id,
               COALESCE(SUM(li.quantity), 0) AS units
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY li.product_variant_id
    ),
    rolled AS (
        SELECT COALESCE(SUM(si.available_quantity), 0) AS available_stock,
               COALESCE(SUM(s.units), 0) AS units
        FROM sku_inventory si
        LEFT JOIN sales s ON s.product_variant_id = si.variant_id
    )
    SELECT ROUND(100.0 * r.units
                 / NULLIF(r.available_stock + r.units, 0), 2) AS sell_through_rate
    FROM rolled r
    $$,
    NULL,
    'KPI',
    60,
    'Units sold as a percentage of units sold plus available stock, for the selected period vs the prior period.',
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
    '01a066fd-069a-7c3c-8bab-ec8e0da32825',
    'Low Stock Revenue Risk',
    'Product & Inventory Health/Replenishment & Stock Risk/KPI/Low Stock Revenue Risk',
    $$
    WITH period AS (
        SELECT GREATEST(COALESCE(:currentEndDate::date,
                                 (SELECT MAX(o.created_at::date) FROM public.fact_order_headers o
                                  WHERE o.seller_id = :shopId AND o.test = FALSE))
                      - COALESCE(:currentStartDate::date,
                                 (SELECT MIN(o.created_at::date) FROM public.fact_order_headers o
                                  WHERE o.seller_id = :shopId AND o.test = FALSE)) + 1, 1) AS days
    ),
    sku_inventory AS (
        SELECT pv.id AS variant_id,
               pv.price,
               SUM(COALESCE(il.available_quantity, 0)) AS available_quantity,
               BOOL_OR(COALESCE(il.available_quantity, 0)
                       <= COALESCE(il.safety_stock_quantity, 0)) AS any_location_low
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.id, pv.price
    ),
    sales AS (
        SELECT li.product_variant_id,
               COALESCE(SUM(li.quantity), 0) AS units
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY li.product_variant_id
    ),
    velocity AS (
        SELECT si.price,
               si.available_quantity,
               si.any_location_low,
               COALESCE(s.units, 0)::numeric / per.days AS per_day
        FROM sku_inventory si
        CROSS JOIN period per
        LEFT JOIN sales s ON s.product_variant_id = si.variant_id
    )
    SELECT ROUND(COALESCE(SUM(
               CASE WHEN any_location_low
                    THEN per_day
                         * GREATEST(7 - available_quantity / NULLIF(per_day, 0), 0)
                         * COALESCE(price, 0)
                    ELSE 0 END), 0), 2) AS low_stock_revenue_risk
    FROM velocity
    $$,
    NULL,
    'KPI',
    60,
    'Revenue at risk from low-stock SKUs over a seven day horizon, for the selected period vs the prior period.',
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
    '01a066fd-069a-74e3-bc1c-df8cb3a99329',
    'Stock Coverage Days',
    'Product & Inventory Health/Replenishment & Stock Risk/KPI/Stock Coverage Days',
    $$
    WITH period AS (
        SELECT GREATEST(COALESCE(:currentEndDate::date,
                                 (SELECT MAX(o.created_at::date) FROM public.fact_order_headers o
                                  WHERE o.seller_id = :shopId AND o.test = FALSE))
                      - COALESCE(:currentStartDate::date,
                                 (SELECT MIN(o.created_at::date) FROM public.fact_order_headers o
                                  WHERE o.seller_id = :shopId AND o.test = FALSE)) + 1, 1) AS days
    ),
    sku_inventory AS (
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
    sales AS (
        SELECT li.product_variant_id,
               COALESCE(SUM(li.quantity), 0) AS units
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY li.product_variant_id
    ),
    velocity AS (
        SELECT si.available_quantity,
               COALESCE(s.units, 0)::numeric / per.days AS per_day
        FROM sku_inventory si
        CROSS JOIN period per
        LEFT JOIN sales s ON s.product_variant_id = si.variant_id
    )
    SELECT ROUND(SUM(available_quantity) / NULLIF(SUM(per_day), 0), 1) AS stock_coverage_days
    FROM velocity
    $$,
    NULL,
    'KPI',
    60,
    'Days of stock cover at the current sales rate, for the selected period vs the prior period.',
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
    '01a066fd-069b-791e-859f-fff53ba5787c',
    'Incoming Stock',
    'Product & Inventory Health/Replenishment & Stock Risk/KPI/Incoming Stock',
    $$
    SELECT COALESCE(SUM(COALESCE(il.incoming_quantity, 0)), 0) AS incoming_stock
    FROM public.dim_inventory_items ii
    JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
    JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
    WHERE ii.seller_id = :shopId
      AND il.seller_id = :shopId
      AND il.is_active = TRUE
    $$,
    NULL,
    'KPI',
    60,
    'Units currently inbound to inventory locations.',
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
    '01a066fd-069c-7314-ad1d-3714729d64a8',
    'Inventory Value',
    'Product & Inventory Health/Inventory Value & Capital/KPI/Inventory Value',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(il.on_hand_quantity, 0)
                              * COALESCE(ii.unit_cost, 0)), 0), 2) AS inventory_value
    FROM public.dim_inventory_items ii
    JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
    JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
    WHERE ii.seller_id = :shopId
      AND il.seller_id = :shopId
      AND il.is_active = TRUE
    $$,
    NULL,
    'KPI',
    60,
    'Total capital tied up in on-hand inventory at unit cost.',
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
    '01a066fd-069c-75ee-8553-9854ebeffc45',
    'Dead Stock Value',
    'Product & Inventory Health/Inventory Value & Capital/KPI/Dead Stock Value',
    $$
    WITH sku_inventory AS (
        SELECT pv.id AS variant_id,
               ii.unit_cost,
               SUM(COALESCE(il.on_hand_quantity, 0)) AS on_hand_quantity
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.id, ii.unit_cost
    ),
    sales AS (
        SELECT li.product_variant_id,
               SUM(li.quantity) AS units
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND (:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)
        GROUP BY li.product_variant_id
    )
    SELECT ROUND(COALESCE(SUM(si.on_hand_quantity * COALESCE(si.unit_cost, 0))
                          FILTER (WHERE s.units IS NULL), 0), 2) AS dead_stock_value
    FROM sku_inventory si
    LEFT JOIN sales s ON s.product_variant_id = si.variant_id
    $$,
    NULL,
    'KPI',
    60,
    'Capital held in SKUs with no sales in the selected period vs the prior period.',
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
    '01a066fd-069c-7836-8347-19c5ef19e315',
    'Damaged Stock Value',
    'Product & Inventory Health/Inventory Value & Capital/KPI/Damaged Stock Value',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(il.damaged_quantity, 0)
                              * COALESCE(ii.unit_cost, 0)), 0), 2) AS damaged_stock_value
    FROM public.dim_inventory_items ii
    JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
    JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
    WHERE ii.seller_id = :shopId
      AND il.seller_id = :shopId
      AND il.is_active = TRUE
    $$,
    NULL,
    'KPI',
    60,
    'Capital held in damaged inventory at unit cost.',
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
    '01a066fd-069d-7d77-806d-5f39f62d1143',
    'Committed Stock',
    'Product & Inventory Health/Fulfillment & Demand/KPI/Committed Stock',
    $$
    SELECT COALESCE(SUM(COALESCE(il.committed_quantity, 0)), 0) AS committed_stock
    FROM public.dim_inventory_levels il
    WHERE il.seller_id = :shopId
      AND il.is_active = TRUE
    $$,
    NULL,
    'KPI',
    60,
    'Stock committed to open orders.',
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
    '01a066fd-069d-7d6c-89c4-c2545a48df03',
    'Reserved Stock',
    'Product & Inventory Health/Fulfillment & Demand/KPI/Reserved Stock',
    $$
    SELECT COALESCE(SUM(COALESCE(il.reserved_quantity, 0)), 0) AS reserved_stock
    FROM public.dim_inventory_levels il
    WHERE il.seller_id = :shopId
      AND il.is_active = TRUE
    $$,
    NULL,
    'KPI',
    60,
    'Stock reserved and not available to sell.',
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
    '01a066fd-069d-7d71-b34f-430af60b31f8',
    'Unfulfilled Stock Demand',
    'Product & Inventory Health/Fulfillment & Demand/KPI/Unfulfilled Stock Demand',
    $$
    SELECT COALESCE(SUM(COALESCE(li.unfulfilled_quantity, 0)), 0) AS unfulfilled_stock_demand
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
    'Units ordered but not yet fulfilled for the selected period vs the prior period.',
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
    '01a066fd-069d-795d-bdef-7288d72f2aac',
    'Active Inventory Locations',
    'Product & Inventory Health/Locations & Operations/KPI/Active Inventory Locations',
    $$
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
    $$,
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
);

-- ---------- 2. chart signals: divergence ----------
-- Only the five metrics that carried a comparison in the source get a signal.

INSERT INTO vizkit.chart_signal (id, chart_id, name, query)
VALUES (
    '019fff82-e31e-7fa1-8f91-5a2b3c4d1001',
    '01a066fd-0699-7cb0-8588-23b2f7ce82e2',
    'sell_through_rate',
    $$
    WITH sku_inventory AS (
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
    sales AS (
        SELECT product_variant_id,
               COALESCE(SUM(quantity) FILTER (WHERE is_current), 0) AS cur_units,
               COALESCE(SUM(quantity) FILTER (WHERE is_prior),   0) AS prv_units
        FROM (
            SELECT li.product_variant_id,
                   li.quantity,
                   ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
        GROUP BY product_variant_id
    ),
    rolled AS (
        SELECT COALESCE(SUM(si.available_quantity), 0) AS available_stock,
               COALESCE(SUM(s.cur_units), 0) AS cur_units,
               COALESCE(SUM(s.prv_units), 0) AS prv_units
        FROM sku_inventory si
        LEFT JOIN sales s ON s.product_variant_id = si.variant_id
    ),
    computed AS (
        SELECT ROUND(100.0 * r.cur_units
                     / NULLIF(r.available_stock + r.cur_units, 0), 2) AS cur_rate,
               ROUND(100.0 * r.prv_units
                     / NULLIF(r.available_stock + r.prv_units, 0), 2) AS prv_rate
        FROM rolled r
    )
    SELECT c.prv_rate AS previous_value,
           ROUND(100 * (c.cur_rate - c.prv_rate)
                 / NULLIF(ABS(c.prv_rate), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fff82-e31e-7fa2-8f92-5a2b3c4d1002',
    '01a066fd-069a-7c3c-8bab-ec8e0da32825',
    'low_stock_revenue_risk',
    $$
    WITH period AS (
        SELECT GREATEST(COALESCE(:currentEndDate::date,
                                 (SELECT MAX(o.created_at::date) FROM public.fact_order_headers o
                                  WHERE o.seller_id = :shopId AND o.test = FALSE))
                      - COALESCE(:currentStartDate::date,
                                 (SELECT MIN(o.created_at::date) FROM public.fact_order_headers o
                                  WHERE o.seller_id = :shopId AND o.test = FALSE)) + 1, 1) AS cur_days,
               GREATEST(:priorEndDate::date - :priorStartDate::date + 1, 1) AS prv_days
    ),
    sku_inventory AS (
        SELECT pv.id AS variant_id,
               pv.price,
               SUM(COALESCE(il.available_quantity, 0)) AS available_quantity,
               BOOL_OR(COALESCE(il.available_quantity, 0)
                       <= COALESCE(il.safety_stock_quantity, 0)) AS any_location_low
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.id, pv.price
    ),
    sales AS (
        SELECT product_variant_id,
               COALESCE(SUM(quantity) FILTER (WHERE is_current), 0) AS cur_units,
               COALESCE(SUM(quantity) FILTER (WHERE is_prior),   0) AS prv_units
        FROM (
            SELECT li.product_variant_id,
                   li.quantity,
                   ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
        GROUP BY product_variant_id
    ),
    velocity AS (
        SELECT si.price,
               si.available_quantity,
               si.any_location_low,
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
                        ELSE 0 END), 0), 2) AS cur_value,
               ROUND(COALESCE(SUM(
                   CASE WHEN any_location_low
                        THEN prv_per_day
                             * GREATEST(7 - available_quantity / NULLIF(prv_per_day, 0), 0)
                             * COALESCE(price, 0)
                        ELSE 0 END), 0), 2) AS prv_value
        FROM velocity
    )
    SELECT c.prv_value AS previous_value,
           ROUND(100 * (c.cur_value - c.prv_value)
                 / NULLIF(ABS(c.prv_value), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fff82-e31e-7fa3-8f93-5a2b3c4d1003',
    '01a066fd-069a-74e3-bc1c-df8cb3a99329',
    'stock_coverage_days',
    $$
    WITH period AS (
        SELECT GREATEST(COALESCE(:currentEndDate::date,
                                 (SELECT MAX(o.created_at::date) FROM public.fact_order_headers o
                                  WHERE o.seller_id = :shopId AND o.test = FALSE))
                      - COALESCE(:currentStartDate::date,
                                 (SELECT MIN(o.created_at::date) FROM public.fact_order_headers o
                                  WHERE o.seller_id = :shopId AND o.test = FALSE)) + 1, 1) AS cur_days,
               GREATEST(:priorEndDate::date - :priorStartDate::date + 1, 1) AS prv_days
    ),
    sku_inventory AS (
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
    sales AS (
        SELECT product_variant_id,
               COALESCE(SUM(quantity) FILTER (WHERE is_current), 0) AS cur_units,
               COALESCE(SUM(quantity) FILTER (WHERE is_prior),   0) AS prv_units
        FROM (
            SELECT li.product_variant_id,
                   li.quantity,
                   ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
        GROUP BY product_variant_id
    ),
    velocity AS (
        SELECT si.available_quantity,
               COALESCE(s.cur_units, 0)::numeric / per.cur_days AS cur_per_day,
               COALESCE(s.prv_units, 0)::numeric / per.prv_days AS prv_per_day
        FROM sku_inventory si
        CROSS JOIN period per
        LEFT JOIN sales s ON s.product_variant_id = si.variant_id
    ),
    computed AS (
        SELECT ROUND(SUM(available_quantity) / NULLIF(SUM(cur_per_day), 0), 1) AS cur_cover,
               ROUND(SUM(available_quantity) / NULLIF(SUM(prv_per_day), 0), 1) AS prv_cover
        FROM velocity
    )
    SELECT c.prv_cover AS previous_value,
           ROUND(100 * (c.cur_cover - c.prv_cover)
                 / NULLIF(ABS(c.prv_cover), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fff82-e31e-7fa4-8f94-5a2b3c4d1004',
    '01a066fd-069c-75ee-8553-9854ebeffc45',
    'dead_stock_value',
    $$
    WITH sku_inventory AS (
        SELECT pv.id AS variant_id,
               ii.unit_cost,
               SUM(COALESCE(il.on_hand_quantity, 0)) AS on_hand_quantity
        FROM public.dim_inventory_items ii
        JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        JOIN public.dim_inventory_levels il ON il.inventory_item_id = ii.id
        WHERE ii.seller_id = :shopId
          AND il.seller_id = :shopId
          AND il.is_active = TRUE
        GROUP BY pv.id, ii.unit_cost
    ),
    sales AS (
        SELECT product_variant_id,
               SUM(quantity) FILTER (WHERE is_current) AS cur_units,
               SUM(quantity) FILTER (WHERE is_prior)   AS prv_units
        FROM (
            SELECT li.product_variant_id,
                   li.quantity,
                   ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
        GROUP BY product_variant_id
    ),
    computed AS (
        SELECT ROUND(COALESCE(SUM(si.on_hand_quantity * COALESCE(si.unit_cost, 0))
                              FILTER (WHERE s.cur_units IS NULL), 0), 2) AS cur_value,
               ROUND(COALESCE(SUM(si.on_hand_quantity * COALESCE(si.unit_cost, 0))
                              FILTER (WHERE s.prv_units IS NULL), 0), 2) AS prv_value
        FROM sku_inventory si
        LEFT JOIN sales s ON s.product_variant_id = si.variant_id
    )
    SELECT c.prv_value AS previous_value,
           ROUND(100 * (c.cur_value - c.prv_value)
                 / NULLIF(ABS(c.prv_value), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fff82-e31e-7fa5-8f95-5a2b3c4d1005',
    '01a066fd-069d-7d71-b34f-430af60b31f8',
    'unfulfilled_stock_demand',
    $$
    WITH unfulfilled AS (
        SELECT COALESCE(SUM(unfulfilled_quantity) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(unfulfilled_quantity) FILTER (WHERE is_prior),   0) AS prv_value
        FROM (
            SELECT COALESCE(li.unfulfilled_quantity, 0) AS unfulfilled_quantity,
                   ((:currentStartDate::date IS NULL OR o.created_at::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR o.created_at::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND o.created_at::date BETWEEN :priorStartDate::date AND :priorEndDate::date)         AS is_prior
            FROM public.fact_order_line_items li
            JOIN public.fact_order_headers o ON o.id = li.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
        ) t
        WHERE t.is_current OR t.is_prior
    )
    SELECT u.prv_value AS previous_value,
           ROUND(100.0 * (u.cur_value - u.prv_value)
                 / NULLIF(ABS(u.prv_value), 0), 2) AS divergence
    FROM unfulfilled u
    $$
);
