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
    '019fff82-e31b-786f-9d94-810596bff3e8',
    'Unfulfilled Line Items Report',
    'Order Line Item Analytics/Fulfillment & Backlog/TABLE/Unfulfilled Line Items Report',
    '
    WITH filtered_lines AS (
        SELECT li.id AS line_id,
               li.product_variant_id,
               o.id AS order_id,
               o.fulfillmentstatus AS fulfillment_status,
               li.quantity AS units,
               COALESCE(li.unfulfilled_quantity, 0) AS unfulfilled_units,
               COALESCE(li.unfulfilled_discounted_total_amount, 0) AS unfulfilled_value
        FROM public.fact_order_line_items li
        JOIN public.fact_order_headers o ON o.id = li.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND COALESCE(li.unfulfilled_quantity, 0) > 0
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    )
    SELECT f.order_id,
           p.id AS product_id,
           pv.sku AS sku,
           p.title AS product,
           f.units AS quantity,
           f.unfulfilled_units AS unfulfilled_quantity,
           ROUND(f.unfulfilled_value, 2) AS unfulfilled_value,
           f.fulfillment_status AS fulfillment_status,
           COUNT(*) OVER() AS total_records
    FROM filtered_lines f
    JOIN public.dim_product_variants pv ON pv.id = f.product_variant_id
    LEFT JOIN public.dim_products p ON p.id = pv.product_id
    ORDER BY f.unfulfilled_value DESC, f.line_id
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
    NULL,
    'TABLE',
    60,
    'Granular tabular audit of individual unfulfilled line items per order.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "limit": { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset": { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" }
      },
      "excludeExtraParams": true
    }'
);

INSERT INTO
    query_segment (id, name, query)
VALUES (
        'c6b65345-4a56-42b7-8495-2c8e2279b003',
        'ORDER_STATUS_FILTER',
        'AND (''ALL'' = ANY (:<statusParam>) OR <statusColumn> = ANY (:<statusParam>))'
    );