-- ---------- charts: one metric each ----------

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
'01a066fe-c9e2-7a28-980d-75040e670dce',
        'Active Locations',
        'Inventory Location/Location Overview/KPI/Active Locations',
        $$
    SELECT COUNT(*) FILTER (WHERE loc.is_active) AS active_locations
    FROM public.dim_inventory_locations loc
    WHERE loc.seller_id = :shopId
    $$,
'{"helperText": "See how many of your locations are currently active, so you know the size of your live location network."}',
        'KPI',
        60,
        'Count of active inventory locations.',
        '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
        '01a066fe-c9e3-70b7-9314-8667e5320bd9',
        'Locations With Active Inventory',
        'Inventory Location/Location Overview/KPI/Locations With Active Inventory',
        $$
    SELECT COUNT(*) FILTER (WHERE loc.has_active_inventory) AS locations_with_active_inventory
    FROM public.dim_inventory_locations loc
    WHERE loc.seller_id = :shopId
    $$,
'{"helperText": "See how many locations are currently holding active inventory, so you know how many sites are actually stocked."}',
        'KPI',
        60,
        'Count of locations currently holding active inventory.',
        '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
        '01a066fe-c9e3-78ac-bfcd-bf619893fd82',
        'Total Stock Across Locations',
        'Inventory Location/Location Overview/KPI/Total Stock Across Locations',
        $$
    SELECT COALESCE(SUM(il.on_hand_quantity), 0) AS total_stock_across_locations
    FROM public.dim_inventory_levels il
    WHERE il.seller_id = :shopId
      AND il.is_active = TRUE
    $$,
'{"helperText": "See the total on-hand units held across all your locations, so you know your overall stock volume."}',
        'KPI',
        60,
        'Total on-hand units held across all locations.',
        '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
        '01a066fe-c9e4-794b-ad24-967898c65b0c',
        'Available Stock',
        'Inventory Location/Inventory Health by Location/KPI/Available Stock',
        $$
    SELECT COALESCE(SUM(il.available_quantity), 0) AS available_stock
    FROM public.dim_inventory_levels il
    WHERE il.seller_id = :shopId
      AND il.is_active = TRUE
    $$,
'{"helperText": "See how many units are available to sell across all locations, so you know what''s ready for customers right now."}',
        'KPI',
        60,
        'Units available to sell across all locations.',
        '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
        '01a066fe-c9e4-7d6b-91f1-edfdc1dade35',
        'Committed Stock',
        'Inventory Location/Inventory Health by Location/KPI/Committed Stock',
        $$
    SELECT COALESCE(SUM(il.committed_quantity), 0) AS committed_stock
    FROM public.dim_inventory_levels il
    WHERE il.seller_id = :shopId
      AND il.is_active = TRUE
    $$,
'{"helperText": "See how many units are committed to open orders across all locations, so you know how much stock is already spoken for."}',
        'KPI',
        60,
        'Units committed to open orders across all locations.',
        '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
        '01a066fe-c9e4-76ae-8776-ce51271f788c',
        'Reserved Stock',
        'Inventory Location/Inventory Health by Location/KPI/Reserved Stock',
        $$
    SELECT COALESCE(SUM(il.reserved_quantity), 0) AS reserved_stock
    FROM public.dim_inventory_levels il
    WHERE il.seller_id = :shopId
      AND il.is_active = TRUE
    $$,
'{"helperText": "See how many units are reserved and unavailable to sell across all locations, so you understand what''s set aside."}',
        'KPI',
        60,
        'Units reserved and unavailable to sell across all locations.',
        '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
        '01a066fe-c9e4-7ddc-aad7-ab1097bd5872',
        'Damaged Stock',
        'Inventory Location/Inventory Health by Location/KPI/Damaged Stock',
        $$
    SELECT COALESCE(SUM(il.damaged_quantity), 0) AS damaged_stock
    FROM public.dim_inventory_levels il
    WHERE il.seller_id = :shopId
      AND il.is_active = TRUE
    $$,
'{"helperText": "See how many units are marked damaged across all locations, so you can track losses from damaged inventory."}',
        'KPI',
        60,
        'Damaged units held across all locations.',
        '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
        '01a066fe-c9e5-79b2-b39d-124b9a1941ca',
        'Low Stock SKUs',
        'Inventory Location/Replenishment & Stock Risk/KPI/Low Stock SKUs',
        $$
    SELECT COUNT(*) FILTER (WHERE COALESCE(il.available_quantity, 0)
                                 <= COALESCE(il.safety_stock_quantity, 0)) AS low_stock_skus
    FROM public.dim_inventory_levels il
    WHERE il.seller_id = :shopId
      AND il.is_active = TRUE
    $$,
'{"helperText": "See how many SKUs are at or below their safety stock threshold, so you know how many items need reordering soon."}',
        'KPI',
        60,
        'Inventory levels at or below their safety stock threshold.',
        '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
        '01a066fe-c9e5-713c-a95d-2beeeca7a8dd',
        'Out of Stock SKUs',
        'Inventory Location/Replenishment & Stock Risk/KPI/Out of Stock SKUs',
        $$
    SELECT COUNT(*) FILTER (WHERE COALESCE(il.available_quantity, 0) = 0) AS out_of_stock_skus
    FROM public.dim_inventory_levels il
    WHERE il.seller_id = :shopId
      AND il.is_active = TRUE
    $$,
'{"helperText": "See how many SKUs currently have zero available stock, so you know how many items risk missed sales."}',
        'KPI',
        60,
        'Inventory levels with no available stock remaining.',
        '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
        '01a066fe-c9e5-771c-9979-ddb874ff1002',
        'Incoming Stock',
        'Inventory Location/Replenishment & Stock Risk/KPI/Incoming Stock',
        $$
    SELECT COALESCE(SUM(il.incoming_quantity), 0) AS incoming_stock
    FROM public.dim_inventory_levels il
    WHERE il.seller_id = :shopId
      AND il.is_active = TRUE
    $$,
'{"helperText": "See how many units are currently inbound across all locations, so you know what replenishment is on the way."}',
        'KPI',
        60,
        'Units currently inbound across all locations.',
        '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
        '01a066fe-c9e7-7f12-86db-f311cfd5460f',
        'Fulfillment Risk Locations',
        'Inventory Location/Fulfillment & Operational Risk/KPI/Fulfillment Risk Locations',
        $$
    SELECT COUNT(*) FILTER (WHERE loc.has_unfulfilled_orders) AS fulfillment_risk_locations
    FROM public.dim_inventory_locations loc
    WHERE loc.seller_id = :shopId
    $$,
'{"helperText": "See how many locations have pending unfulfilled orders, so you know where fulfillment delays might be building up."}',
        'KPI',
        60,
        'Locations with pending unfulfilled orders.',
        '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
        '01a066fe-c9e7-7716-8662-cf1e4634476e',
        'Inventory Value',
        'Inventory Location/Inventory Value & Asset Management/KPI/Inventory Value',
        $$
    SELECT ROUND(COALESCE(SUM(COALESCE(il.on_hand_quantity, 0)
                              * COALESCE(ii.unit_cost, 0)), 0), 2) AS inventory_value
    FROM public.dim_inventory_levels il
    LEFT JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
                               AND ii.seller_id = :shopId
    WHERE il.seller_id = :shopId
      AND il.is_active = TRUE
    $$,
'{"helperText": "See the total value of your on-hand inventory at cost, so you know how much capital is tied up in stock."}',
        'KPI',
        60,
        'Total on-hand inventory valuation at unit cost.',
        '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
        '01a066fe-c9e7-7013-9e63-3506655dd9ab',
        'Non-Sellable Stock',
        'Inventory Location/Inventory Value & Asset Management/KPI/Non-Sellable Stock',
        $$
    SELECT COALESCE(SUM(COALESCE(il.damaged_quantity, 0)
                      + COALESCE(il.quality_control_quantity, 0)
                      + COALESCE(il.reserved_quantity, 0)), 0) AS non_sellable_stock
    FROM public.dim_inventory_levels il
    WHERE il.seller_id = :shopId
      AND il.is_active = TRUE
    $$,
'{"helperText": "See how many units are damaged, in quality control, or reserved — and therefore not sellable — so you understand how much stock isn''t contributing to revenue."}',
        'KPI',
        60,
        'Units held as damaged, in quality control, or reserved.',
        '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
        '01a066fe-c9e8-7a2d-8acd-b64c514f0f14',
        'Inactive Locations With Stock',
        'Inventory Location/Location Governance & Special Operations/KPI/Inactive Locations With Stock',
        $$
    WITH location_stock AS (
        SELECT loc.id AS location_id,
               COALESCE(loc.is_active, TRUE) AS is_active,
               COALESCE(SUM(il.on_hand_quantity), 0) AS on_hand_quantity
        FROM public.dim_inventory_locations loc
        LEFT JOIN public.dim_inventory_levels il
               ON il.inventory_location_id = loc.id
              AND il.seller_id = :shopId
        WHERE loc.seller_id = :shopId
        GROUP BY loc.id, loc.is_active
    )
    SELECT COUNT(*) FILTER (WHERE NOT ls.is_active AND ls.on_hand_quantity > 0)
           AS inactive_locations_with_stock
    FROM location_stock ls
    $$,
'{"helperText": "See how many deactivated locations are still holding on-hand stock, so you can spot inventory that needs to be moved or written off."}',
        'KPI',
        60,
        'Deactivated locations still holding on-hand stock.',
        '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
),
    (
        '01a066fe-c9e9-7e71-865c-7918ba4ceeb0',
        'Fulfillment Service Locations',
        'Inventory Location/Location Governance & Special Operations/KPI/Fulfillment Service Locations',
        $$
    SELECT COUNT(*) FILTER (WHERE COALESCE(loc.is_fulfillment_service, FALSE))
           AS fulfillment_service_locations
    FROM public.dim_inventory_locations loc
    WHERE loc.seller_id = :shopId
    $$,
'{"helperText": "See how many of your locations operate as third-party fulfillment services, so you understand your fulfillment network setup."}',
        'KPI',
        60,
        'Locations operated as a third-party fulfillment service.',
        '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "priorStartDate":   { "source": "REQUEST_FILTER", "filterKey": "prevStartDate" },
        "priorEndDate":     { "source": "REQUEST_FILTER", "filterKey": "prevEndDate" }
      },
      "excludeExtraParams": true
    }'
);