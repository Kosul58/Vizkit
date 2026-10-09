INSERT INTO vizkit.report (id, name, description, supported_formats, filters, projection, configuration, metadata, query, created_at, updated_at)
VALUES
(
    '019f45c3-a5aa-7b77-9753-913fe85d8fd4',
    'Products & Inventory Health',
    'Provides information about Products it''s variant and inventory information associated to it.',
    '["CSV", "XLSX"]',
    '[
      {"type": "DATE_RANGE", "label": "Date Range", "column": "createdAt", "options": [{"key": "-1", "label": "Last 1 Days"}, {"key": "-7", "label": "Last 7 Days"}, {"key": "-14", "label": "Last 14 Days"}, {"key": "-30", "label": "Last 1 Month"}, {"key": "-90", "label": "Last 3 Months"}, {"key": "-180", "label": "Last 6 Months"}, {"key": "-365", "label": "Last 12 Months"}, {"key": "MTD", "label": "This Month"}, {"key": "PREVIOUS-MONTH", "label": "Previous Month"}, {"key": "QTD", "label": "This Quarter"}, {"key": "PREVIOUS-QUARTER", "label": "Previous Quarter"}, {"key": "YTD", "label": "This Year"}, {"key": "PREVIOUS-YEAR", "label": "Previous Year"}, {"key": "CUSTOM", "label": "Choose Date Range"}], "defaultValue": "-30"}
    ]',
    '[
      {"type": "TEXT", "state": "REQUIRED", "title": "Product Name", "column": "product_name"},
      {"type": "TEXT", "state": "REQUIRED", "title": "Vendor", "column": "vendor"},
      {"type": "TEXT", "state": "CHECKED", "title": "SKU", "column": "sku"},
      {"type": "TEXT", "state": "CHECKED", "title": "Product Type", "column": "product_type"},
      {"type": "TEXT", "state": "CHECKED", "title": "Product Status", "column": "product_status"},
      {"type": "TEXT", "state": "CHECKED", "title": "Variant Name", "column": "variant"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Price", "column": "price"},
      {"type": "DATE", "state": "CHECKED", "title": "Variant Created At", "column": "variant_created_at"},
      {"type": "TEXT", "state": "CHECKED", "title": "Inventory Location", "column": "inventory_location"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Available Quantity", "column": "available_quantity"},
      {"type": "NUMBER", "state": "CHECKED", "title": "On Hand Quantity", "column": "on_hand_quantity"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Committed Quantity", "column": "committed_quantity"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Incoming Quantity", "column": "incoming_quantity"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Reserved Quantity", "column": "reserved_quantity"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Damaged Quantity", "column": "damaged_quantity"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Safety Stock Quantity", "column": "safety_stock_quantity"},
      {"type": "TEXT", "state": "CHECKED", "title": "Inventory Status", "column": "inventory_status"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Unit Cost", "column": "unit_cost"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Inventory Value", "column": "inventory_value"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Potential Sales Value", "column": "potential_sales_value"}
    ]',
    '{
      "filterMappings": {
        "shopId": {"source": "AUTH_CONTEXT", "contextKey": "shopGid"},
        "createdAtEnd": {"index": 1, "source": "REQUEST_FILTER", "filterKey": "createdAt"},
        "createdAtStart": {"index": 0, "source": "REQUEST_FILTER", "filterKey": "createdAt"}
      },
      "excludeExtraParams": true
    }',
    NULL,
    $$
        with base as (

SELECT
    -- Product
    dp.id AS product_id,
    dp.title AS product_name,
    dp.product_type,
    dp.vendor,
    dpv.sku,
    dp.status AS product_status,

    -- Variant
    dpv.id AS variant_id,
    dpv.variant_title AS variant,
    dpv.price,
    dpv.created_at AS variant_created_at,

    -- Inventory Location
    dil.name AS inventory_location,

    -- Inventory
    dilv.available_quantity,
    dilv.on_hand_quantity,
    dilv.committed_quantity,
    dilv.incoming_quantity,
    dilv.reserved_quantity,
    dilv.damaged_quantity,
    dilv.safety_stock_quantity,

    -- Inventory Health
    CASE
        WHEN COALESCE(dilv.available_quantity, 0) <= 0
            THEN 'OUT OF STOCK'

        WHEN dilv.available_quantity <= COALESCE(dilv.safety_stock_quantity, 0)
            THEN 'LOW STOCK'

        ELSE 'IN STOCK'
    END AS inventory_status,

    -- Cost
    dii.unit_cost,

    CASE
        WHEN dii.unit_cost IS NOT NULL
        THEN dilv.on_hand_quantity * dii.unit_cost
    END AS inventory_value,

    CASE
        WHEN dpv.price IS NOT NULL
        THEN dilv.available_quantity * dpv.price
    END AS potential_sales_value

FROM public.dim_products dp

INNER JOIN public.dim_product_variants dpv
    ON dpv.product_id = dp.id
    AND dpv.seller_id = dp.seller_id
    AND dpv.record_status = 'ACTIVE'

inner JOIN public.dim_inventory_items dii
    ON dii.id = dpv.inventory_item_id
    AND dii.seller_id = dpv.seller_id
    AND dii.record_status = 'ACTIVE'

LEFT JOIN public.dim_inventory_levels dilv
    ON dilv.inventory_item_id = dii.id
    AND dilv.seller_id = dii.seller_id
    AND dilv.record_status = 'ACTIVE'

LEFT JOIN public.dim_inventory_locations dil
    ON dil.id = dilv.inventory_location_id
    AND dil.seller_id = dilv.seller_id
    AND dil.record_status = 'ACTIVE'

WHERE
    dpv.seller_id = :shopId
    AND (dpv.created_at::date between :createdAtStart::date AND :createdAtEnd::date)
    AND dp.record_status = 'ACTIVE'
)
SELECT
    /*projection_fields*/
from base
where true
/*additional_filters*/
    $$,
    '2026-09-01 07:28:00.925871',
    '2026-09-01 07:28:00.925871'
),
(
    '019f45c3-a5aa-7b94-9f96-62fdc5cafec3',
    'Payments & Transactions',
    'Provides information about order payment transaction and tender transaction for an order.',
    '["CSV", "XLSX"]',
    '[
      {"type": "DATE_RANGE", "label": "Date Range", "column": "createdAt", "options": [{"key": "-1", "label": "Last 1 Days"}, {"key": "-7", "label": "Last 7 Days"}, {"key": "-14", "label": "Last 14 Days"}, {"key": "-30", "label": "Last 1 Month"}, {"key": "-90", "label": "Last 3 Months"}, {"key": "-180", "label": "Last 6 Months"}, {"key": "-365", "label": "Last 12 Months"}, {"key": "MTD", "label": "This Month"}, {"key": "PREVIOUS-MONTH", "label": "Previous Month"}, {"key": "QTD", "label": "This Quarter"}, {"key": "PREVIOUS-QUARTER", "label": "Previous Quarter"}, {"key": "YTD", "label": "This Year"}, {"key": "PREVIOUS-YEAR", "label": "Previous Year"}, {"key": "CUSTOM", "label": "Choose Date Range"}], "defaultValue": "-30"}
    ]',
    '[
      {"type": "TEXT", "state": "REQUIRED", "title": "Customer Name", "column": "customer_name"},
      {"type": "TEXT", "state": "REQUIRED", "title": "Customer Email", "column": "customer_email"},
      {"type": "TEXT", "state": "REQUIRED", "title": "Order ID", "column": "order_id"},
      {"type": "DATE", "state": "REQUIRED", "title": "Order Date", "column": "order_date"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Order Total", "column": "order_total"},
      {"type": "TEXT", "state": "CHECKED", "title": "Currency", "column": "currency"},
      {"type": "TEXT", "state": "CHECKED", "title": "Order Payment Status", "column": "order_payment_status"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Net Amount Received", "column": "net_amount_received"},
      {"type": "TEXT", "state": "CHECKED", "title": "Payment Action", "column": "payment_action"},
      {"type": "TEXT", "state": "CHECKED", "title": "Payment Result", "column": "payment_result"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Payment Amount", "column": "payment_amount"},
      {"type": "TEXT", "state": "CHECKED", "title": "Payment Processor", "column": "payment_processor"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Processing Fee", "column": "processing_fee"},
      {"type": "DATE", "state": "CHECKED", "title": "Payment Processed On", "column": "payment_processed_on"},
      {"type": "TEXT", "state": "CHECKED", "title": "Tender Type", "column": "tender_type"},
      {"type": "TEXT", "state": "CHECKED", "title": "Card Brand", "column": "card_brand"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Amount Settled", "column": "amount_settled"},
      {"type": "TEXT", "state": "CHECKED", "title": "Payment Reference #", "column": "remote_reference"},
      {"type": "DATE", "state": "CHECKED", "title": "Settled On", "column": "settled_on"}
    ]',
    '{
      "filterMappings": {
        "shopId": {"source": "AUTH_CONTEXT", "contextKey": "shopGid"},
        "createdAtEnd": {"index": 1, "source": "REQUEST_FILTER", "filterKey": "createdAt"},
        "createdAtStart": {"index": 0, "source": "REQUEST_FILTER", "filterKey": "createdAt"}
      },
      "excludeExtraParams": true
    }',
    NULL,
    $$
WITH base AS (
    SELECT
        NULLIF(
            CONCAT_WS(' ', dc.first_name, dc.last_name),
            ''
        ) AS customer_name,

        dc.email AS customer_email,

        foh.id AS order_id,
        foh.created_at AS order_date,
        foh.total_price AS order_total,
        foh.currency_code AS currency,
        foh.financialstatus AS order_payment_status,
        foh.net_payment AS net_amount_received,

        fot.kind AS payment_action,
        fot.status AS payment_result,
        fot.amount AS payment_amount,
        fot.gateway AS payment_processor,
        fot.transaction_fee AS processing_fee,
        fot.processed_at AS payment_processed_on,

        dtt.payment_method AS tender_type,
        dtt.transaction_credit_card_company AS card_brand,
        dtt.amount AS amount_settled,
        dtt.remote_reference AS remote_reference,
        dtt.processed_at AS settled_on

    FROM public.fact_order_headers foh

    INNER JOIN public.dim_customers dc
        ON dc.id = foh.customer_id AND dc.record_status = 'ACTIVE'

    LEFT JOIN public.fact_order_transactions fot
        ON fot.order_id = foh.id
        AND fot.seller_id = foh.seller_id
        AND fot.record_status = 'ACTIVE'

    LEFT JOIN public.fact_tender_transactions dtt
        ON dtt.order_id = foh.id
        AND dtt.seller_id = foh.seller_id
        AND dtt.record_status = 'ACTIVE'

    WHERE foh.seller_id = :shopId
      AND foh.created_at::date BETWEEN :createdAtStart::date
                                   AND :createdAtEnd::date
      AND (foh.test = FALSE OR EXISTS (SELECT 1 FROM public.seller sl WHERE sl.shop_id = :shopId AND sl.store_type <> 'MERCHANT'))
      AND foh.record_status = 'ACTIVE'
)
SELECT
    /*projection_fields*/
FROM base
WHERE TRUE
/*additional_filters*/
    $$,
    '2026-09-02 07:52:47.367000',
    '2026-09-02 07:52:47.367000'
),
(
    '019f45c3-a5aa-7b5c-aba3-77d754a33030',
    'Order Line Item Report',
    'Provides information about order details which mainly contains line-item information',
    '["CSV", "XLSX"]',
    '[
      {"type": "DATE_RANGE", "label": "Date Range", "column": "createdAt", "options": [{"key": "-1", "label": "Last 1 Days"}, {"key": "-7", "label": "Last 7 Days"}, {"key": "-14", "label": "Last 14 Days"}, {"key": "-30", "label": "Last 1 Month"}, {"key": "-90", "label": "Last 3 Months"}, {"key": "-180", "label": "Last 6 Months"}, {"key": "-365", "label": "Last 12 Months"}, {"key": "MTD", "label": "This Month"}, {"key": "PREVIOUS-MONTH", "label": "Previous Month"}, {"key": "QTD", "label": "This Quarter"}, {"key": "PREVIOUS-QUARTER", "label": "Previous Quarter"}, {"key": "YTD", "label": "This Year"}, {"key": "PREVIOUS-YEAR", "label": "Previous Year"}, {"key": "CUSTOM", "label": "Choose Date Range"}], "defaultValue": "-30"}
    ]',
    '[
      {"type": "TEXT", "state": "REQUIRED", "title": "Order ID", "column": "order_id"},
      {"type": "TEXT", "state": "CHECKED", "title": "Product Name", "column": "product_name"},
      {"type": "TEXT", "state": "CHECKED", "title": "Variant Name", "column": "variant_name"},
      {"type": "TEXT", "state": "CHECKED", "title": "Vendor", "column": "vendor"},
      {"type": "TEXT", "state": "CHECKED", "title": "SKU", "column": "sku"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Quantity Ordered", "column": "quantity_ordered"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Current Quantity", "column": "current_quantity"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Unfulfilled Quantity", "column": "unfulfilled_quantity"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Refundable Quantity", "column": "refundable_quantity"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Original Unit Price", "column": "original_unit_price"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Unit Price", "column": "unit_price"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Line Item Total", "column": "line_item_total"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Discount Amount", "column": "discount_amount"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Unfulfilled Amount", "column": "unfulfilled_amount"},
      {"type": "TEXT", "state": "CHECKED", "title": "Shipping Requirement", "column": "shipping_requirement"},
      {"type": "TEXT", "state": "CHECKED", "title": "Item Type", "column": "item_type"},
      {"type": "TEXT", "state": "CHECKED", "title": "Tax Status", "column": "tax_status"}
    ]',
    '{
      "filterMappings": {
        "shopId": {"source": "AUTH_CONTEXT", "contextKey": "shopGid"},
        "createdAtEnd": {"index": 1, "source": "REQUEST_FILTER", "filterKey": "createdAt"},
        "createdAtStart": {"index": 0, "source": "REQUEST_FILTER", "filterKey": "createdAt"}
      },
      "excludeExtraParams": true
    }',
    NULL,
    $$
        with base as (

SELECT
    foli.order_id AS order_id,


    foli.product_name AS product_name,
    foli.variant_name AS variant_name,
    foli.sku AS sku,
    foli.vendor AS vendor,


    foli.quantity AS quantity_ordered,
    foli.current_quantity AS current_quantity,
    foli.unfulfilled_quantity AS unfulfilled_quantity,
    foli.refundable_quantity AS refundable_quantity,


    foli.original_unit_price AS original_unit_price,
    foli.discounted_unit_price_after_all_discounts AS unit_price,
    foli.discounted_total_amount AS line_item_total,
    foli.total_discount_amount AS discount_amount,
    foli.unfulfilled_discounted_total_amount AS unfulfilled_amount,


    CASE
        WHEN foli.requires_shipping THEN 'REQUIRES SHIPPING'
        ELSE 'NO SHIPPING REQUIRED'
    END AS shipping_requirement,

    CASE
        WHEN foli.is_giftcard THEN 'GIFT CARD'
        ELSE 'REGULAR PRODUCT'
    END AS item_type,

    CASE
        WHEN foli.taxable THEN 'TAXABLE'
        ELSE 'NON-TAXABLE'
    END AS tax_status

FROM public.fact_order_headers foh
inner join  public.fact_order_line_items foli on foh.id = foli.order_id and foli.seller_id = foh.seller_id AND foli.record_status = 'ACTIVE'
WHERE
    foh.seller_id = :shopId
    AND (foh.test = FALSE OR EXISTS (SELECT 1 FROM public.seller sl WHERE sl.shop_id = :shopId AND sl.store_type <> 'MERCHANT'))
    and (foh.created_at::date between :createdAtStart::date and :createdAtEnd::date)
    AND foh.record_status = 'ACTIVE'
)
SELECT
    /*projection_fields*/
from base
where true
/*additional_filters*/
    $$,
    '2026-09-01 07:28:00.925871',
    '2026-09-01 07:28:00.925871'
),
(
    '019f45c3-a5aa-7b80-9361-07219d3b3218',
    'Customers & Retention',
    'Provides Information about Customers and their last activity.',
    '["CSV", "XLSX"]',
    '[
      {"type": "DATE_RANGE", "label": "Date Range", "column": "createdAt", "options": [{"key": "-1", "label": "Last 1 Days"}, {"key": "-7", "label": "Last 7 Days"}, {"key": "-14", "label": "Last 14 Days"}, {"key": "-30", "label": "Last 1 Month"}, {"key": "-90", "label": "Last 3 Months"}, {"key": "-180", "label": "Last 6 Months"}, {"key": "-365", "label": "Last 12 Months"}, {"key": "MTD", "label": "This Month"}, {"key": "PREVIOUS-MONTH", "label": "Previous Month"}, {"key": "QTD", "label": "This Quarter"}, {"key": "PREVIOUS-QUARTER", "label": "Previous Quarter"}, {"key": "YTD", "label": "This Year"}, {"key": "PREVIOUS-YEAR", "label": "Previous Year"}, {"key": "CUSTOM", "label": "Choose Date Range"}], "defaultValue": "-30"}
    ]',
    '[
      {"type": "TEXT", "state": "REQUIRED", "title": "Customer Name", "column": "customer_name"},
      {"type": "TEXT", "state": "REQUIRED", "title": "Customer Email", "column": "email"},
      {"type": "TEXT", "state": "CHECKED", "title": "Customer Address", "column": "customer_address"},
      {"type": "DATE", "state": "CHECKED", "title": "Created Date", "column": "created_at"},
      {"type": "TEXT", "state": "CHECKED", "title": "Account Status", "column": "state"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Total Spent", "column": "amount_spent"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Number of Orders", "column": "number_of_orders"},
      {"type": "DATE", "state": "CHECKED", "title": "Last Order Date", "column": "last_ordered_date"},
      {"type": "TEXT", "state": "CHECKED", "title": "Last Order Payment Status", "column": "last_order_financial_status"}
    ]',
    '{
      "filterMappings": {
        "shopId": {"source": "AUTH_CONTEXT", "contextKey": "shopGid"},
        "createdAtEnd": {"index": 1, "source": "REQUEST_FILTER", "filterKey": "createdAt"},
        "createdAtStart": {"index": 0, "source": "REQUEST_FILTER", "filterKey": "createdAt"}
      },
      "excludeExtraParams": true
    }',
    NULL,
    $$
with base as (

Select
    Nullif(CONCAT_WS(' ', dc.first_name, dc.last_name),'') AS customer_name,
    dc.email as email,
     nullif(
        concat_ws(', ',
            nullif(concat_ws(' ',
                 address1,address2
            ), ''),
            city,
            nullif(concat_ws(' ',
                province,
                zip
            ), ''),
            country
        ),
    '') as customer_address,
    dc.created_at,
    dc.state,
    dc.amount_spent,
    dc.number_of_orders,
    dc.last_ordered_date,
    dc.last_order_financial_status
from public.dim_customers dc
inner join public.dim_customer_addresses dca on dca.customer_id = dc.id and dc.seller_id = dca.seller_id  and dc.default_address_id = dca.id AND dca.record_status = 'ACTIVE'
where dc.seller_id = :shopId
and (dc.created_at::date between :createdAtStart::date and :createdAtEnd::date)
AND dc.record_status = 'ACTIVE'
)
SELECT
    /*projection_fields*/
from base
where true
/*additional_filters*/
    $$,
    '2026-09-02 07:26:57.942901',
    '2026-09-02 07:26:57.942901'
),
(
    '019f45c3-a5aa-7b10-87c0-96f899a0fc8b',
    'Orders Report',
    'Provides information about order from top level',
    '["CSV", "XLSX"]',
    '[
      {"type": "DATE_RANGE", "label": "Date Range", "column": "createdAt", "options": [{"key": "-1", "label": "Last 1 Days"}, {"key": "-7", "label": "Last 7 Days"}, {"key": "-14", "label": "Last 14 Days"}, {"key": "-30", "label": "Last 1 Month"}, {"key": "-90", "label": "Last 3 Months"}, {"key": "-180", "label": "Last 6 Months"}, {"key": "-365", "label": "Last 12 Months"}, {"key": "MTD", "label": "This Month"}, {"key": "PREVIOUS-MONTH", "label": "Previous Month"}, {"key": "QTD", "label": "This Quarter"}, {"key": "PREVIOUS-QUARTER", "label": "Previous Quarter"}, {"key": "YTD", "label": "This Year"}, {"key": "PREVIOUS-YEAR", "label": "Previous Year"}, {"key": "CUSTOM", "label": "Choose Date Range"}], "defaultValue": "-30"}
    ]',
    '[
      {"type": "TEXT", "state": "REQUIRED", "title": "Order ID", "column": "order_id"},
      {"type": "DATE", "state": "REQUIRED", "title": "Order Date", "column": "order_date"},
      {"type": "TEXT", "state": "REQUIRED", "title": "Customer Name", "column": "customer_name"},
      {"type": "TEXT", "state": "CHECKED", "title": "Sales Channel", "column": "sales_channel"},
      {"type": "TEXT", "state": "CHECKED", "title": "Order Source", "column": "order_source"},
      {"type": "TEXT", "state": "CHECKED", "title": "Financial Status", "column": "financial_status"},
      {"type": "TEXT", "state": "CHECKED", "title": "Fulfillment Status", "column": "fulfillment_status"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Subtotal", "column": "subtotal"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Discounts", "column": "discounts"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Order Total", "column": "order_total"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Tax", "column": "tax"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Shipping", "column": "shipping"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Amount Outstanding", "column": "amount_outstanding"},
      {"type": "TEXT", "state": "UNCHECKED", "title": "Customer Email", "column": "customer_email"},
      {"type": "DATE", "state": "UNCHECKED", "title": "Processed Date", "column": "processed_date"},
      {"type": "DATE", "state": "UNCHECKED", "title": "Cancelled Date", "column": "cancelled_date"},
      {"type": "DATE", "state": "UNCHECKED", "title": "Closed Date", "column": "closed_date"},
      {"type": "TEXT", "state": "UNCHECKED", "title": "Currency", "column": "currency"},
      {"type": "NUMBER", "state": "UNCHECKED", "title": "Duties", "column": "duties"},
      {"type": "NUMBER", "state": "UNCHECKED", "title": "Additional Fees", "column": "additional_fees"},
      {"type": "NUMBER", "state": "UNCHECKED", "title": "Original Order Total", "column": "original_order_total"},
      {"type": "NUMBER", "state": "UNCHECKED", "title": "Item Quantity", "column": "item_quantity"},
      {"type": "TEXT", "state": "UNCHECKED", "title": "Payment Method", "column": "payment_method"},
      {"type": "NUMBER", "state": "UNCHECKED", "title": "Amount Paid", "column": "amount_paid"},
      {"type": "NUMBER", "state": "UNCHECKED", "title": "Refunded Amount", "column": "refunded_amount"},
      {"type": "NUMBER", "state": "UNCHECKED", "title": "Refunded Shipping Amount", "column": "refunded_shipping_amount"},
      {"type": "TEXT", "state": "UNCHECKED", "title": "Payment Status", "column": "payment_status"},
      {"type": "TEXT", "state": "UNCHECKED", "title": "Order Status", "column": "order_status"},
      {"type": "TEXT", "state": "UNCHECKED", "title": "Billing Address", "column": "billing_address"},
      {"type": "TEXT", "state": "UNCHECKED", "title": "Shipping Address", "column": "shipping_address"}
    ]',
    '{
      "filterMappings": {
        "shopId": {"source": "AUTH_CONTEXT", "contextKey": "shopGid"},
        "createdAtEnd": {"index": 1, "source": "REQUEST_FILTER", "filterKey": "createdAt"},
        "createdAtStart": {"index": 0, "source": "REQUEST_FILTER", "filterKey": "createdAt"}
      },
      "excludeExtraParams": true
    }',
    NULL,
    $$
with base as (

SELECT
    foh.id                                      AS order_id,
    NULLIF(CONCAT_WS(' ', dc.first_name, dc.last_name),'') AS customer_name,
    dc.email                                    AS customer_email,

    foh.created_at                              AS order_date,
    foh.processed_at                            AS processed_date,
    foh.cancelled_at                            AS cancelled_date,
    foh.closed_at                               AS closed_date,

    foh.currency_code                           AS currency,

    foh.attribution_displayname                 AS sales_channel,
    foh.source_name                             AS order_source,
    foh.payment_gateway_names ->> 0                AS payment_method,
    CASE
        WHEN foh.fullypaid THEN 'FULLY PAID'
        WHEN foh.total_received_amount > 0 THEN 'PARTIALLY PAID'
        ELSE 'UNPAID'
        END                                     AS payment_status,

    foh.financialstatus                         AS financial_status,

    foh.fulfillmentstatus                       AS fulfillment_status,

    CASE
        WHEN foh.cancelled_at IS NOT NULL THEN 'CANCELLED'
        WHEN foh.closed THEN 'CLOSED'
        ELSE 'OPEN'
        END                                     AS order_status,

    NULLIF(CONCAT_WS(
            ', ',
            NULLIF(foh.billing_address #>> '{address1}', ''),
            NULLIF(foh.billing_address #>> '{address2}', ''),
            NULLIF(foh.billing_address #>> '{city}', ''),
            NULLIF(foh.billing_address #>> '{provinceCode}', ''),
            NULLIF(foh.billing_address #>> '{country}', '')
    ),'')                                           AS billing_address,

    NULLIF(CONCAT_WS(
            ', ',
            NULLIF(foh.shipping_address #>> '{address1}', ''),
            NULLIF(foh.shipping_address #>> '{address2}', ''),
            NULLIF(foh.shipping_address #>> '{city}', ''),
            NULLIF(foh.shipping_address #>> '{provinceCode}', ''),
            NULLIF(foh.shipping_address #>> '{country}', '')
    ),'')                                           AS shipping_address,

    foh.current_subtotal_lineitems_quantity     AS item_quantity,
    foh.current_subtotal_price                  AS subtotal,
    foh.current_total_discounts                 AS discounts,
    foh.current_shipping_price                  AS shipping,
    foh.current_total_tax                       AS tax,
    foh.current_total_duties                    AS duties,
    foh.current_total_additional_fees           AS additional_fees,
    foh.current_total_price                     AS order_total,

    foh.original_total_price                    AS original_order_total,



    foh.total_received_amount                   AS amount_paid,
    foh.total_outstanding_amount                AS amount_outstanding,

    foh.total_refunded_amount                   AS refunded_amount,
    foh.total_refunded_shipping_amount          AS refunded_shipping_amount


FROM public.fact_order_headers foh
LEFT JOIN public.dim_customers dc
ON dc.id = foh.customer_id AND dc.record_status = 'ACTIVE'
WHERE (foh.created_at::date between :createdAtStart::date and :createdAtEnd::date)
  AND foh.seller_id = :shopId
  AND (foh.test = FALSE OR EXISTS (SELECT 1 FROM public.seller sl WHERE sl.shop_id = :shopId AND sl.store_type <> 'MERCHANT'))
  AND foh.record_status = 'ACTIVE'
)
SELECT
    /*projection_fields*/
from base
where true
/*additional_filters*/
    $$,
    '2026-09-01 07:28:00.925871',
    '2026-09-01 07:28:00.925871'
),
(
    '019f45c3-a5aa-7b8c-ba97-df3026cbc529',
    'Sales Channels & Attribution',
    'Provides Information about where quality sales come from.',
    '["CSV", "XLSX"]',
    '[
      {"type": "DATE_RANGE", "label": "Date Range", "column": "createdAt", "options": [{"key": "-1", "label": "Last 1 Days"}, {"key": "-7", "label": "Last 7 Days"}, {"key": "-14", "label": "Last 14 Days"}, {"key": "-30", "label": "Last 1 Month"}, {"key": "-90", "label": "Last 3 Months"}, {"key": "-180", "label": "Last 6 Months"}, {"key": "-365", "label": "Last 12 Months"}, {"key": "MTD", "label": "This Month"}, {"key": "PREVIOUS-MONTH", "label": "Previous Month"}, {"key": "QTD", "label": "This Quarter"}, {"key": "PREVIOUS-QUARTER", "label": "Previous Quarter"}, {"key": "YTD", "label": "This Year"}, {"key": "PREVIOUS-YEAR", "label": "Previous Year"}, {"key": "CUSTOM", "label": "Choose Date Range"}], "defaultValue": "-30"}
    ]',
    '[
      {"type": "TEXT", "state": "REQUIRED", "title": "Order ID", "column": "order_id"},
      {"type": "DATE", "state": "REQUIRED", "title": "Order Date", "column": "order_date"},
      {"type": "NUMBER", "state": "REQUIRED", "title": "Order Value ($)", "column": "order_total"},
      {"type": "TEXT", "state": "CHECKED", "title": "Sales Channel (App Used)", "column": "order_app_name"},
      {"type": "TEXT", "state": "CHECKED", "title": "Order Placed Via", "column": "source_name"},
      {"type": "TEXT", "state": "CHECKED", "title": "Marketing Credit Given To", "column": "attribution_displayname"},
      {"type": "TEXT", "state": "CHECKED", "title": "First Discovered Through", "column": "first_visit_source"},
      {"type": "TEXT", "state": "CHECKED", "title": "First Touch Marketing Type", "column": "first_visit_source_type"},
      {"type": "TEXT", "state": "CHECKED", "title": "Marketing Campaign (First Visit)", "column": "first_visit_utm_campaign"},
      {"type": "TEXT", "state": "CHECKED", "title": "Returned to Buy Via", "column": "last_visit_source"},
      {"type": "TEXT", "state": "CHECKED", "title": "Final Touch Marketing Type", "column": "last_visit_source_type"}
    ]',
    '{
      "filterMappings": {
        "shopId": {"source": "AUTH_CONTEXT", "contextKey": "shopGid"},
        "createdAtEnd": {"index": 1, "source": "REQUEST_FILTER", "filterKey": "createdAt"},
        "createdAtStart": {"index": 0, "source": "REQUEST_FILTER", "filterKey": "createdAt"}
      },
      "excludeExtraParams": true
    }',
    NULL,
    $$
with base as (

Select
    foh.id  as order_id,
    foh.created_at as order_date,
    foh.current_total_price as order_total,
    foh.order_app_name,
    foh.source_name,
    foh.attribution_displayname,
    public.clean_string(foh.customer_journey_summary #>> '{firstVisit, source}') as first_visit_source,
    public.clean_string(foh.customer_journey_summary #>> '{firstVisit, sourceType}') as first_visit_source_type,
    public.clean_string(foh.customer_journey_summary #>> '{firstVisit, utmParameters, campaign}') as first_visit_utm_campaign,
    public.clean_string(foh.customer_journey_summary #>> '{lastVisit, source}') as last_visit_source,
    public.clean_string(foh.customer_journey_summary #>> '{lastVisit, sourceType}') as last_visit_source_type
from public.fact_order_headers foh
where foh.seller_id = :shopId
and (foh.created_at::date between :createdAtStart::date and :createdAtEnd::date)
and (foh.test = false OR EXISTS (SELECT 1 FROM public.seller sl WHERE sl.shop_id = :shopId AND sl.store_type <> 'MERCHANT'))
AND foh.record_status = 'ACTIVE'
)
SELECT
    /*projection_fields*/
from base
where true
/*additional_filters*/
    $$,
    '2026-09-02 07:34:30.559198',
    '2026-09-02 07:34:30.559198'
),
(
    '019f45c3-a5aa-7b69-9988-a967d4be7a2d',
    'Refunds & Reversals',
    'Provides information about refund orders in line item level.',
    '["CSV", "XLSX"]',
    '[
      {"type": "DATE_RANGE", "label": "Date Range", "column": "createdAt", "options": [{"key": "-1", "label": "Last 1 Days"}, {"key": "-7", "label": "Last 7 Days"}, {"key": "-14", "label": "Last 14 Days"}, {"key": "-30", "label": "Last 1 Month"}, {"key": "-90", "label": "Last 3 Months"}, {"key": "-180", "label": "Last 6 Months"}, {"key": "-365", "label": "Last 12 Months"}, {"key": "MTD", "label": "This Month"}, {"key": "PREVIOUS-MONTH", "label": "Previous Month"}, {"key": "QTD", "label": "This Quarter"}, {"key": "PREVIOUS-QUARTER", "label": "Previous Quarter"}, {"key": "YTD", "label": "This Year"}, {"key": "PREVIOUS-YEAR", "label": "Previous Year"}, {"key": "CUSTOM", "label": "Choose Date Range"}], "defaultValue": "-30"}
    ]',
    '[
      {"type": "TEXT", "state": "REQUIRED", "title": "Order ID", "column": "order_id"},
      {"type": "DATE", "state": "REQUIRED", "title": "Order Date", "column": "order_date"},
      {"type": "TEXT", "state": "CHECKED", "title": "Order Financial Status", "column": "order_financial_status"},
      {"type": "TEXT", "state": "CHECKED", "title": "Product Name", "column": "product_name"},
      {"type": "TEXT", "state": "CHECKED", "title": "Vendor", "column": "vendor"},
      {"type": "TEXT", "state": "CHECKED", "title": "SKU", "column": "sku"},
      {"type": "TEXT", "state": "CHECKED", "title": "Variant", "column": "variant_name"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Refunded Quantity", "column": "refund_quantity"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Original Unit Price", "column": "original_unit_price"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Refunded Line Amount", "column": "refund_line_item_price"},
      {"type": "DATE", "state": "CHECKED", "title": "Refund Date", "column": "refund_date"},
      {"type": "DATE", "state": "CHECKED", "title": "Refund Processed On", "column": "refund_processed_at"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Total Refund Amount", "column": "total_refunded_amount"},
      {"type": "TEXT", "state": "CHECKED", "title": "Restock Type", "column": "restock_type"},
      {"type": "TEXT", "state": "CHECKED", "title": "Currency", "column": "currency_code"},
      {"type": "TEXT", "state": "CHECKED", "title": "Refund Note", "column": "refund_note"}
    ]',
    '{
      "filterMappings": {
        "shopId": {"source": "AUTH_CONTEXT", "contextKey": "shopGid"},
        "createdAtEnd": {"index": 1, "source": "REQUEST_FILTER", "filterKey": "createdAt"},
        "createdAtStart": {"index": 0, "source": "REQUEST_FILTER", "filterKey": "createdAt"}
      },
      "excludeExtraParams": true
    }',
    NULL,
    $$
with base as (

select
    foh.id                        as order_id,
    foh.created_at                as order_date,
    foh.financialstatus              as order_financial_status,

    foli.product_name,
    foli.vendor,
    foli.sku,
    foli.variant_name,
    frli.refund_quantity,
    foli.original_unit_price,
    frli.refund_line_item_price,

    fr.created_at                   as refund_date,
    fr.processed_at                 as refund_processed_at,
    fr.total_refunded_amount,
    frli.restock_type,

    foh.currency_code,
    fr.note                         as refund_note

from public.fact_order_refunds fr
inner join public.fact_order_headers foh
    on foh.id = fr.order_id
    and foh.seller_id = fr.seller_id
    AND foh.record_status = 'ACTIVE'
left join public.fact_order_refund_line_items frli
    on frli.refund_id = fr.id
    and frli.seller_id = fr.seller_id
    AND frli.record_status = 'ACTIVE'
left join public.fact_order_line_items foli
    on foli.id = frli.order_line_item_id
    and foli.seller_id = fr.seller_id
    AND foli.record_status = 'ACTIVE'

where fr.seller_id = :shopId
    and (fr.created_at::date between :createdAtStart::date and :createdAtEnd::date)
    and (foh.test = false OR EXISTS (SELECT 1 FROM public.seller sl WHERE sl.shop_id = :shopId AND sl.store_type <> 'MERCHANT'))
    AND fr.record_status = 'ACTIVE'
)
SELECT
/*projection_fields*/
from base
where true
/*additional_filters*/
order by order_id
    $$,
    '2026-09-02 11:47:00.548905',
    '2026-09-02 11:47:00.548905'
),
(
    '019f45c3-a5aa-7bb1-9fce-f7dd67d28288',
    'Inventory Locations',
    'Provides inventory information for products per inventory locations.',
    '["CSV", "XLSX"]',
    '[
      {"type": "DATE_RANGE", "label": "Date Range", "column": "createdAt", "options": [{"key": "-1", "label": "Last 1 Days"}, {"key": "-7", "label": "Last 7 Days"}, {"key": "-14", "label": "Last 14 Days"}, {"key": "-30", "label": "Last 1 Month"}, {"key": "-90", "label": "Last 3 Months"}, {"key": "-180", "label": "Last 6 Months"}, {"key": "-365", "label": "Last 12 Months"}, {"key": "MTD", "label": "This Month"}, {"key": "PREVIOUS-MONTH", "label": "Previous Month"}, {"key": "QTD", "label": "This Quarter"}, {"key": "PREVIOUS-QUARTER", "label": "Previous Quarter"}, {"key": "YTD", "label": "This Year"}, {"key": "PREVIOUS-YEAR", "label": "Previous Year"}, {"key": "CUSTOM", "label": "Choose Date Range"}], "defaultValue": "-30"}
    ]',
    '[
      {"type": "TEXT", "state": "REQUIRED", "title": "Inventory Location Name", "column": "location_name"},
      {"type": "TEXT", "state": "REQUIRED", "title": "Inventory Location City", "column": "location_city"},
      {"type": "TEXT", "state": "CHECKED", "title": "Inventory Location Province/State", "column": "location_province"},
      {"type": "TEXT", "state": "CHECKED", "title": "Inventory Location Country", "column": "location_country"},
      {"type": "DATE", "state": "CHECKED", "title": "Inventory Location Created On", "column": "inventory_created_at"},
      {"type": "TEXT", "state": "CHECKED", "title": "Inventory Location Status", "column": "location_status"},
      {"type": "TEXT", "state": "CHECKED", "title": "Online Fulfillment", "column": "fulfills_online_orders"},
      {"type": "TEXT", "state": "CHECKED", "title": "Product Name", "column": "product_name"},
      {"type": "TEXT", "state": "CHECKED", "title": "Variant", "column": "variant"},
      {"type": "TEXT", "state": "CHECKED", "title": "Vendor", "column": "vendor"},
      {"type": "TEXT", "state": "CHECKED", "title": "SKU", "column": "sku"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Price", "column": "price"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Quantity On Hand", "column": "quantity_on_hand"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Quantity Available", "column": "quantity_available"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Quantity Committed", "column": "quantity_committed"},
      {"type": "NUMBER", "state": "CHECKED", "title": "Quantity Incoming", "column": "quantity_incoming"}
    ]',
    '{
      "filterMappings": {
        "shopId": {"source": "AUTH_CONTEXT", "contextKey": "shopGid"},
        "createdAtEnd": {"index": 1, "source": "REQUEST_FILTER", "filterKey": "createdAt"},
        "createdAtStart": {"index": 0, "source": "REQUEST_FILTER", "filterKey": "createdAt"}
      },
      "excludeExtraParams": true
    }',
    NULL,
    $$
with base as (

SELECT
    -- Location fields
    dil.id,
    dil.name                                        AS location_name,
    dil.address #>> '{city}'                          AS location_city,
    dil.address #>> '{provinceCode}'                  AS location_province,
    dil.address #>> '{countryCode}'                   AS location_country,
    dil.created_at as inventory_created_at,
    CASE
        WHEN dil.is_active THEN 'Active'
        ELSE 'Inactive'
    END                                              AS location_status,
    CASE
        WHEN dil.fulfills_online_orders THEN 'Ships Online Orders'
        ELSE 'In-Store Only'
    END                                              AS fulfills_online_orders,

    -- Product & Variant fields
    dp.title                                        AS product_name,
    dpv.variant_title                                AS variant,
    dp.vendor                                       AS vendor,
    dpv.sku                                          AS sku,
    dpv.price                                        AS price,

    -- Inventory level fields
    dilv.on_hand_quantity                            AS quantity_on_hand,
    dilv.available_quantity                          AS quantity_available,
    dilv.committed_quantity                          AS quantity_committed,
    dilv.incoming_quantity                           AS quantity_incoming

FROM public.dim_inventory_locations dil
INNER JOIN public.dim_inventory_levels dilv
    ON dil.id = dilv.inventory_location_id
   AND dil.seller_id = dilv.seller_id
   AND dilv.record_status = 'ACTIVE'
left JOIN public.dim_product_variants dpv
    ON dpv.inventory_item_id = dilv.inventory_item_id
   AND dpv.seller_id = dilv.seller_id
   AND dpv.record_status = 'ACTIVE'
left JOIN public.dim_products dp
    ON dp.id = dpv.product_id
   AND dp.seller_id = dpv.seller_id
   AND dp.record_status = 'ACTIVE'

WHERE dil.seller_id = :shopId
  AND (dil.created_at::date between :createdAtStart::date and :createdAtEnd::date)
  AND dil.record_status = 'ACTIVE'
)
SELECT
    /*projection_fields*/
from base
where true
/*additional_filters*/
    $$,
    '2026-09-02 07:50:47.367000',
    '2026-09-02 07:50:47.367899'
);
