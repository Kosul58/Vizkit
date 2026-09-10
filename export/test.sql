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
'019fff82-e31d-769a-bc42-f99a7173de6a',
    'Orders Detail Report',
    'Order Reports/Sales & Revenue/TABLE/Orders Detail Report',
    '
    WITH filtered_orders AS (
        SELECT o.id,
o.id AS order_id,
               o.created_at,
o.customer_id, o.attribution_displayname,
o.source_name,
o.financialStatus AS financial_status,
o.fulfillmentStatus AS fulfillment_status,
COALESCE(o.original_total_price, 0) AS gross_sales,
COALESCE(o.total_discounts_amount, 0) AS discounts,
COALESCE(o.current_total_price, 0) - COALESCE(o.current_total_tax, 0) - COALESCE(o.current_shipping_price, 0) AS net_sales,
COALESCE(o.current_total_tax, 0) AS tax,
COALESCE(o.current_shipping_price, 0) AS shipping,
COALESCE(o.total_outstanding_amount, 0) AS outstanding_amount
FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
AND o.test = FALSE
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
/*financial_status_filter*/
/*fulfillment_status_filter*/
)
    SELECT f.order_id,
           f.created_at::date::text AS order_date,
           CASE
               WHEN LENGTH(CONCAT_WS(CHR(32), c.first_name, c.last_name)) > 0
               THEN CONCAT_WS(CHR(32), c.first_name, c.last_name)
               ELSE COALESCE(c.email, ''Guest'')
           END AS customer,
           COALESCE(f.attribution_displayname, f.source_name, ''unknown'') AS channel,
           f.source_name AS source,
           f.financial_status,
           f.fulfillment_status,
ROUND(f.gross_sales, 2) AS gross_sales,
ROUND(f.discounts, 2) AS discounts,
ROUND(f.net_sales, 2) AS net_sales,
ROUND(f.tax, 2) AS tax,
ROUND(f.shipping, 2) AS shipping,
ROUND(f.outstanding_amount, 2) AS outstanding_amount,
           COUNT(*) OVER() AS total_records
FROM filtered_orders f
    LEFT JOIN public.dim_customers c ON c.id = f.customer_id
ORDER BY f.created_at DESC
    LIMIT COALESCE(:limit, 10)
OFFSET COALESCE( : offset , 0 )
    ',
NULL, 'TABLE', 60,
'Comprehensive tabular report of all order transactions including financial status, sales totals, taxes, and shipping.',
    '{
      "filterMappings": {
"shopId":            { "source": "AUTH_CONTEXT",   "contextKey": "shopGid" },
        "userId":            { "source": "AUTH_CONTEXT",   "contextKey": "user_id" },
        "limit":             { "source": "REQUEST_FILTER", "filterKey": "limit" },
        "offset":            { "source": "REQUEST_FILTER", "filterKey": "offset" },
        "currentStartDate":  { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":    { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "financialStatus":   { "source": "REQUEST_FILTER", "filterKey": "financialStatus", "type": "ARRAY" },
        "fulfillmentStatus": { "source": "REQUEST_FILTER", "filterKey": "fulfillmentStatus", "type": "ARRAY" }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        {
          "provider": "ORDER_STATUS_FILTER",
          "condition": "hasFilter:financialStatus",
          "placeholder": "/*financial_status_filter*/",
          "args": {
            "statusColumn": "o.financialStatus",
            "statusParam": "financialStatus"
          }
        },
{
          "provider": "ORDER_STATUS_FILTER",
          "condition": "hasFilter:fulfillmentStatus",
          "placeholder": "/*fulfillment_status_filter*/",
          "args": {
            "statusColumn": "o.fulfillmentStatus",
            "statusParam": "fulfillmentStatus"
          }
        }
      ]
    }'
);

INSERT INTO
    query_segment (id, name, query)
VALUES (
        'c6b65345-4a56-42b7-8495-2c8e2279b003',
        'ORDER_STATUS_FILTER',
        'AND (''ALL'' = ANY (:<statusParam>) OR <statusColumn> = ANY (:<statusParam>))'
    );