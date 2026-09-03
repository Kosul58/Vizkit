
-- ---------- 1. charts: value only ----------

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '01a066fe-171d-77b4-8e36-56ab5085c279',
    'Total Payment Amount',
    'Payments & Transactions/Payment Overview/KPI/Total Payment Amount',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(t.amount, 0)), 0), 2) AS total_payment_amount
    FROM public.fact_order_transactions t
    JOIN public.fact_order_headers o ON o.id = t.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND t.test = FALSE
      AND UPPER(t.kind) IN ('SALE', 'CAPTURE')
      AND UPPER(t.status) = 'SUCCESS'
      AND (:currentStartDate::date IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Successful payment volume for the selected period vs the prior period.',
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
    '01a066fe-171d-7955-8215-3afba3718e02',
    'Net Payment Received',
    'Payments & Transactions/Payment Overview/KPI/Net Payment Received',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(t.amount, 0))
                          FILTER (WHERE UPPER(t.kind) IN ('SALE', 'CAPTURE')
                                    AND UPPER(t.status) = 'SUCCESS'), 0)
               - COALESCE(SUM(COALESCE(t.amount, 0))
                          FILTER (WHERE UPPER(t.kind) = 'REFUND'
                                    AND UPPER(t.status) = 'SUCCESS'), 0), 2)
           AS net_payment_received
    FROM public.fact_order_transactions t
    JOIN public.fact_order_headers o ON o.id = t.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND t.test = FALSE
      AND (:currentStartDate::date IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Payments less refunds for the selected period vs the prior period.',
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
    '01a066fe-171d-7f85-9330-47452ba7f843',
    'Transaction Count',
    'Payments & Transactions/Payment Overview/KPI/Transaction Count',
    $$
    SELECT COUNT(*) AS transaction_count
    FROM public.fact_order_transactions t
    JOIN public.fact_order_headers o ON o.id = t.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND t.test = FALSE
      AND (:currentStartDate::date IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Transactions of any kind for the selected period vs the prior period.',
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
    '01a066fe-171d-7925-91f1-deb646816e01',
    'Top Payment Method',
    'Payments & Transactions/Payment Overview/KPI/Top Payment Method',
    $$
    WITH scoped_tender AS (
        SELECT INITCAP(REPLACE(COALESCE(tt.payment_method, 'Unattributed'),
                               CHR(95), CHR(32))) AS method,
               COALESCE(tt.amount, 0) AS amount
        FROM public.dim_tender_transactions tt
        JOIN public.fact_order_headers o ON o.id = tt.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND tt.test = FALSE
          AND (:currentStartDate::date IS NULL OR tt.processed_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR tt.processed_at::date <= :currentEndDate::date)
    )
    SELECT COALESCE((SELECT method FROM scoped_tender
                     GROUP BY method
                     ORDER BY SUM(amount) DESC NULLS LAST, method ASC
                     LIMIT 1), 'No data') AS top_payment_method
    $$,
    NULL,
    'KPI',
    60,
    'Payment method with the highest tender volume in the selected period.',
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
    '01a066fe-171d-7b80-93aa-1c5288c446eb',
    'Top Gateway',
    'Payments & Transactions/Payment Overview/KPI/Top Gateway',
    $$
    WITH scoped_txn AS (
        SELECT INITCAP(REPLACE(COALESCE(t.gateway, 'Unknown'),
                               CHR(95), CHR(32))) AS gateway,
               COALESCE(t.amount, 0) AS amount
        FROM public.fact_order_transactions t
        JOIN public.fact_order_headers o ON o.id = t.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND t.test = FALSE
          AND UPPER(t.kind) IN ('SALE', 'CAPTURE')
          AND UPPER(t.status) = 'SUCCESS'
          AND (:currentStartDate::date IS NULL
               OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL
               OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    )
    SELECT COALESCE((SELECT gateway FROM scoped_txn
                     GROUP BY gateway
                     ORDER BY SUM(amount) DESC NULLS LAST, gateway ASC
                     LIMIT 1), 'No data') AS top_gateway
    $$,
    NULL,
    'KPI',
    60,
    'Payment gateway with the highest successful payment volume in the selected period.',
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
    '01a066fe-171e-7abf-bc17-eb1627e26a65',
    'Transaction Fees',
    'Payments & Transactions/Payment Costs & Gateway Performance/KPI/Transaction Fees',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(t.transaction_fee, 0)), 0), 2) AS transaction_fees
    FROM public.fact_order_transactions t
    JOIN public.fact_order_headers o ON o.id = t.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND t.test = FALSE
      AND UPPER(t.kind) IN ('SALE', 'CAPTURE')
      AND UPPER(t.status) = 'SUCCESS'
      AND (:currentStartDate::date IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Gateway transaction fees for the selected period vs the prior period.',
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
    '01a066fe-171f-79ee-bee6-0f529107aa8e',
    'Fee Rate',
    'Payments & Transactions/Payment Costs & Gateway Performance/KPI/Fee Rate',
    $$
    SELECT COALESCE(ROUND(100 * COALESCE(SUM(COALESCE(t.transaction_fee, 0)), 0)
                          / NULLIF(COALESCE(SUM(COALESCE(t.amount, 0)), 0), 0), 2), 0) AS fee_rate
    FROM public.fact_order_transactions t
    JOIN public.fact_order_headers o ON o.id = t.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND t.test = FALSE
      AND UPPER(t.kind) IN ('SALE', 'CAPTURE')
      AND UPPER(t.status) = 'SUCCESS'
      AND (:currentStartDate::date IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Fees as a percentage of payment volume for the selected period vs the prior period.',
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
    '01a066fe-171f-7528-9fb8-0b08d81a0a4c',
    'Failed Transactions',
    'Payments & Transactions/Payment Health & Reliability/KPI/Failed Transactions',
    $$
    SELECT COUNT(*) AS failed_transactions
    FROM public.fact_order_transactions t
    JOIN public.fact_order_headers o ON o.id = t.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND t.test = FALSE
      AND UPPER(t.status) IN ('FAILURE', 'ERROR')
      AND (:currentStartDate::date IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Failed transaction count for the selected period vs the prior period.',
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
    '01a066fe-171f-711a-8d55-5e22770e3a09',
    'Failed Amount',
    'Payments & Transactions/Payment Health & Reliability/KPI/Failed Amount',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(t.amount, 0)), 0), 2) AS failed_amount
    FROM public.fact_order_transactions t
    JOIN public.fact_order_headers o ON o.id = t.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND t.test = FALSE
      AND UPPER(t.status) IN ('FAILURE', 'ERROR')
      AND (:currentStartDate::date IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Value of failed transactions for the selected period vs the prior period.',
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
    '01a066fe-171f-763c-9fb0-b21194e9e97b',
    'Pending Transactions',
    'Payments & Transactions/Payment Health & Reliability/KPI/Pending Transactions',
    $$
    SELECT COUNT(*) AS pending_transactions
    FROM public.fact_order_transactions t
    JOIN public.fact_order_headers o ON o.id = t.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND t.test = FALSE
      AND UPPER(t.status) IN ('PENDING', 'AWAITING_RESPONSE')
      AND (:currentStartDate::date IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Pending transaction count for the selected period vs the prior period.',
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
    '01a066fe-171f-7549-8d9f-1cee201690e9',
    'Pending Amount',
    'Payments & Transactions/Payment Health & Reliability/KPI/Pending Amount',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(t.amount, 0)), 0), 2) AS pending_amount
    FROM public.fact_order_transactions t
    JOIN public.fact_order_headers o ON o.id = t.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND t.test = FALSE
      AND UPPER(t.status) IN ('PENDING', 'AWAITING_RESPONSE')
      AND (:currentStartDate::date IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Value of pending transactions for the selected period vs the prior period.',
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
    '01a066fe-1720-7afb-9349-b638599d92eb',
    'Refund Transactions',
    'Payments & Transactions/Reconciliation & Refund Payments/KPI/Refund Transactions',
    $$
    SELECT COUNT(*) AS refund_transactions
    FROM public.fact_order_transactions t
    JOIN public.fact_order_headers o ON o.id = t.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND t.test = FALSE
      AND UPPER(t.kind) = 'REFUND'
      AND UPPER(t.status) = 'SUCCESS'
      AND (:currentStartDate::date IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Successful refund transaction count for the selected period vs the prior period.',
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
    '01a066fe-1720-7332-918a-dc2aeae10418',
    'Refund Amount',
    'Payments & Transactions/Reconciliation & Refund Payments/KPI/Refund Amount',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(t.amount, 0)), 0), 2) AS refund_amount
    FROM public.fact_order_transactions t
    JOIN public.fact_order_headers o ON o.id = t.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND t.test = FALSE
      AND UPPER(t.kind) = 'REFUND'
      AND UPPER(t.status) = 'SUCCESS'
      AND (:currentStartDate::date IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Value refunded through payment transactions for the selected period vs the prior period.',
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
    '01a066fe-1720-702e-9532-cd90cb9c81f3',
    'Maximum Refundable Amount',
    'Payments & Transactions/Reconciliation & Refund Payments/KPI/Maximum Refundable Amount',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(t.maximum_refundable_amount, 0)), 0), 2)
           AS maximum_refundable_amount
    FROM public.fact_order_transactions t
    JOIN public.fact_order_headers o ON o.id = t.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND t.test = FALSE
      AND UPPER(t.kind) IN ('SALE', 'CAPTURE')
      AND UPPER(t.status) = 'SUCCESS'
      AND (:currentStartDate::date IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Refundable balance still available on payments, for the selected period vs the prior period.',
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
    '01a066fe-1721-7a63-85c9-1792687065a6',
    'Uncaptured Amount',
    'Payments & Transactions/Authorization & Payment Risk/KPI/Uncaptured Amount',
    $$
    WITH per_order AS (
        SELECT t.order_id,
               COALESCE(SUM(COALESCE(t.amount, 0))
                        FILTER (WHERE UPPER(t.kind) IN ('AUTHORIZATION', 'EMV_AUTHORIZATION')
                                  AND UPPER(t.status) = 'SUCCESS'), 0) AS authorized,
               COALESCE(SUM(COALESCE(t.amount, 0))
                        FILTER (WHERE UPPER(t.kind) IN ('SALE', 'CAPTURE')
                                  AND UPPER(t.status) = 'SUCCESS'), 0) AS captured
        FROM public.fact_order_transactions t
        JOIN public.fact_order_headers o ON o.id = t.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND t.test = FALSE
          AND (:currentStartDate::date IS NULL
               OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL
               OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
        GROUP BY t.order_id
    )
    SELECT ROUND(COALESCE(SUM(GREATEST(p.authorized - p.captured, 0)), 0), 2) AS uncaptured_amount
    FROM per_order p
    $$,
    NULL,
    'KPI',
    60,
    'Authorized value never captured, for the selected period vs the prior period.',
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
    '01a066fe-1722-7467-82b1-0cc282753e93',
    'Manual Payment Amount',
    'Payments & Transactions/POS & Alternative Payment Operations/KPI/Manual Payment Amount',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(t.amount, 0)), 0), 2) AS manual_payment_amount
    FROM public.fact_order_transactions t
    JOIN public.fact_order_headers o ON o.id = t.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND t.test = FALSE
      AND t.manual_payment_gateway
      AND UPPER(t.kind) IN ('SALE', 'CAPTURE')
      AND UPPER(t.status) = 'SUCCESS'
      AND (:currentStartDate::date IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Payment volume taken through manual gateways, for the selected period vs the prior period.',
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
    '01a066fe-1722-7917-8925-07154749e843',
    'Cash Rounding Adjustment',
    'Payments & Transactions/POS & Alternative Payment Operations/KPI/Cash Rounding Adjustment',
    $$
    SELECT ROUND(COALESCE(SUM(COALESCE(t.amount_rounding, 0)), 0), 2) AS cash_rounding_adjustment
    FROM public.fact_order_transactions t
    JOIN public.fact_order_headers o ON o.id = t.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      AND t.test = FALSE
      AND (:currentStartDate::date IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
      AND (:currentEndDate::date   IS NULL
           OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    $$,
    NULL,
    'KPI',
    60,
    'Cash rounding applied at tender, for the selected period vs the prior period.',
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
    '01a066fe-1722-7a8b-aaa5-85693dce8e5f',
    'Top Card Brand',
    'Payments & Transactions/POS & Alternative Payment Operations/KPI/Top Card Brand',
    $$
    WITH scoped_tender AS (
        SELECT INITCAP(REPLACE(tt.transaction_credit_card_company, CHR(95), CHR(32))) AS card_brand,
               COALESCE(tt.amount, 0) AS amount
        FROM public.dim_tender_transactions tt
        JOIN public.fact_order_headers o ON o.id = tt.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          AND tt.test = FALSE
          AND tt.transaction_credit_card_company IS NOT NULL
          AND (:currentStartDate::date IS NULL OR tt.processed_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR tt.processed_at::date <= :currentEndDate::date)
    )
    SELECT COALESCE((SELECT card_brand FROM scoped_tender
                     GROUP BY card_brand
                     ORDER BY SUM(amount) DESC NULLS LAST, card_brand ASC
                     LIMIT 1), 'No data') AS top_card_brand
    $$,
    NULL,
    'KPI',
    60,
    'Credit card brand with the highest tender volume in the selected period.',
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
);

-- ---------- 2. chart signals: divergence ----------

INSERT INTO vizkit.chart_signal (id, chart_id, name, query)
VALUES (
    '019fffa3-ddd4-7b01-8ff1-8a2b3c4d1001',
    '01a066fe-171d-77b4-8e36-56ab5085c279',
    'total_payment_amount',
    $$
    WITH txn_totals AS (
        SELECT COALESCE(SUM(amount) FILTER (WHERE is_current AND is_payment), 0) AS cur_value,
               COALESCE(SUM(amount) FILTER (WHERE is_prior   AND is_payment), 0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(t.processed_at, t.created_at)::date
                    BETWEEN :priorStartDate::date AND :priorEndDate::date)                      AS is_prior,
                   COALESCE(t.amount, 0) AS amount,
                   (UPPER(t.kind) IN ('SALE', 'CAPTURE')
                AND UPPER(t.status) = 'SUCCESS') AS is_payment
            FROM public.fact_order_transactions t
            JOIN public.fact_order_headers o ON o.id = t.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND t.test = FALSE
        ) x
        WHERE x.is_current OR x.is_prior
    )
    SELECT ROUND(tot.prv_value, 2) AS previous_value,
           ROUND(100 * (tot.cur_value - tot.prv_value)
                 / NULLIF(ABS(tot.prv_value), 0), 2) AS divergence
    FROM txn_totals tot
    $$
),
(
    '019fffa3-ddd4-7b02-8ff2-8a2b3c4d1002',
    '01a066fe-171d-7955-8215-3afba3718e02',
    'net_payment_received',
    $$
    WITH txn_totals AS (
        SELECT COALESCE(SUM(amount) FILTER (WHERE is_current AND is_payment), 0)
             - COALESCE(SUM(amount) FILTER (WHERE is_current AND is_refund),  0) AS cur_value,
               COALESCE(SUM(amount) FILTER (WHERE is_prior   AND is_payment), 0)
             - COALESCE(SUM(amount) FILTER (WHERE is_prior   AND is_refund),  0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(t.processed_at, t.created_at)::date
                    BETWEEN :priorStartDate::date AND :priorEndDate::date)                      AS is_prior,
                   COALESCE(t.amount, 0) AS amount,
                   (UPPER(t.kind) IN ('SALE', 'CAPTURE')
                AND UPPER(t.status) = 'SUCCESS') AS is_payment,
                   (UPPER(t.kind) = 'REFUND'
                AND UPPER(t.status) = 'SUCCESS') AS is_refund
            FROM public.fact_order_transactions t
            JOIN public.fact_order_headers o ON o.id = t.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND t.test = FALSE
        ) x
        WHERE x.is_current OR x.is_prior
    )
    SELECT ROUND(tot.prv_value, 2) AS previous_value,
           ROUND(100 * (tot.cur_value - tot.prv_value)
                 / NULLIF(ABS(tot.prv_value), 0), 2) AS divergence
    FROM txn_totals tot
    $$
),
(
    '019fffa3-ddd4-7b03-8ff3-8a2b3c4d1003',
    '01a066fe-171d-7f85-9330-47452ba7f843',
    'transaction_count',
    $$
    WITH txn_totals AS (
        SELECT COUNT(*) FILTER (WHERE is_current) AS cur_value,
               COUNT(*) FILTER (WHERE is_prior)   AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(t.processed_at, t.created_at)::date
                    BETWEEN :priorStartDate::date AND :priorEndDate::date)                      AS is_prior
            FROM public.fact_order_transactions t
            JOIN public.fact_order_headers o ON o.id = t.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND t.test = FALSE
        ) x
        WHERE x.is_current OR x.is_prior
    )
    SELECT tot.prv_value AS previous_value,
           ROUND(100.0 * (tot.cur_value - tot.prv_value)
                 / NULLIF(ABS(tot.prv_value), 0), 2) AS divergence
    FROM txn_totals tot
    $$
),
(
    '019fffa3-ddd4-7b04-8ff4-8a2b3c4d1004',
    '01a066fe-171e-7abf-bc17-eb1627e26a65',
    'transaction_fees',
    $$
    WITH totals AS (
        SELECT COALESCE(SUM(fee) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(fee) FILTER (WHERE is_prior),   0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(t.processed_at, t.created_at)::date
                    BETWEEN :priorStartDate::date AND :priorEndDate::date)                      AS is_prior,
                   COALESCE(t.transaction_fee, 0) AS fee
            FROM public.fact_order_transactions t
            JOIN public.fact_order_headers o ON o.id = t.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND t.test = FALSE
              AND UPPER(t.kind) IN ('SALE', 'CAPTURE')
              AND UPPER(t.status) = 'SUCCESS'
        ) x
        WHERE x.is_current OR x.is_prior
    )
    SELECT ROUND(tot.prv_value, 2) AS previous_value,
           ROUND(100 * (tot.cur_value - tot.prv_value)
                 / NULLIF(ABS(tot.prv_value), 0), 2) AS divergence
    FROM totals tot
    $$
),
(
    '019fffa3-ddd4-7b05-8ff5-8a2b3c4d1005',
    '01a066fe-171f-79ee-bee6-0f529107aa8e',
    'fee_rate',
    $$
    WITH totals AS (
        SELECT COALESCE(SUM(fee)    FILTER (WHERE is_current), 0) AS cur_fees,
               COALESCE(SUM(fee)    FILTER (WHERE is_prior),   0) AS prv_fees,
               COALESCE(SUM(amount) FILTER (WHERE is_current), 0) AS cur_amount,
               COALESCE(SUM(amount) FILTER (WHERE is_prior),   0) AS prv_amount
        FROM (
            SELECT ((:currentStartDate::date IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(t.processed_at, t.created_at)::date
                    BETWEEN :priorStartDate::date AND :priorEndDate::date)                      AS is_prior,
                   COALESCE(t.amount, 0) AS amount,
                   COALESCE(t.transaction_fee, 0) AS fee
            FROM public.fact_order_transactions t
            JOIN public.fact_order_headers o ON o.id = t.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND t.test = FALSE
              AND UPPER(t.kind) IN ('SALE', 'CAPTURE')
              AND UPPER(t.status) = 'SUCCESS'
        ) x
        WHERE x.is_current OR x.is_prior
    ),
    computed AS (
        SELECT ROUND(100 * tot.cur_fees / NULLIF(tot.cur_amount, 0), 2) AS cur_rate,
               ROUND(100 * tot.prv_fees / NULLIF(tot.prv_amount, 0), 2) AS prv_rate
        FROM totals tot
    )
    SELECT c.prv_rate AS previous_value,
           ROUND(100 * (c.cur_rate - c.prv_rate)
                 / NULLIF(ABS(c.prv_rate), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fffa3-ddd4-7b06-8ff6-8a2b3c4d1006',
    '01a066fe-171f-7528-9fb8-0b08d81a0a4c',
    'failed_transactions',
    $$
    WITH totals AS (
        SELECT COUNT(*) FILTER (WHERE is_current AND is_failed) AS cur_value,
               COUNT(*) FILTER (WHERE is_prior   AND is_failed) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(t.processed_at, t.created_at)::date
                    BETWEEN :priorStartDate::date AND :priorEndDate::date)                      AS is_prior,
                   (UPPER(t.status) IN ('FAILURE', 'ERROR')) AS is_failed
            FROM public.fact_order_transactions t
            JOIN public.fact_order_headers o ON o.id = t.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND t.test = FALSE
        ) x
        WHERE x.is_current OR x.is_prior
    )
    SELECT t.prv_value AS previous_value,
           ROUND(100.0 * (t.cur_value - t.prv_value)
                 / NULLIF(ABS(t.prv_value), 0), 2) AS divergence
    FROM totals t
    $$
),
(
    '019fffa3-ddd4-7b07-8ff7-8a2b3c4d1007',
    '01a066fe-171f-711a-8d55-5e22770e3a09',
    'failed_amount',
    $$
    WITH totals AS (
        SELECT COALESCE(SUM(amount) FILTER (WHERE is_current AND is_failed), 0) AS cur_value,
               COALESCE(SUM(amount) FILTER (WHERE is_prior   AND is_failed), 0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(t.processed_at, t.created_at)::date
                    BETWEEN :priorStartDate::date AND :priorEndDate::date)                      AS is_prior,
                   COALESCE(t.amount, 0) AS amount,
                   (UPPER(t.status) IN ('FAILURE', 'ERROR')) AS is_failed
            FROM public.fact_order_transactions t
            JOIN public.fact_order_headers o ON o.id = t.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND t.test = FALSE
        ) x
        WHERE x.is_current OR x.is_prior
    )
    SELECT ROUND(t.prv_value, 2) AS previous_value,
           ROUND(100 * (t.cur_value - t.prv_value)
                 / NULLIF(ABS(t.prv_value), 0), 2) AS divergence
    FROM totals t
    $$
),
(
    '019fffa3-ddd4-7b08-8ff8-8a2b3c4d1008',
    '01a066fe-171f-763c-9fb0-b21194e9e97b',
    'pending_transactions',
    $$
    WITH totals AS (
        SELECT COUNT(*) FILTER (WHERE is_current AND is_pending) AS cur_value,
               COUNT(*) FILTER (WHERE is_prior   AND is_pending) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(t.processed_at, t.created_at)::date
                    BETWEEN :priorStartDate::date AND :priorEndDate::date)                      AS is_prior,
                   (UPPER(t.status) IN ('PENDING', 'AWAITING_RESPONSE')) AS is_pending
            FROM public.fact_order_transactions t
            JOIN public.fact_order_headers o ON o.id = t.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND t.test = FALSE
        ) x
        WHERE x.is_current OR x.is_prior
    )
    SELECT t.prv_value AS previous_value,
           ROUND(100.0 * (t.cur_value - t.prv_value)
                 / NULLIF(ABS(t.prv_value), 0), 2) AS divergence
    FROM totals t
    $$
),
(
    '019fffa3-ddd4-7b09-8ff9-8a2b3c4d1009',
    '01a066fe-171f-7549-8d9f-1cee201690e9',
    'pending_amount',
    $$
    WITH totals AS (
        SELECT COALESCE(SUM(amount) FILTER (WHERE is_current AND is_pending), 0) AS cur_value,
               COALESCE(SUM(amount) FILTER (WHERE is_prior   AND is_pending), 0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(t.processed_at, t.created_at)::date
                    BETWEEN :priorStartDate::date AND :priorEndDate::date)                      AS is_prior,
                   COALESCE(t.amount, 0) AS amount,
                   (UPPER(t.status) IN ('PENDING', 'AWAITING_RESPONSE')) AS is_pending
            FROM public.fact_order_transactions t
            JOIN public.fact_order_headers o ON o.id = t.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND t.test = FALSE
        ) x
        WHERE x.is_current OR x.is_prior
    )
    SELECT ROUND(t.prv_value, 2) AS previous_value,
           ROUND(100 * (t.cur_value - t.prv_value)
                 / NULLIF(ABS(t.prv_value), 0), 2) AS divergence
    FROM totals t
    $$
),
(
    '019fffa3-ddd4-7b0a-8ffa-8a2b3c4d100a',
    '01a066fe-1720-7afb-9349-b638599d92eb',
    'refund_transactions',
    $$
    WITH totals AS (
        SELECT COUNT(*) FILTER (WHERE is_current AND is_refund) AS cur_value,
               COUNT(*) FILTER (WHERE is_prior   AND is_refund) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(t.processed_at, t.created_at)::date
                    BETWEEN :priorStartDate::date AND :priorEndDate::date)                      AS is_prior,
                   (UPPER(t.kind) = 'REFUND'
                AND UPPER(t.status) = 'SUCCESS') AS is_refund
            FROM public.fact_order_transactions t
            JOIN public.fact_order_headers o ON o.id = t.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND t.test = FALSE
        ) x
        WHERE x.is_current OR x.is_prior
    )
    SELECT t.prv_value AS previous_value,
           ROUND(100.0 * (t.cur_value - t.prv_value)
                 / NULLIF(ABS(t.prv_value), 0), 2) AS divergence
    FROM totals t
    $$
),
(
    '019fffa3-ddd4-7b0b-8ffb-8a2b3c4d100b',
    '01a066fe-1720-7332-918a-dc2aeae10418',
    'refund_amount',
    $$
    WITH totals AS (
        SELECT COALESCE(SUM(amount) FILTER (WHERE is_current AND is_refund), 0) AS cur_value,
               COALESCE(SUM(amount) FILTER (WHERE is_prior   AND is_refund), 0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(t.processed_at, t.created_at)::date
                    BETWEEN :priorStartDate::date AND :priorEndDate::date)                      AS is_prior,
                   COALESCE(t.amount, 0) AS amount,
                   (UPPER(t.kind) = 'REFUND'
                AND UPPER(t.status) = 'SUCCESS') AS is_refund
            FROM public.fact_order_transactions t
            JOIN public.fact_order_headers o ON o.id = t.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND t.test = FALSE
        ) x
        WHERE x.is_current OR x.is_prior
    )
    SELECT ROUND(t.prv_value, 2) AS previous_value,
           ROUND(100 * (t.cur_value - t.prv_value)
                 / NULLIF(ABS(t.prv_value), 0), 2) AS divergence
    FROM totals t
    $$
),
(
    '019fffa3-ddd4-7b0c-8ffc-8a2b3c4d100c',
    '01a066fe-1720-702e-9532-cd90cb9c81f3',
    'maximum_refundable_amount',
    $$
    WITH totals AS (
        SELECT COALESCE(SUM(max_refundable) FILTER (WHERE is_current AND is_payment), 0) AS cur_value,
               COALESCE(SUM(max_refundable) FILTER (WHERE is_prior   AND is_payment), 0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(t.processed_at, t.created_at)::date
                    BETWEEN :priorStartDate::date AND :priorEndDate::date)                      AS is_prior,
                   COALESCE(t.maximum_refundable_amount, 0) AS max_refundable,
                   (UPPER(t.kind) IN ('SALE', 'CAPTURE')
                AND UPPER(t.status) = 'SUCCESS') AS is_payment
            FROM public.fact_order_transactions t
            JOIN public.fact_order_headers o ON o.id = t.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND t.test = FALSE
        ) x
        WHERE x.is_current OR x.is_prior
    )
    SELECT ROUND(t.prv_value, 2) AS previous_value,
           ROUND(100 * (t.cur_value - t.prv_value)
                 / NULLIF(ABS(t.prv_value), 0), 2) AS divergence
    FROM totals t
    $$
),
(
    '019fffa3-ddd4-7b0d-8ffd-8a2b3c4d100d',
    '01a066fe-1721-7a63-85c9-1792687065a6',
    'uncaptured_amount',
    $$
    WITH scoped_txn AS (
        SELECT * FROM (
            SELECT t.order_id,
                   ((:currentStartDate::date IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(t.processed_at, t.created_at)::date
                    BETWEEN :priorStartDate::date AND :priorEndDate::date)                      AS is_prior,
                   COALESCE(t.amount, 0) AS amount,
                   (UPPER(t.kind) IN ('AUTHORIZATION', 'EMV_AUTHORIZATION')
                AND UPPER(t.status) = 'SUCCESS') AS is_authorized,
                   (UPPER(t.kind) IN ('SALE', 'CAPTURE')
                AND UPPER(t.status) = 'SUCCESS') AS is_captured
            FROM public.fact_order_transactions t
            JOIN public.fact_order_headers o ON o.id = t.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND t.test = FALSE
        ) x
        WHERE x.is_current OR x.is_prior
    ),
    per_order AS (
        SELECT s.order_id,
               COALESCE(SUM(s.amount) FILTER (WHERE s.is_current AND s.is_authorized), 0) AS cur_authorized,
               COALESCE(SUM(s.amount) FILTER (WHERE s.is_current AND s.is_captured),   0) AS cur_captured,
               COALESCE(SUM(s.amount) FILTER (WHERE s.is_prior   AND s.is_authorized), 0) AS prv_authorized,
               COALESCE(SUM(s.amount) FILTER (WHERE s.is_prior   AND s.is_captured),   0) AS prv_captured
        FROM scoped_txn s
        GROUP BY s.order_id
    ),
    computed AS (
        SELECT COALESCE(SUM(GREATEST(p.cur_authorized - p.cur_captured, 0)), 0) AS cur_value,
               COALESCE(SUM(GREATEST(p.prv_authorized - p.prv_captured, 0)), 0) AS prv_value
        FROM per_order p
    )
    SELECT ROUND(c.prv_value, 2) AS previous_value,
           ROUND(100 * (c.cur_value - c.prv_value)
                 / NULLIF(ABS(c.prv_value), 0), 2) AS divergence
    FROM computed c
    $$
),
(
    '019fffa3-ddd4-7b0e-8ffe-8a2b3c4d100e',
    '01a066fe-1722-7467-82b1-0cc282753e93',
    'manual_payment_amount',
    $$
    WITH txn_totals AS (
        SELECT COALESCE(SUM(amount) FILTER (WHERE is_current AND is_payment AND is_manual), 0) AS cur_value,
               COALESCE(SUM(amount) FILTER (WHERE is_prior   AND is_payment AND is_manual), 0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(t.processed_at, t.created_at)::date
                    BETWEEN :priorStartDate::date AND :priorEndDate::date)                      AS is_prior,
                   COALESCE(t.amount, 0) AS amount,
                   t.manual_payment_gateway AS is_manual,
                   (UPPER(t.kind) IN ('SALE', 'CAPTURE')
                AND UPPER(t.status) = 'SUCCESS') AS is_payment
            FROM public.fact_order_transactions t
            JOIN public.fact_order_headers o ON o.id = t.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND t.test = FALSE
        ) x
        WHERE x.is_current OR x.is_prior
    )
    SELECT ROUND(tot.prv_value, 2) AS previous_value,
           ROUND(100 * (tot.cur_value - tot.prv_value)
                 / NULLIF(ABS(tot.prv_value), 0), 2) AS divergence
    FROM txn_totals tot
    $$
),
(
    '019fffa3-ddd4-7b0f-8fff-8a2b3c4d100f',
    '01a066fe-1722-7917-8925-07154749e843',
    'cash_rounding_adjustment',
    $$
    WITH txn_totals AS (
        SELECT COALESCE(SUM(rounding) FILTER (WHERE is_current), 0) AS cur_value,
               COALESCE(SUM(rounding) FILTER (WHERE is_prior),   0) AS prv_value
        FROM (
            SELECT ((:currentStartDate::date IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL
                     OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(t.processed_at, t.created_at)::date
                    BETWEEN :priorStartDate::date AND :priorEndDate::date)                      AS is_prior,
                   COALESCE(t.amount_rounding, 0) AS rounding
            FROM public.fact_order_transactions t
            JOIN public.fact_order_headers o ON o.id = t.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              AND t.test = FALSE
        ) x
        WHERE x.is_current OR x.is_prior
    )
    SELECT ROUND(tot.prv_value, 2) AS previous_value,
           ROUND(100 * (tot.cur_value - tot.prv_value)
                 / NULLIF(ABS(tot.prv_value), 0), 2) AS divergence
    FROM txn_totals tot
    $$
);
