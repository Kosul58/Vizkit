--liquibase formatted sql logicalFilePath:20260814001_analytical_inventory_location.sql

--changeset saugat:RW-48-1
--comment seed Location Overview tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff9a-1dfc-7913-b680-280fa241f5c5',
    'Location Overview KPIs',
    'Inventory Location/Location Overview/KPI/Location Overview KPIs',
    '
    WITH location_totals AS (
        SELECT COUNT(*) FILTER (WHERE loc.is_active) AS active_locations,
               COUNT(*) FILTER (WHERE loc.has_active_inventory) AS locations_with_active_inventory
        FROM public.dim_inventory_locations loc
        WHERE loc.seller_id = :shopId
    ),
    stock_totals AS (
        SELECT COALESCE(SUM(il.on_hand_quantity), 0) AS total_stock
        FROM public.dim_inventory_levels il
        WHERE il.seller_id = :shopId
          AND il.is_active = TRUE
    )
    SELECT lt.active_locations AS active_locations,
           lt.locations_with_active_inventory AS locations_with_active_inventory,
           st.total_stock AS total_stock_across_locations
    FROM location_totals lt
    CROSS JOIN stock_totals st
    ',
    NULL,
    'KPI',
    60,
    'Location overview KPIs showing count of active locations, locations with active inventory, and total stock across locations.',
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
    '019fff9a-1dfc-7221-83be-9ef1db174eef',
    'Stock by Location',
    'Inventory Location/Location Overview/PLOT/Stock by Location',
    '
    WITH location_stock AS (
        SELECT loc.id AS location_id,
               COALESCE(loc.name, ''Unknown'') AS location_name,
               COALESCE(SUM(il.available_quantity), 0) AS available_quantity,
               COALESCE(SUM(il.committed_quantity), 0) AS committed_quantity,
               COALESCE(SUM(il.reserved_quantity), 0) AS reserved_quantity
        FROM public.dim_inventory_locations loc
        LEFT JOIN public.dim_inventory_levels il
               ON il.inventory_location_id = loc.id
              AND il.seller_id = :shopId
              AND il.is_active = TRUE
        WHERE loc.seller_id = :shopId
        GROUP BY loc.id, loc.name
    )
    SELECT ls.location_name AS location,
           ls.available_quantity AS available_quantity,
           ls.committed_quantity AS committed_quantity,
           ls.reserved_quantity AS reserved_quantity
    FROM location_stock ls
    ORDER BY (ls.available_quantity + ls.committed_quantity + ls.reserved_quantity) DESC,
             ls.location_name, ls.location_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Stock breakdown by location showing available, committed, and reserved quantities.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff9a-1dfc-7a67-a13a-f4be3232af49',
    'Available Stock by Location',
    'Inventory Location/Location Overview/PLOT/Available Stock by Location',
    '
    WITH location_stock AS (
        SELECT loc.id AS location_id,
               COALESCE(loc.name, ''Unknown'') AS location_name,
               COALESCE(SUM(il.available_quantity), 0) AS available_quantity
        FROM public.dim_inventory_locations loc
        LEFT JOIN public.dim_inventory_levels il
               ON il.inventory_location_id = loc.id
              AND il.seller_id = :shopId
              AND il.is_active = TRUE
        WHERE loc.seller_id = :shopId
        GROUP BY loc.id, loc.name
    )
    SELECT ls.location_name AS location,
           ls.available_quantity AS available_quantity
    FROM location_stock ls
    ORDER BY ls.available_quantity DESC, ls.location_name, ls.location_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Available sellable stock quantity per store/warehouse location.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff9a-1dfc-7f1c-8633-d54b46a9f55e',
    'Location Inventory Summary',
    'Inventory Location/Location Overview/TABLE/Location Inventory Summary',
    '
    WITH location_stock AS (
        SELECT loc.id AS location_id,
               COALESCE(loc.name, ''Unknown'') AS location_name,
               COALESCE(loc.is_active, FALSE) AS is_active,
               loc.address,
               COALESCE(SUM(il.available_quantity), 0) AS available_quantity,
               COALESCE(SUM(il.on_hand_quantity), 0)   AS on_hand_quantity,
               COALESCE(SUM(il.committed_quantity), 0) AS committed_quantity,
               COALESCE(SUM(il.reserved_quantity), 0)  AS reserved_quantity,
               COALESCE(SUM(il.damaged_quantity), 0)   AS damaged_quantity,
               COALESCE(SUM(il.incoming_quantity), 0)  AS incoming_quantity
        FROM public.dim_inventory_locations loc
        LEFT JOIN public.dim_inventory_levels il
               ON il.inventory_location_id = loc.id
              AND il.seller_id = :shopId
              AND il.is_active = TRUE
        WHERE loc.seller_id = :shopId
        GROUP BY loc.id, loc.name, loc.is_active, loc.address
    )
    SELECT ls.location_name AS location,
           CASE WHEN ls.is_active THEN ''Active'' ELSE ''Inactive'' END AS active_status,
           CASE WHEN LENGTH(CONCAT_WS(CHR(44) || CHR(32),
                         ls.address #>> ''{address1}'', ls.address #>> ''{city}'',
                         ls.address #>> ''{province}'', ls.address #>> ''{country}'')) > 0
                THEN CONCAT_WS(CHR(44) || CHR(32),
                         ls.address #>> ''{address1}'', ls.address #>> ''{city}'',
                         ls.address #>> ''{province}'', ls.address #>> ''{country}'')
                ELSE ''Unknown'' END AS address,
           ls.available_quantity AS available_quantity,
           ls.on_hand_quantity   AS on_hand_quantity,
           ls.committed_quantity AS committed_quantity,
           ls.reserved_quantity  AS reserved_quantity,
           ls.damaged_quantity   AS damaged_quantity,
           ls.incoming_quantity  AS incoming_quantity,
           COUNT(*) OVER() AS total_records
    FROM location_stock ls
    ORDER BY ls.on_hand_quantity DESC, ls.location_name, ls.location_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Summary table per location showing active status, full address, available, on hand, committed, reserved, damaged, and incoming inventory counts.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff9a-1dfc-7fe3-864f-63a5e46aba11',
    'SKU by Location Report',
    'Inventory Location/Location Overview/TABLE/SKU by Location Report',
    '
    WITH level_rows AS (
        SELECT il.id AS level_id,
               COALESCE(loc.name, ''Unknown'') AS location_name,
               COALESCE(ii.sku, pv.sku, ''Unknown'') AS sku,
               COALESCE(p.title, ''Unknown'') AS product,
               COALESCE(il.available_quantity, 0)    AS available_quantity,
               COALESCE(il.on_hand_quantity, 0)      AS on_hand_quantity,
               COALESCE(il.committed_quantity, 0)    AS committed_quantity,
               COALESCE(il.reserved_quantity, 0)     AS reserved_quantity,
               COALESCE(il.safety_stock_quantity, 0) AS safety_stock_quantity
        FROM public.dim_inventory_levels il
        JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
        LEFT JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        LEFT JOIN public.dim_products p ON p.id = pv.product_id
        LEFT JOIN public.dim_inventory_locations loc ON loc.id = il.inventory_location_id
        WHERE il.seller_id = :shopId
          AND ii.seller_id = :shopId
          AND il.is_active = TRUE
    )
    SELECT lr.location_name AS location,
           lr.sku AS sku,
           lr.product AS product,
           lr.available_quantity    AS available_quantity,
           lr.on_hand_quantity      AS on_hand_quantity,
           lr.committed_quantity    AS committed_quantity,
           lr.reserved_quantity     AS reserved_quantity,
           lr.safety_stock_quantity AS safety_stock_quantity,
           CASE
               WHEN lr.available_quantity = 0 THEN ''Out of Stock''
               WHEN lr.available_quantity <= lr.safety_stock_quantity THEN ''Low Stock''
               WHEN lr.available_quantity > lr.safety_stock_quantity * 3 THEN ''Overstock''
               ELSE ''In Stock''
           END AS stock_status,
           COUNT(*) OVER() AS total_records
    FROM level_rows lr
    ORDER BY lr.available_quantity ASC, lr.sku, lr.location_name, lr.level_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Detailed SKU breakdown table per location showing available, on hand, committed, reserved, safety stock, and stock health status.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
);

--changeset saugat:RW-48-2
--comment seed Inventory Health by Location tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff9a-1dfc-78bc-b6ad-abdbad79f1e3',
    'Stock Status KPIs',
    'Inventory Location/Inventory Health by Location/KPI/Stock Status KPIs',
    '
    SELECT COALESCE(SUM(il.available_quantity), 0) AS available_stock,
           COALESCE(SUM(il.committed_quantity), 0) AS committed_stock,
           COALESCE(SUM(il.reserved_quantity), 0)  AS reserved_stock,
           COALESCE(SUM(il.damaged_quantity), 0)   AS damaged_stock
    FROM public.dim_inventory_levels il
    WHERE il.seller_id = :shopId
      AND il.is_active = TRUE
    ',
    NULL,
    'KPI',
    60,
    'Inventory health KPIs evaluating total available stock, committed stock, reserved stock, and damaged stock.',
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
    '019fff9a-1dfc-79fc-9640-ef363d7491af',
    'Stock Composition by Location',
    'Inventory Location/Inventory Health by Location/PLOT/Stock Composition by Location',
    '
    WITH location_stock AS (
        SELECT loc.id AS location_id,
               COALESCE(loc.name, ''Unknown'') AS location_name,
               COALESCE(SUM(il.available_quantity), 0)       AS available_quantity,
               COALESCE(SUM(il.committed_quantity), 0)       AS committed_quantity,
               COALESCE(SUM(il.reserved_quantity), 0)        AS reserved_quantity,
               COALESCE(SUM(il.damaged_quantity), 0)         AS damaged_quantity,
               COALESCE(SUM(il.quality_control_quantity), 0) AS quality_control_quantity
        FROM public.dim_inventory_locations loc
        LEFT JOIN public.dim_inventory_levels il
               ON il.inventory_location_id = loc.id
              AND il.seller_id = :shopId
              AND il.is_active = TRUE
        WHERE loc.seller_id = :shopId
        GROUP BY loc.id, loc.name
    )
    SELECT ls.location_name AS location,
           ls.available_quantity       AS available_quantity,
           ls.committed_quantity       AS committed_quantity,
           ls.reserved_quantity        AS reserved_quantity,
           ls.damaged_quantity         AS damaged_quantity,
           ls.quality_control_quantity AS quality_control_quantity
    FROM location_stock ls
    ORDER BY (ls.available_quantity + ls.committed_quantity + ls.reserved_quantity
              + ls.damaged_quantity + ls.quality_control_quantity) DESC,
             ls.location_name, ls.location_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Stock state composition across location sites (available, committed, reserved, damaged, QC).',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff9a-1dfc-77e4-91ed-7ffbb2ad68bb',
    'Location Stock Health Matrix',
    'Inventory Location/Inventory Health by Location/PLOT/Location Stock Health Matrix',
    '
    WITH level_rows AS (
        SELECT loc.id AS location_id,
               COALESCE(loc.name, ''Unknown'') AS location_name,
               COALESCE(il.available_quantity, 0)    AS available_quantity,
               COALESCE(il.safety_stock_quantity, 0) AS safety_stock_quantity,
               COALESCE(il.damaged_quantity, 0)      AS damaged_quantity,
               COALESCE(il.reserved_quantity, 0)     AS reserved_quantity
        FROM public.dim_inventory_locations loc
        LEFT JOIN public.dim_inventory_levels il
               ON il.inventory_location_id = loc.id
              AND il.seller_id = :shopId
              AND il.is_active = TRUE
        WHERE loc.seller_id = :shopId
    )
    SELECT lr.location_name AS location,
           COUNT(*) FILTER (WHERE lr.available_quantity > 0
                              AND lr.available_quantity <= lr.safety_stock_quantity) AS "Low Stock",
           COUNT(*) FILTER (WHERE lr.available_quantity = 0)  AS "Out of Stock",
           COUNT(*) FILTER (WHERE lr.damaged_quantity > 0)    AS "Damaged",
           COUNT(*) FILTER (WHERE lr.reserved_quantity > 0)   AS "Reserved"
    FROM level_rows lr
    GROUP BY lr.location_id, lr.location_name
    ORDER BY lr.location_name, lr.location_id
    ',
    NULL,
    'PLOT',
    60,
    'Health condition count matrix across locations showing low stock, out of stock, damaged, and reserved items.',
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
    '019fff9a-1dfc-723b-8e67-79ec0caf69e6',
    'Damaged Stock by Location',
    'Inventory Location/Inventory Health by Location/PLOT/Damaged Stock by Location',
    '
    WITH location_damage AS (
        SELECT loc.id AS location_id,
               COALESCE(loc.name, ''Unknown'') AS location_name,
               COALESCE(SUM(il.damaged_quantity), 0) AS damaged_quantity,
               COALESCE(SUM(COALESCE(il.damaged_quantity, 0)
                            * COALESCE(ii.unit_cost, 0)), 0) AS damaged_value
        FROM public.dim_inventory_locations loc
        LEFT JOIN public.dim_inventory_levels il
               ON il.inventory_location_id = loc.id
              AND il.seller_id = :shopId
              AND il.is_active = TRUE
        LEFT JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
        WHERE loc.seller_id = :shopId
        GROUP BY loc.id, loc.name
    )
    SELECT ld.location_name AS location,
           ld.damaged_quantity AS damaged_quantity,
           ROUND(ld.damaged_value, 2) AS damaged_value
    FROM location_damage ld
    ORDER BY ld.damaged_value DESC, ld.location_name, ld.location_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Damaged stock quantity and loss dollar value per location.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff9a-1dfc-771c-a028-9b840c9feeec',
    'Damaged / QC Stock Report',
    'Inventory Location/Inventory Health by Location/TABLE/Damaged / QC Stock Report',
    '
    WITH level_rows AS (
        SELECT il.id AS level_id,
               COALESCE(loc.name, ''Unknown'') AS location_name,
               COALESCE(ii.sku, pv.sku, ''Unknown'') AS sku,
               COALESCE(p.title, ''Unknown'') AS product,
               COALESCE(il.damaged_quantity, 0) AS damaged_quantity,
               COALESCE(il.quality_control_quantity, 0) AS quality_control_quantity,
               COALESCE(ii.unit_cost, 0) AS unit_cost
        FROM public.dim_inventory_levels il
        JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
        LEFT JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        LEFT JOIN public.dim_products p ON p.id = pv.product_id
        LEFT JOIN public.dim_inventory_locations loc ON loc.id = il.inventory_location_id
        WHERE il.seller_id = :shopId
          AND ii.seller_id = :shopId
          AND il.is_active = TRUE
          AND (COALESCE(il.damaged_quantity, 0) > 0
            OR COALESCE(il.quality_control_quantity, 0) > 0)
    )
    SELECT lr.location_name AS location,
           lr.sku AS sku,
           lr.product AS product,
           lr.damaged_quantity AS damaged_quantity,
           lr.quality_control_quantity AS quality_control_quantity,
           ROUND(lr.unit_cost, 2) AS unit_cost,
           ROUND((lr.damaged_quantity + lr.quality_control_quantity)
                 * lr.unit_cost, 2) AS blocked_value,
           COUNT(*) OVER() AS total_records
    FROM level_rows lr
    ORDER BY (lr.damaged_quantity + lr.quality_control_quantity) * lr.unit_cost DESC,
             lr.sku, lr.level_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Report table listing damaged and quality-control held stock SKUs with unit cost and blocked dollar value.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
);

--changeset saugat:RW-48-3
--comment seed Replenishment & Stock Risk tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff9a-1dfc-7cb8-9c5e-132d1a372cbe',
    'Replenishment KPIs',
    'Inventory Location/Replenishment & Stock Risk/KPI/Replenishment KPIs',
    '
    SELECT COUNT(*) FILTER (WHERE COALESCE(il.available_quantity, 0)
                                 <= COALESCE(il.safety_stock_quantity, 0)) AS low_stock_skus,
           COUNT(*) FILTER (WHERE COALESCE(il.available_quantity, 0) = 0)  AS out_of_stock_skus,
           COALESCE(SUM(il.incoming_quantity), 0) AS incoming_stock
    FROM public.dim_inventory_levels il
    WHERE il.seller_id = :shopId
      AND il.is_active = TRUE
    ',
    NULL,
    'KPI',
    60,
    'Replenishment KPIs tracking count of low stock SKUs, out of stock SKUs, and incoming stock quantity.',
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
    '019fff9a-1dfc-7902-8a87-fca49495f135',
    'Low-Stock SKUs by Location',
    'Inventory Location/Replenishment & Stock Risk/PLOT/Low-Stock SKUs by Location',
    '
    WITH location_rows AS (
        SELECT loc.id AS location_id,
               COALESCE(loc.name, ''Unknown'') AS location_name,
               COUNT(il.id) FILTER (WHERE COALESCE(il.available_quantity, 0)
                                        <= COALESCE(il.safety_stock_quantity, 0)) AS low_stock_skus
        FROM public.dim_inventory_locations loc
        LEFT JOIN public.dim_inventory_levels il
               ON il.inventory_location_id = loc.id
              AND il.seller_id = :shopId
              AND il.is_active = TRUE
        WHERE loc.seller_id = :shopId
        GROUP BY loc.id, loc.name
    )
    SELECT lr.location_name AS location,
           lr.low_stock_skus AS low_stock_skus
    FROM location_rows lr
    ORDER BY lr.low_stock_skus DESC, lr.location_name, lr.location_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Low-stock SKU count per location site.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff9a-1dfc-7c07-a554-8e4ab001e903',
    'Out-of-Stock SKUs by Location',
    'Inventory Location/Replenishment & Stock Risk/PLOT/Out-of-Stock SKUs by Location',
    '
    WITH location_rows AS (
        SELECT loc.id AS location_id,
               COALESCE(loc.name, ''Unknown'') AS location_name,
               COUNT(il.id) FILTER (WHERE COALESCE(il.available_quantity, 0) = 0)
                 AS out_of_stock_skus
        FROM public.dim_inventory_locations loc
        LEFT JOIN public.dim_inventory_levels il
               ON il.inventory_location_id = loc.id
              AND il.seller_id = :shopId
              AND il.is_active = TRUE
        WHERE loc.seller_id = :shopId
        GROUP BY loc.id, loc.name
    )
    SELECT lr.location_name AS location,
           lr.out_of_stock_skus AS out_of_stock_skus
    FROM location_rows lr
    ORDER BY lr.out_of_stock_skus DESC, lr.location_name, lr.location_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Out-of-stock SKU count per location site.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff9a-1dfc-7c2d-beb8-ea50708414ee',
    'Incoming vs Available Stock',
    'Inventory Location/Replenishment & Stock Risk/PLOT/Incoming vs Available Stock',
    '
    WITH location_stock AS (
        SELECT loc.id AS location_id,
               COALESCE(loc.name, ''Unknown'') AS location_name,
               COALESCE(SUM(il.incoming_quantity), 0)  AS incoming_quantity,
               COALESCE(SUM(il.available_quantity), 0) AS available_quantity
        FROM public.dim_inventory_locations loc
        LEFT JOIN public.dim_inventory_levels il
               ON il.inventory_location_id = loc.id
              AND il.seller_id = :shopId
              AND il.is_active = TRUE
        WHERE loc.seller_id = :shopId
        GROUP BY loc.id, loc.name
    )
    SELECT ls.location_name AS location,
           ls.incoming_quantity  AS incoming_quantity,
           ls.available_quantity AS available_quantity
    FROM location_stock ls
    ORDER BY ls.available_quantity DESC, ls.location_name, ls.location_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Comparison per location between incoming replenishment stock and current available stock.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff9a-1dfc-7b18-90b7-5eaf4d0062d7',
    'Low Stock by Location Report',
    'Inventory Location/Replenishment & Stock Risk/TABLE/Low Stock by Location Report',
    '
    WITH level_rows AS (
        SELECT il.id AS level_id,
               COALESCE(loc.name, ''Unknown'') AS location_name,
               COALESCE(ii.sku, pv.sku, ''Unknown'') AS sku,
               COALESCE(p.title, ''Unknown'') AS product,
               COALESCE(il.available_quantity, 0)    AS available_quantity,
               COALESCE(il.safety_stock_quantity, 0) AS safety_stock_quantity,
               COALESCE(il.incoming_quantity, 0)     AS incoming_quantity
        FROM public.dim_inventory_levels il
        JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
        LEFT JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        LEFT JOIN public.dim_products p ON p.id = pv.product_id
        LEFT JOIN public.dim_inventory_locations loc ON loc.id = il.inventory_location_id
        WHERE il.seller_id = :shopId
          AND ii.seller_id = :shopId
          AND il.is_active = TRUE
          AND COALESCE(il.available_quantity, 0) <= COALESCE(il.safety_stock_quantity, 0)
    )
    SELECT lr.location_name AS location,
           lr.sku AS sku,
           lr.product AS product,
           lr.available_quantity    AS available_quantity,
           lr.safety_stock_quantity AS safety_stock_quantity,
           lr.incoming_quantity     AS incoming_quantity,
           CASE
               WHEN lr.available_quantity = 0 AND lr.incoming_quantity = 0 THEN ''Critical''
               WHEN lr.available_quantity + lr.incoming_quantity
                    <= lr.safety_stock_quantity THEN ''High''
               ELSE ''Medium''
           END AS reorder_priority,
           COUNT(*) OVER() AS total_records
    FROM level_rows lr
    ORDER BY (lr.available_quantity + lr.incoming_quantity - lr.safety_stock_quantity) ASC,
             lr.available_quantity ASC, lr.sku, lr.level_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Low stock alert report table listing location, SKU, product, available quantity, safety threshold, incoming stock, and calculated reorder priority.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff9a-1dfc-7fc3-8116-62b95b12534e',
    'Out-of-Stock by Location Report',
    'Inventory Location/Replenishment & Stock Risk/TABLE/Out-of-Stock by Location Report',
    '
    WITH last_sale AS (
        SELECT li.product_variant_id,
               MAX(o.created_at) AS last_sold_at
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
        GROUP BY li.product_variant_id
    ),
    level_rows AS (
        SELECT il.id AS level_id,
               COALESCE(loc.name, ''Unknown'') AS location_name,
               COALESCE(ii.sku, pv.sku, ''Unknown'') AS sku,
               COALESCE(p.title, ''Unknown'') AS product,
               ls.last_sold_at,
               COALESCE(il.available_quantity, 0) AS available_quantity,
               COALESCE(il.incoming_quantity, 0)  AS incoming_quantity
        FROM public.dim_inventory_levels il
        JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
        LEFT JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        LEFT JOIN public.dim_products p ON p.id = pv.product_id
        LEFT JOIN public.dim_inventory_locations loc ON loc.id = il.inventory_location_id
        LEFT JOIN last_sale ls ON ls.product_variant_id = pv.id
        WHERE il.seller_id = :shopId
          AND ii.seller_id = :shopId
          AND il.is_active = TRUE
          AND COALESCE(il.available_quantity, 0) = 0
    )
    SELECT lr.location_name AS location,
           lr.sku AS sku,
           lr.product AS product,
           lr.last_sold_at::date::text AS last_sold_date,
           lr.available_quantity AS available_quantity,
           lr.incoming_quantity  AS incoming_quantity,
           COUNT(*) OVER() AS total_records
    FROM level_rows lr
    ORDER BY lr.last_sold_at DESC NULLS LAST, lr.sku, lr.level_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Out-of-stock report table listing out-of-stock SKUs per location with last sold date and incoming quantity.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff9a-1dfd-7d7d-8b21-45a9066a365d',
    'Incoming Stock Report',
    'Inventory Location/Replenishment & Stock Risk/TABLE/Incoming Stock Report',
    '
    WITH level_rows AS (
        SELECT il.id AS level_id,
               COALESCE(loc.name, ''Unknown'') AS location_name,
               COALESCE(ii.sku, pv.sku, ''Unknown'') AS sku,
               COALESCE(p.title, ''Unknown'') AS product,
               COALESCE(il.incoming_quantity, 0)     AS incoming_quantity,
               COALESCE(il.available_quantity, 0)    AS available_quantity,
               COALESCE(il.safety_stock_quantity, 0) AS safety_stock_quantity
        FROM public.dim_inventory_levels il
        JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
        LEFT JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        LEFT JOIN public.dim_products p ON p.id = pv.product_id
        LEFT JOIN public.dim_inventory_locations loc ON loc.id = il.inventory_location_id
        WHERE il.seller_id = :shopId
          AND ii.seller_id = :shopId
          AND il.is_active = TRUE
          AND COALESCE(il.incoming_quantity, 0) > 0
    )
    SELECT lr.location_name AS location,
           lr.sku AS sku,
           lr.product AS product,
           lr.incoming_quantity  AS incoming_quantity,
           lr.available_quantity AS available_quantity,
           CASE
               WHEN lr.available_quantity = 0 THEN ''Out of Stock''
               WHEN lr.available_quantity <= lr.safety_stock_quantity THEN ''Low Stock''
               WHEN lr.available_quantity > lr.safety_stock_quantity * 3 THEN ''Overstock''
               ELSE ''In Stock''
           END AS stock_status,
           COUNT(*) OVER() AS total_records
    FROM level_rows lr
    ORDER BY lr.incoming_quantity DESC, lr.sku, lr.level_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Incoming stock shipment tracking report table per location listing SKU, product, incoming quantity, available quantity, and current stock status.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
);

--changeset saugat:RW-48-4
--comment seed Fulfillment & Operational Risk tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff9a-1dfd-7e79-83d1-5b9094a2b62e',
    'Fulfillment Risk KPIs',
    'Inventory Location/Fulfillment & Operational Risk/KPI/Fulfillment Risk KPIs',
    '
    SELECT COUNT(*) FILTER (WHERE loc.has_unfulfilled_orders) AS fulfillment_risk_locations
    FROM public.dim_inventory_locations loc
    WHERE loc.seller_id = :shopId
    ',
    NULL,
    'KPI',
    60,
    'Fulfillment risk KPI tracking count of locations with pending unfulfilled orders.',
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
    '019fff9a-1dfd-7a0e-baaf-247a79f97951',
    'Fulfillment Risk by Location',
    'Inventory Location/Fulfillment & Operational Risk/PLOT/Fulfillment Risk by Location',
    '
    WITH location_stock AS (
        SELECT loc.id AS location_id,
               COALESCE(loc.name, ''Unknown'') AS location_name,
               COALESCE(SUM(il.committed_quantity), 0) AS committed_quantity
        FROM public.dim_inventory_locations loc
        LEFT JOIN public.dim_inventory_levels il
               ON il.inventory_location_id = loc.id
              AND il.seller_id = :shopId
              AND il.is_active = TRUE
        WHERE loc.seller_id = :shopId
        GROUP BY loc.id, loc.name
    )
    SELECT ls.location_name AS location,
           ls.committed_quantity AS committed_quantity
    FROM location_stock ls
    ORDER BY ls.committed_quantity DESC, ls.location_name, ls.location_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Committed unfulfilled order stock quantity per location.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff9a-1dfd-79fc-a01e-4d8faeede3a4',
    'Fulfillment Risk Report',
    'Inventory Location/Fulfillment & Operational Risk/TABLE/Fulfillment Risk Report',
    '
    WITH level_rows AS (
        SELECT il.id AS level_id,
               COALESCE(loc.name, ''Unknown'') AS location_name,
               COALESCE(loc.has_unfulfilled_orders, FALSE) AS has_unfulfilled_orders,
               COALESCE(ii.sku, pv.sku, ''Unknown'') AS sku,
               COALESCE(p.title, ''Unknown'') AS product,
               COALESCE(il.committed_quantity, 0)    AS committed_quantity,
               COALESCE(il.available_quantity, 0)    AS available_quantity,
               COALESCE(il.safety_stock_quantity, 0) AS safety_stock_quantity
        FROM public.dim_inventory_levels il
        JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
        LEFT JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        LEFT JOIN public.dim_products p ON p.id = pv.product_id
        LEFT JOIN public.dim_inventory_locations loc ON loc.id = il.inventory_location_id
        WHERE il.seller_id = :shopId
          AND ii.seller_id = :shopId
          AND il.is_active = TRUE
          AND COALESCE(il.committed_quantity, 0) > 0
    )
    SELECT lr.location_name AS location,
           lr.sku AS sku,
           lr.product AS product,
           lr.committed_quantity AS committed_quantity,
           CASE WHEN lr.has_unfulfilled_orders THEN ''Yes'' ELSE ''No'' END
             AS unfulfilled_orders_flag,
           lr.available_quantity AS available_stock,
           CASE
               WHEN lr.available_quantity = 0 THEN ''Critical''
               WHEN lr.available_quantity <= lr.safety_stock_quantity THEN ''High''
               ELSE ''Medium''
           END AS risk_level,
           COUNT(*) OVER() AS total_records
    FROM level_rows lr
    ORDER BY (lr.available_quantity - lr.safety_stock_quantity) ASC,
             lr.committed_quantity DESC, lr.sku, lr.level_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Fulfillment risk report table listing location, SKU, product, committed quantity, unfulfilled orders flag, available stock, and evaluated risk level.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
);

--changeset saugat:RW-48-5
--comment seed Inventory Value & Asset Management tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff9a-1dfd-73f8-99c8-cf67c8421b51',
    'Inventory Value KPIs',
    'Inventory Location/Inventory Value & Asset Management/KPI/Inventory Value KPIs',
    '
    SELECT ROUND(COALESCE(SUM(COALESCE(il.on_hand_quantity, 0)
                              * COALESCE(ii.unit_cost, 0)), 0), 2) AS inventory_value,
           COALESCE(SUM(COALESCE(il.damaged_quantity, 0)
                        + COALESCE(il.quality_control_quantity, 0)
                        + COALESCE(il.reserved_quantity, 0)), 0) AS non_sellable_stock
    FROM public.dim_inventory_levels il
    LEFT JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
                               AND ii.seller_id = :shopId
    WHERE il.seller_id = :shopId
      AND il.is_active = TRUE
    ',
    NULL,
    'KPI',
    60,
    'Inventory value KPIs tracking total on-hand inventory valuation and non-sellable stock quantity.',
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
    '019fff9a-1dfd-76e4-99d4-5168b37fb95f',
    'Inventory Value by Location',
    'Inventory Location/Inventory Value & Asset Management/PLOT/Inventory Value by Location',
    '
    WITH location_value AS (
        SELECT loc.id AS location_id,
               COALESCE(loc.name, ''Unknown'') AS location_name,
               COALESCE(SUM(COALESCE(il.on_hand_quantity, 0)
                            * COALESCE(ii.unit_cost, 0)), 0) AS inventory_value
        FROM public.dim_inventory_locations loc
        LEFT JOIN public.dim_inventory_levels il
               ON il.inventory_location_id = loc.id
              AND il.seller_id = :shopId
              AND il.is_active = TRUE
        LEFT JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
        WHERE loc.seller_id = :shopId
        GROUP BY loc.id, loc.name
    )
    SELECT lv.location_name AS location,
           ROUND(lv.inventory_value, 2) AS inventory_value
    FROM location_value lv
    ORDER BY lv.inventory_value DESC, lv.location_name, lv.location_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Inventory dollar valuation per store/warehouse location.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff9a-1dfd-73b5-a621-555bfce3e3ec',
    'Stock by City / Region',
    'Inventory Location/Inventory Value & Asset Management/PLOT/Stock by City / Region',
    '
    WITH geo_value AS (
        SELECT loc.address #>> ''{city}''     AS city,
               loc.address #>> ''{province}'' AS province,
               loc.address #>> ''{country}''  AS country,
               COALESCE(SUM(COALESCE(il.on_hand_quantity, 0)
                            * COALESCE(ii.unit_cost, 0)), 0) AS inventory_value
        FROM public.dim_inventory_locations loc
        LEFT JOIN public.dim_inventory_levels il
               ON il.inventory_location_id = loc.id
              AND il.seller_id = :shopId
              AND il.is_active = TRUE
        LEFT JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
        WHERE loc.seller_id = :shopId
        GROUP BY loc.address #>> ''{city}'', loc.address #>> ''{province}'', loc.address #>> ''{country}''
    )
    SELECT CASE WHEN LENGTH(CONCAT_WS(CHR(44) || CHR(32), gv.city, gv.province, gv.country)) > 0
                THEN CONCAT_WS(CHR(44) || CHR(32), gv.city, gv.province, gv.country)
                ELSE ''Unknown'' END AS region,
           ROUND(gv.inventory_value, 2) AS inventory_value
    FROM geo_value gv
    ORDER BY gv.inventory_value DESC, gv.city, gv.province, gv.country
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Inventory valuation grouped by geographic region / city.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff9a-1dfd-786b-996d-22cc13375928',
    'Inventory Value by Location Report',
    'Inventory Location/Inventory Value & Asset Management/TABLE/Inventory Value by Location Report',
    '
    WITH level_rows AS (
        SELECT il.id AS level_id,
               COALESCE(loc.name, ''Unknown'') AS location_name,
               COALESCE(ii.sku, pv.sku, ''Unknown'') AS sku,
               COALESCE(p.title, ''Unknown'') AS product,
               COALESCE(p.vendor, ''Unknown'') AS vendor,
               COALESCE(il.on_hand_quantity, 0) AS on_hand_quantity,
               COALESCE(ii.unit_cost, 0) AS unit_cost
        FROM public.dim_inventory_levels il
        JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
        LEFT JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        LEFT JOIN public.dim_products p ON p.id = pv.product_id
        LEFT JOIN public.dim_inventory_locations loc ON loc.id = il.inventory_location_id
        WHERE il.seller_id = :shopId
          AND ii.seller_id = :shopId
          AND il.is_active = TRUE
    )
    SELECT lr.location_name AS location,
           lr.sku AS sku,
           lr.product AS product,
           lr.vendor AS vendor,
           lr.on_hand_quantity AS on_hand_quantity,
           ROUND(lr.unit_cost, 2) AS unit_cost,
           ROUND(lr.on_hand_quantity * lr.unit_cost, 2) AS inventory_value,
           COUNT(*) OVER() AS total_records
    FROM level_rows lr
    ORDER BY lr.on_hand_quantity * lr.unit_cost DESC, lr.sku, lr.level_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Asset valuation report table per SKU and location listing vendor, on-hand quantity, unit cost, and total inventory value.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
);

--changeset saugat:RW-48-6
--comment seed Location Governance & Special Operations tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fff9a-1dfd-7dde-b41a-49261098371d',
    'Location Governance KPIs',
    'Inventory Location/Location Governance & Special Operations/KPI/Location Governance KPIs',
    '
    WITH location_stock AS (
        SELECT loc.id AS location_id,
               COALESCE(loc.is_active, TRUE) AS is_active,
               COALESCE(loc.is_fulfillment_service, FALSE) AS is_fulfillment_service,
               COALESCE(SUM(il.on_hand_quantity), 0) AS on_hand_quantity
        FROM public.dim_inventory_locations loc
        LEFT JOIN public.dim_inventory_levels il
               ON il.inventory_location_id = loc.id
              AND il.seller_id = :shopId
        WHERE loc.seller_id = :shopId
        GROUP BY loc.id, loc.is_active, loc.is_fulfillment_service
    )
    SELECT COUNT(*) FILTER (WHERE NOT ls.is_active AND ls.on_hand_quantity > 0)
             AS inactive_locations_with_stock,
           COUNT(*) FILTER (WHERE ls.is_fulfillment_service)
             AS fulfillment_service_locations
    FROM location_stock ls
    ',
    NULL,
    'KPI',
    60,
    'Location governance KPIs tracking count of inactive locations retaining stock and fulfillment service locations count.',
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
    '019fff9a-1dfd-72e6-b151-76e45937aba1',
    'Inactive Location Stock Exposure',
    'Inventory Location/Location Governance & Special Operations/PLOT/Inactive Location Stock Exposure',
    '
    WITH inactive_stock AS (
        SELECT loc.id AS location_id,
               COALESCE(loc.name, ''Unknown'') AS location_name,
               COALESCE(SUM(COALESCE(il.on_hand_quantity, 0)
                            * COALESCE(ii.unit_cost, 0)), 0) AS inventory_value
        FROM public.dim_inventory_locations loc
        LEFT JOIN public.dim_inventory_levels il
               ON il.inventory_location_id = loc.id
              AND il.seller_id = :shopId
        LEFT JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
        WHERE loc.seller_id = :shopId
          AND NOT COALESCE(loc.is_active, TRUE)
        GROUP BY loc.id, loc.name
    )
    SELECT i.location_name AS location,
           ROUND(i.inventory_value, 2) AS inventory_value
    FROM inactive_stock i
    ORDER BY i.inventory_value DESC, i.location_name, i.location_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'PLOT',
    60,
    'Stock valuation exposure trapped at inactive locations.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff9a-1dfd-76d4-9608-da40ce2f7995',
    'Inactive Location Stock Report',
    'Inventory Location/Location Governance & Special Operations/TABLE/Inactive Location Stock Report',
    '
    WITH level_rows AS (
        SELECT il.id AS level_id,
               COALESCE(loc.name, ''Unknown'') AS location_name,
               COALESCE(loc.is_active, TRUE) AS is_active,
               loc.deactivated_at,
               COALESCE(ii.sku, pv.sku, ''Unknown'') AS sku,
               COALESCE(p.title, ''Unknown'') AS product,
               COALESCE(il.on_hand_quantity, 0) AS on_hand_quantity,
               COALESCE(ii.unit_cost, 0) AS unit_cost
        FROM public.dim_inventory_levels il
        JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
        LEFT JOIN public.dim_product_variants pv ON pv.inventory_item_id = ii.id
        LEFT JOIN public.dim_products p ON p.id = pv.product_id
        JOIN public.dim_inventory_locations loc ON loc.id = il.inventory_location_id
        WHERE il.seller_id = :shopId
          AND ii.seller_id = :shopId
          AND loc.seller_id = :shopId
          AND NOT COALESCE(loc.is_active, TRUE)
          AND COALESCE(il.on_hand_quantity, 0) > 0
    )
    SELECT lr.location_name AS location,
           CASE WHEN lr.is_active THEN ''Active'' ELSE ''Inactive'' END AS active_status,
           lr.deactivated_at::date::text AS deactivated_date,
           lr.sku AS sku,
           lr.product AS product,
           lr.on_hand_quantity AS on_hand_quantity,
           ROUND(lr.on_hand_quantity * lr.unit_cost, 2) AS inventory_value,
           COUNT(*) OVER() AS total_records
    FROM level_rows lr
    ORDER BY lr.on_hand_quantity * lr.unit_cost DESC, lr.sku, lr.level_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Audit table listing stranded inventory at inactive locations with deactivated date, SKU, quantity, and dollar value.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fff9a-1dfd-74e2-b5f8-3f1a07395cb2',
    'Fulfillment Service Location Report',
    'Inventory Location/Location Governance & Special Operations/TABLE/Fulfillment Service Location Report',
    '
    WITH location_rows AS (
        SELECT loc.id AS location_id,
               COALESCE(loc.name, ''Unknown'') AS location_name,
               COALESCE(loc.is_fulfillment_service, FALSE) AS is_fulfillment_service,
               COALESCE(loc.fulfills_online_orders, FALSE) AS fulfills_online_orders,
               COALESCE(loc.has_active_inventory, FALSE) AS has_active_inventory,
               COALESCE(SUM(COALESCE(il.on_hand_quantity, 0)
                            * COALESCE(ii.unit_cost, 0)), 0) AS stock_value
        FROM public.dim_inventory_locations loc
        LEFT JOIN public.dim_inventory_levels il
               ON il.inventory_location_id = loc.id
              AND il.seller_id = :shopId
              AND il.is_active = TRUE
        LEFT JOIN public.dim_inventory_items ii ON ii.id = il.inventory_item_id
        WHERE loc.seller_id = :shopId
        GROUP BY loc.id, loc.name, loc.is_fulfillment_service,
                 loc.fulfills_online_orders, loc.has_active_inventory
    )
    SELECT lr.location_name AS location,
           CASE WHEN lr.is_fulfillment_service THEN ''Yes'' ELSE ''No'' END
             AS fulfillment_service,
           CASE WHEN lr.fulfills_online_orders THEN ''Yes'' ELSE ''No'' END
             AS fulfills_online_orders,
           CASE WHEN lr.has_active_inventory THEN ''Yes'' ELSE ''No'' END
             AS active_inventory,
           ROUND(lr.stock_value, 2) AS stock_value,
           COUNT(*) OVER() AS total_records
    FROM location_rows lr
    ORDER BY lr.stock_value DESC, lr.location_name, lr.location_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Fulfillment service location governance report showing fulfillment service flag, online fulfillment flag, active inventory flag, and total stock value.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
);