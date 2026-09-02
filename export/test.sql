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
        '019fffa2-0f80-7abe-96ab-bc331790de2d',
        'Channel Fulfillment Report',
        'Sales Channel Attribution/Operations & Fulfillment/TABLE/Channel Fulfillment Report',
        '
    WITH filtered_orders AS (
        SELECT o.id,
               o.created_at,
o.fulfillmentStatus as fulfillment_status,
COALESCE(
    o.attribution_displayname,
    o.order_app_name,
    o.source_name,
    '' Unattributed ''
) AS channel
FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
AND o.test = FALSE
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    order_unfulfilled AS (
        SELECT li.order_id,
               SUM(COALESCE(li.unfulfilled_discounted_total_amount, 0)) AS unfulfilled_value
FROM public.fact_order_line_items li
        JOIN filtered_orders f ON f.id = li.order_id
        GROUP BY li.order_id
    ),
    backlog AS (
        SELECT f.channel,
               f.fulfillment_status,
               (CURRENT_DATE - f.created_at::date) AS aging_days,
               ou.unfulfilled_value
        FROM filtered_orders f
        JOIN order_unfulfilled ou ON ou.order_id = f.id
        WHERE ou.unfulfilled_value > 0
    )
    SELECT b.channel AS channel,
           COUNT(*) AS unfulfilled_orders,
           ROUND(SUM(b.unfulfilled_value), 2) AS unfulfilled_value,
           COUNT(*) FILTER (
               WHERE UPPER(b.fulfillment_status) = ''UNFULFILLED'') AS fully_unfulfilled,
           COUNT(*) FILTER (
               WHERE UPPER(b.fulfillment_status) = ''PARTIALLY_FULFILLED'') AS partially_fulfilled,
           ROUND(AVG(b.aging_days), 1) AS avg_aging_days,
           MAX(b.aging_days) AS max_aging_days,
           COUNT(*) OVER() AS total_records
    FROM backlog b
    GROUP BY b.channel
    ORDER BY SUM(b.unfulfilled_value) DESC, b.channel ASC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE(:offset, 0)
    ',
        NULL,
        'TABLE',
        60,
        'Fulfillment backlog report table per channel showing unfulfilled orders count, unfulfilled value, fully/partially unfulfilled breakdown, and average/max aging days.',
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