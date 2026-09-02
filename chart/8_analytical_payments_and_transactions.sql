INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fffa3-ddd3-7369-b2f8-35100851f1f5',
    'Payment Overview KPIs',
    'Payments & Transactions/Payment Overview/KPI/Payment Overview KPIs',
    '
    WITH scoped_txn AS (
        SELECT * FROM (
            SELECT ((:currentStartDate::date IS NULL OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(t.processed_at, t.created_at)::date BETWEEN :priorStartDate::date AND :priorEndDate::date)          AS is_prior,
                   COALESCE(t.amount, 0) AS amount,
                   (UPPER(t.kind) IN (''SALE'', ''CAPTURE'')
                AND UPPER(t.status) = ''SUCCESS'') AS is_payment,
                   (UPPER(t.kind) = ''REFUND''
                AND UPPER(t.status) = ''SUCCESS'') AS is_refund,
                   INITCAP(REPLACE(COALESCE(t.gateway, ''Unknown''),
                                   CHR(95), CHR(32))) AS gateway
            FROM public.fact_order_transactions t
            JOIN public.fact_order_headers o ON o.id = t.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              
              AND t.test = FALSE
        ) x
        WHERE x.is_current OR x.is_prior
    ),
    txn_totals AS (
        SELECT COALESCE(SUM(amount) FILTER (WHERE is_current AND is_payment), 0) AS cur_payments,
               COALESCE(SUM(amount) FILTER (WHERE is_prior   AND is_payment), 0) AS prv_payments,
               COALESCE(SUM(amount) FILTER (WHERE is_current AND is_refund),  0) AS cur_refunds,
               COALESCE(SUM(amount) FILTER (WHERE is_prior   AND is_refund),  0) AS prv_refunds,
               COUNT(*) FILTER (WHERE is_current) AS cur_count,
               COUNT(*) FILTER (WHERE is_prior)   AS prv_count
        FROM scoped_txn
    ),
    top_gateway AS (
        SELECT gateway
        FROM scoped_txn
        WHERE is_current AND is_payment
        GROUP BY gateway
        ORDER BY SUM(amount) DESC NULLS LAST, gateway ASC
        LIMIT 1
    ),
    scoped_tender AS (
        SELECT INITCAP(REPLACE(COALESCE(tt.payment_method, ''Unattributed''),
                               CHR(95), CHR(32))) AS method,
               COALESCE(tt.amount, 0) AS amount
        FROM public.dim_tender_transactions tt
        JOIN public.fact_order_headers o ON o.id = tt.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND tt.test = FALSE
          AND (:currentStartDate::date IS NULL OR tt.processed_at::date >= :currentStartDate::date)
          AND (:currentEndDate::date   IS NULL OR tt.processed_at::date <= :currentEndDate::date)
    ),
    top_method AS (
        SELECT method
        FROM scoped_tender
        GROUP BY method
        ORDER BY SUM(amount) DESC NULLS LAST, method ASC
        LIMIT 1
    ),
    computed AS (
        SELECT tot.cur_payments, tot.prv_payments,
               tot.cur_payments - tot.cur_refunds AS cur_net,
               tot.prv_payments - tot.prv_refunds AS prv_net,
               tot.cur_count, tot.prv_count
        FROM txn_totals tot
    )
    SELECT ROUND(c.cur_payments, 2) AS total_payment_amount,
           ROUND(100 * (c.cur_payments - c.prv_payments)
                 / NULLIF(ABS(c.prv_payments), 0), 2) AS total_payment_amount_divergence,
           ROUND(c.cur_net, 2) AS net_payment_received,
           ROUND(100 * (c.cur_net - c.prv_net)
                 / NULLIF(ABS(c.prv_net), 0), 2) AS net_payment_received_divergence,
           c.cur_count AS transaction_count,
           ROUND(100.0 * (c.cur_count - c.prv_count)
                 / NULLIF(ABS(c.prv_count), 0), 2) AS transaction_count_divergence,
           COALESCE((SELECT method FROM top_method), ''No data'') AS top_payment_method,
           COALESCE((SELECT gateway FROM top_gateway), ''No data'') AS top_gateway
    FROM computed c
    ',
    NULL,
    'KPI',
    60,
    'Payment overview KPIs evaluating total payment amount, net payment received, transaction count, top payment method, and top gateway vs prior period.',
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
    '019fffa3-ddd3-72e3-a14e-782dfd330b5b',
    'Payment Amount Trend',
    'Payments & Transactions/Payment Overview/PLOT/Payment Amount Trend',
    $$
    WITH
    date_params AS (
        SELECT
            g,
            CASE WHEN g = 'DAY'   THEN date_trunc('day',   :currentStartDate::date)
                 WHEN g = 'WEEK'  THEN date_trunc('week',  :currentStartDate::date)
                 WHEN g = 'MONTH' THEN date_trunc('month', :currentStartDate::date)
                 WHEN g = 'YEAR'  THEN date_trunc('year',  :currentStartDate::date)
            END AS start_bucket,
            CASE WHEN g = 'DAY'   THEN date_trunc('day',   :currentEndDate::date)
                 WHEN g = 'WEEK'  THEN date_trunc('week',  :currentEndDate::date)
                 WHEN g = 'MONTH' THEN date_trunc('month', :currentEndDate::date)
                 WHEN g = 'YEAR'  THEN date_trunc('year',  :currentEndDate::date)
            END AS end_bucket,
            CASE WHEN g = 'DAY'   THEN interval '1 day'
                 WHEN g = 'WEEK'  THEN interval '1 week'
                 WHEN g = 'MONTH' THEN interval '1 month'
                 WHEN g = 'YEAR'  THEN interval '1 year'
            END AS step
        FROM (
            SELECT COALESCE(
                NULLIF(:granularity, ''),
                CASE WHEN (:currentEndDate::date - :currentStartDate::date) > 730 THEN 'YEAR'
                     WHEN (:currentEndDate::date - :currentStartDate::date) > 180 THEN 'MONTH'
                     WHEN (:currentEndDate::date - :currentStartDate::date) > 31  THEN 'WEEK'
                     ELSE 'DAY'
                END
            ) AS g
        ) sub
    ),
    date_filler AS (
        SELECT generate_series(dp.start_bucket, dp.end_bucket, dp.step) AS bucket
        FROM date_params dp
    ),
    scoped_txn AS (
        SELECT date_trunc(LOWER(dp.g), COALESCE(t.processed_at, t.created_at)) AS bucket,
               COALESCE(t.amount, 0) AS amount,
               (UPPER(t.kind) IN ('SALE', 'CAPTURE')
            AND UPPER(t.status) = 'SUCCESS') AS is_payment,
               (UPPER(t.kind) = 'REFUND'
            AND UPPER(t.status) = 'SUCCESS') AS is_refund
        FROM public.fact_order_transactions t
        JOIN public.fact_order_headers o ON o.id = t.order_id
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND t.test = FALSE
          AND COALESCE(t.processed_at, t.created_at) >= dp.start_bucket
          AND COALESCE(t.processed_at, t.created_at) <= :currentEndDate::date
    ),
    daily AS (
        SELECT s.bucket,
               COALESCE(SUM(s.amount) FILTER (WHERE s.is_payment), 0) AS payments,
               COALESCE(SUM(s.amount) FILTER (WHERE s.is_refund),  0) AS refunds
        FROM scoped_txn s
        GROUP BY s.bucket
    )
    SELECT to_char(df.bucket,
               CASE WHEN dp.g = 'DAY'   THEN 'Mon DD, YYYY'
                    WHEN dp.g = 'WEEK'  THEN 'Mon DD, YYYY'
                    WHEN dp.g = 'MONTH' THEN 'Mon YYYY'
                    WHEN dp.g = 'YEAR'  THEN 'YYYY'
               END
           ) AS period,
           df.bucket,
           ROUND(COALESCE(d.payments, 0), 2) AS payments,
           ROUND(COALESCE(d.refunds, 0), 2) AS refunds,
           ROUND(COALESCE(d.payments, 0) - COALESCE(d.refunds, 0), 2) AS net_payments
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily d ON d.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Gross payments, refunds, and net payment trend grouped by dynamic date granularity.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "granularity":    { "source": "REQUEST_FILTER", "filterKey": "granularity" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fffa3-ddd3-7b3c-9f95-309dbdb57dfe',
    'Payment Method Mix',
    'Payments & Transactions/Payment Overview/PLOT/Payment Method Mix',
    '
    SELECT INITCAP(REPLACE(COALESCE(tt.payment_method, ''Unattributed''),
                           CHR(95), CHR(32))) AS payment_method,
           ROUND(SUM(COALESCE(tt.amount, 0)), 2) AS "Payment Amount"
    FROM public.dim_tender_transactions tt
    JOIN public.fact_order_headers o ON o.id = tt.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      
      AND tt.test = FALSE
      AND (:currentStartDate IS NULL OR tt.processed_at::date >= :currentStartDate::date)
      AND (:currentEndDate IS NULL OR tt.processed_at::date <= :currentEndDate::date)
    GROUP BY 1
    ORDER BY SUM(COALESCE(tt.amount, 0)) DESC, 1 ASC
    LIMIT :limit OFFSET :offset
    ',
    NULL,
    'PLOT',
    60,
    'Proportional payment volume mix per payment method.',
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
    '019fffa3-ddd3-752f-9af4-6c1f2cb046f1',
    'Gateway Performance',
    'Payments & Transactions/Payment Overview/PLOT/Gateway Performance',
    '' ||
    '
   WITH scoped_txn AS (
        SELECT INITCAP(REPLACE(COALESCE(t.gateway, ''Unknown''),
                               CHR(95), CHR(32))) AS gateway,
               COALESCE(t.amount, 0) AS amount,
               COALESCE(t.transaction_fee, 0) AS fee
        FROM public.fact_order_transactions t
        JOIN public.fact_order_headers o ON o.id = t.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND t.test = FALSE
          AND UPPER(t.kind) IN (''SALE'', ''CAPTURE'')
          AND UPPER(t.status) = ''SUCCESS''
          AND (:currentStartDate IS NULL OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    )
    SELECT s.gateway AS gateway,
           ROUND(SUM(s.amount), 2) AS amount_processed,
           ROUND(100 * SUM(s.fee) / NULLIF(SUM(s.amount), 0), 2) AS fee_rate
    FROM scoped_txn s
    GROUP BY s.gateway
    ORDER BY SUM(s.amount) DESC, s.gateway ASC
    LIMIT :limit OFFSET :offset
    ',
    NULL,
    'PLOT',
    60,
    'Gateway performance comparison showing total amount processed and fee rate %.',
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
    '019fffa3-ddd3-7057-8f69-3814f3324a8e',
    'Transaction Detail Report',
    'Payments & Transactions/Payment Overview/TABLE/Transaction Detail Report',
    '
    WITH scoped_txn AS (
        SELECT t.id as transaction_gid,
               o.id as order_gid,
               COALESCE(t.processed_at, t.created_at) AS txn_at,
               UPPER(t.kind) AS kind,
               UPPER(t.status) AS status,
               INITCAP(REPLACE(COALESCE(t.gateway, ''Unknown''),
                               CHR(95), CHR(32))) AS gateway,
               COALESCE(t.amount, 0) AS amount,
               COALESCE(t.transaction_fee, 0) AS fee,
               t.location_id
        FROM public.fact_order_transactions t
        JOIN public.fact_order_headers o ON o.id = t.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND t.test = FALSE
          AND (:currentStartDate IS NULL OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    )
    SELECT COALESCE(s.transaction_gid, ''Unknown'') AS transaction_id,
           COALESCE(s.order_gid, ''Unknown'') AS order_id,
           s.txn_at::date::text AS transaction_date,
           COALESCE(s.kind, ''UNKNOWN'') AS kind,
           COALESCE(s.status, ''UNKNOWN'') AS status,
           s.gateway AS gateway,
           ROUND(s.amount, 2) AS amount,
           ROUND(s.fee, 2) AS fee,
           COALESCE(loc.name, ''Unknown'') AS location,
           COUNT(*) OVER() AS total_records
    FROM scoped_txn s
    LEFT JOIN public.dim_inventory_locations loc ON loc.id = s.location_id
    ORDER BY s.txn_at DESC, s.transaction_gid
    LIMIT :limit OFFSET :offset
    ',
    NULL,
    'TABLE',
    60,
    'Comprehensive transaction detail log table listing transaction ID, order ID, date, kind, status, gateway, amount, fee, and location.',
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
    '019fffa3-ddd3-74f4-8b88-84aa1bf30d42',
    'Payment Method Report',
    'Payments & Transactions/Payment Overview/TABLE/Payment Method Report',
    '
    WITH scoped_orders AS (
        SELECT o.id
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
    ),
    scoped_tender AS (
        SELECT tt.order_id,
               INITCAP(REPLACE(COALESCE(tt.payment_method, ''Unattributed''),
                               CHR(95), CHR(32))) AS method,
               COALESCE(tt.amount, 0) AS amount
        FROM public.dim_tender_transactions tt
        JOIN scoped_orders so ON so.id = tt.order_id
        WHERE tt.test = FALSE
          AND (:currentStartDate IS NULL OR tt.processed_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR tt.processed_at::date <= :currentEndDate::date)
    ),
    method_totals AS (
        SELECT s.method,
               COUNT(*) AS transaction_count,
               SUM(s.amount) AS amount
        FROM scoped_tender s
        GROUP BY s.method
    ),
    order_method AS (
        SELECT s.order_id, s.method, SUM(s.amount) AS amount
        FROM scoped_tender s
        GROUP BY s.order_id, s.method
    ),
    primary_method AS (
        SELECT DISTINCT ON (om.order_id) om.order_id, om.method
        FROM order_method om
        ORDER BY om.order_id, om.amount DESC, om.method ASC
    ),
    order_txn AS (
        SELECT t.order_id,
               COALESCE(SUM(COALESCE(t.amount, 0)) FILTER (
                   WHERE UPPER(t.kind) = ''REFUND''
                     AND UPPER(t.status) = ''SUCCESS''), 0) AS refunded,
               COUNT(*) FILTER (WHERE UPPER(t.status) IN (''FAILURE'', ''ERROR'')) AS failures
        FROM public.fact_order_transactions t
        JOIN scoped_orders so ON so.id = t.order_id
        WHERE t.test = FALSE
        GROUP BY t.order_id
    ),
    method_txn AS (
        SELECT pm.method,
               COALESCE(SUM(ot.refunded), 0) AS refund_amount,
               COALESCE(SUM(ot.failures), 0) AS failure_count
        FROM primary_method pm
        LEFT JOIN order_txn ot ON ot.order_id = pm.order_id
        GROUP BY pm.method
    )
    SELECT mt.method AS payment_method,
           mt.transaction_count AS transaction_count,
           ROUND(mt.amount, 2) AS amount,
           ROUND(100 * mt.amount / NULLIF(SUM(mt.amount) OVER (), 0), 2) AS share,
           ROUND(COALESCE(mx.refund_amount, 0), 2) AS refund_amount,
           COALESCE(mx.failure_count, 0) AS failure_count,
           COUNT(*) OVER() AS total_records
    FROM method_totals mt
    LEFT JOIN method_txn mx ON mx.method = mt.method
    ORDER BY mt.amount DESC, mt.method ASC
    LIMIT :limit OFFSET :offset
    ',
    NULL,
    'TABLE',
    60,
    'Payment method performance table showing transaction count, total amount, revenue share %, refund amount, and failed transactions.',
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

--changeset saugat:RW-41-2
--comment seed Payment Costs & Gateway Performance tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fffa3-ddd3-7a0f-9e52-a5fff7b2b20f',
    'Payment Cost KPIs',
    'Payments & Transactions/Payment Costs & Gateway Performance/KPI/Payment Cost KPIs',
    '
     WITH scoped_txn AS (
        SELECT * FROM (
            SELECT ((:currentStartDate::date IS NULL OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(t.processed_at, t.created_at)::date BETWEEN :priorStartDate::date AND :priorEndDate::date)          AS is_prior,
                   COALESCE(t.amount, 0) AS amount,
                   COALESCE(t.transaction_fee, 0) AS fee
            FROM public.fact_order_transactions t
            JOIN public.fact_order_headers o ON o.id = t.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              
              AND t.test = FALSE
              AND UPPER(t.kind) IN (''SALE'', ''CAPTURE'')
              AND UPPER(t.status) = ''SUCCESS''
        ) x
        WHERE x.is_current OR x.is_prior
    ),
    totals AS (
        SELECT COALESCE(SUM(fee)    FILTER (WHERE is_current), 0) AS cur_fees,
               COALESCE(SUM(fee)    FILTER (WHERE is_prior),   0) AS prv_fees,
               COALESCE(SUM(amount) FILTER (WHERE is_current), 0) AS cur_amount,
               COALESCE(SUM(amount) FILTER (WHERE is_prior),   0) AS prv_amount
        FROM scoped_txn
    ),
    computed AS (
        SELECT tot.cur_fees, tot.prv_fees,
               ROUND(100 * tot.cur_fees / NULLIF(tot.cur_amount, 0), 2) AS cur_rate,
               ROUND(100 * tot.prv_fees / NULLIF(tot.prv_amount, 0), 2) AS prv_rate
        FROM totals tot
    )
    SELECT ROUND(c.cur_fees, 2) AS transaction_fees,
           ROUND(100 * (c.cur_fees - c.prv_fees)
                 / NULLIF(ABS(c.prv_fees), 0), 2) AS transaction_fees_divergence,
           COALESCE(c.cur_rate, 0) AS fee_rate,
           ROUND(100 * (c.cur_rate - c.prv_rate)
                 / NULLIF(ABS(c.prv_rate), 0), 2) AS fee_rate_divergence
    FROM computed c
    ',
    NULL,
    'KPI',
    60,
    'Payment cost KPIs evaluating transaction fees and fee rate % vs prior period.',
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
    '019fffa3-ddd3-7597-a973-629f58d62294',
    'Transaction Fee Trend',
    'Payments & Transactions/Payment Costs & Gateway Performance/PLOT/Transaction Fee Trend',
    $$
    WITH
    date_params AS (
        SELECT
            g,
            CASE WHEN g = 'DAY'   THEN date_trunc('day',   :currentStartDate::date)
                 WHEN g = 'WEEK'  THEN date_trunc('week',  :currentStartDate::date)
                 WHEN g = 'MONTH' THEN date_trunc('month', :currentStartDate::date)
                 WHEN g = 'YEAR'  THEN date_trunc('year',  :currentStartDate::date)
            END AS start_bucket,
            CASE WHEN g = 'DAY'   THEN date_trunc('day',   :currentEndDate::date)
                 WHEN g = 'WEEK'  THEN date_trunc('week',  :currentEndDate::date)
                 WHEN g = 'MONTH' THEN date_trunc('month', :currentEndDate::date)
                 WHEN g = 'YEAR'  THEN date_trunc('year',  :currentEndDate::date)
            END AS end_bucket,
            CASE WHEN g = 'DAY'   THEN interval '1 day'
                 WHEN g = 'WEEK'  THEN interval '1 week'
                 WHEN g = 'MONTH' THEN interval '1 month'
                 WHEN g = 'YEAR'  THEN interval '1 year'
            END AS step
        FROM (
            SELECT COALESCE(
                NULLIF(:granularity, ''),
                CASE WHEN (:currentEndDate::date - :currentStartDate::date) > 730 THEN 'YEAR'
                     WHEN (:currentEndDate::date - :currentStartDate::date) > 180 THEN 'MONTH'
                     WHEN (:currentEndDate::date - :currentStartDate::date) > 31  THEN 'WEEK'
                     ELSE 'DAY'
                END
            ) AS g
        ) sub
    ),
    date_filler AS (
        SELECT generate_series(dp.start_bucket, dp.end_bucket, dp.step) AS bucket
        FROM date_params dp
    ),
    scoped_txn AS (
        SELECT date_trunc(LOWER(dp.g), COALESCE(t.processed_at, t.created_at)) AS bucket,
               COALESCE(t.amount, 0) AS amount,
               COALESCE(t.transaction_fee, 0) AS fee
        FROM public.fact_order_transactions t
        JOIN public.fact_order_headers o ON o.id = t.order_id
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND t.test = FALSE
          AND UPPER(t.kind) IN ('SALE', 'CAPTURE')
          AND UPPER(t.status) = 'SUCCESS'
          AND COALESCE(t.processed_at, t.created_at) >= dp.start_bucket
          AND COALESCE(t.processed_at, t.created_at) <= :currentEndDate::date
    ),
    daily AS (
        SELECT s.bucket,
               SUM(s.fee) AS fees,
               SUM(s.amount) AS amount
        FROM scoped_txn s
        GROUP BY s.bucket
    )
    SELECT to_char(df.bucket,
               CASE WHEN dp.g = 'DAY'   THEN 'Mon DD, YYYY'
                    WHEN dp.g = 'WEEK'  THEN 'Mon DD, YYYY'
                    WHEN dp.g = 'MONTH' THEN 'Mon YYYY'
                    WHEN dp.g = 'YEAR'  THEN 'YYYY'
               END
           ) AS period,
           df.bucket,
           ROUND(COALESCE(d.fees, 0), 2) AS transaction_fees,
           ROUND(100 * d.fees / NULLIF(d.amount, 0), 2) AS fee_rate
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily d ON d.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Transaction fees and fee rate % trend grouped by dynamic date granularity.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "granularity":    { "source": "REQUEST_FILTER", "filterKey": "granularity" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fffa3-ddd3-7325-ae53-eba74722bea6',
    'Gateway Fee Report',
    'Payments & Transactions/Payment Costs & Gateway Performance/TABLE/Gateway Fee Report',
    '
    WITH scoped_txn AS (
        SELECT INITCAP(REPLACE(COALESCE(t.gateway, ''Unknown''),
                               CHR(95), CHR(32))) AS gateway,
               COALESCE(t.amount, 0) AS amount,
               COALESCE(t.transaction_fee, 0) AS fee,
               (UPPER(t.kind) IN (''SALE'', ''CAPTURE'')
            AND UPPER(t.status) = ''SUCCESS'') AS is_payment,
               (UPPER(t.status) IN (''FAILURE'', ''ERROR'')) AS is_failed
        FROM public.fact_order_transactions t
        JOIN public.fact_order_headers o ON o.id = t.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND t.test = FALSE
          AND (:currentStartDate IS NULL OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    ),
    gateway_totals AS (
        SELECT s.gateway,
               COALESCE(SUM(s.amount) FILTER (WHERE s.is_payment), 0) AS amount_processed,
               COUNT(*) FILTER (WHERE s.is_payment) AS transaction_count,
               COALESCE(SUM(s.fee) FILTER (WHERE s.is_payment), 0) AS total_fees,
               COALESCE(SUM(s.amount) FILTER (WHERE s.is_failed), 0) AS failed_amount
        FROM scoped_txn s
        GROUP BY s.gateway
    )
    SELECT gt.gateway AS gateway,
           ROUND(gt.amount_processed, 2) AS amount_processed,
           gt.transaction_count AS transaction_count,
           ROUND(gt.total_fees, 2) AS total_fees,
           ROUND(100 * gt.total_fees / NULLIF(gt.amount_processed, 0), 2) AS fee_rate,
           ROUND(gt.failed_amount, 2) AS failed_amount,
           COUNT(*) OVER() AS total_records
    FROM gateway_totals gt
    ORDER BY gt.amount_processed DESC, gt.gateway ASC
    LIMIT :limit OFFSET :offset
    ',
    NULL,
    'TABLE',
    60,
    'Gateway fee analysis report table listing amount processed, transaction count, total fees, fee rate %, and failed transaction volume.',
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

--changeset saugat:RW-41-3
--comment seed Payment Health & Reliability tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fffa3-ddd3-7684-970a-205ebbac5a02',
    'Payment Health KPIs',
    'Payments & Transactions/Payment Health & Reliability/KPI/Payment Health KPIs',
    '
    WITH scoped_txn AS (
        SELECT * FROM (
            SELECT ((:currentStartDate::date IS NULL OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(t.processed_at, t.created_at)::date BETWEEN :priorStartDate::date AND :priorEndDate::date)          AS is_prior,
                   COALESCE(t.amount, 0) AS amount,
                   (UPPER(t.status) IN (''FAILURE'', ''ERROR''))              AS is_failed,
                   (UPPER(t.status) IN (''PENDING'', ''AWAITING_RESPONSE''))  AS is_pending
            FROM public.fact_order_transactions t
            JOIN public.fact_order_headers o ON o.id = t.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              
              AND t.test = FALSE
        ) x
        WHERE x.is_current OR x.is_prior
    ),
    totals AS (
        SELECT COUNT(*) FILTER (WHERE is_current AND is_failed)  AS cur_failed_count,
               COUNT(*) FILTER (WHERE is_prior   AND is_failed)  AS prv_failed_count,
               COUNT(*) FILTER (WHERE is_current AND is_pending) AS cur_pending_count,
               COUNT(*) FILTER (WHERE is_prior   AND is_pending) AS prv_pending_count,
               COALESCE(SUM(amount) FILTER (WHERE is_current AND is_failed),  0) AS cur_failed_amount,
               COALESCE(SUM(amount) FILTER (WHERE is_prior   AND is_failed),  0) AS prv_failed_amount,
               COALESCE(SUM(amount) FILTER (WHERE is_current AND is_pending), 0) AS cur_pending_amount,
               COALESCE(SUM(amount) FILTER (WHERE is_prior   AND is_pending), 0) AS prv_pending_amount
        FROM scoped_txn
    )
    SELECT t.cur_failed_count AS failed_transactions,
           ROUND(100.0 * (t.cur_failed_count - t.prv_failed_count)
                 / NULLIF(ABS(t.prv_failed_count), 0), 2) AS failed_transactions_divergence,
           ROUND(t.cur_failed_amount, 2) AS failed_amount,
           ROUND(100 * (t.cur_failed_amount - t.prv_failed_amount)
                 / NULLIF(ABS(t.prv_failed_amount), 0), 2) AS failed_amount_divergence,
           t.cur_pending_count AS pending_transactions,
           ROUND(100.0 * (t.cur_pending_count - t.prv_pending_count)
                 / NULLIF(ABS(t.prv_pending_count), 0), 2) AS pending_transactions_divergence,
           ROUND(t.cur_pending_amount, 2) AS pending_amount,
           ROUND(100 * (t.cur_pending_amount - t.prv_pending_amount)
                 / NULLIF(ABS(t.prv_pending_amount), 0), 2) AS pending_amount_divergence
    FROM totals t
    ',
    NULL,
    'KPI',
    60,
    'Payment health KPIs evaluating failed transaction count, failed dollar amount, pending transaction count, and pending dollar amount vs prior period.',
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
    '019fffa3-ddd3-795f-a999-4897d4e273db',
    'Transaction Status Mix',
    'Payments & Transactions/Payment Health & Reliability/PLOT/Transaction Status Mix',
    '
    WITH classified AS (
        SELECT CASE WHEN UPPER(t.status) IN (''FAILURE'', ''ERROR'')             THEN ''Failed''
                    WHEN UPPER(t.status) IN (''PENDING'', ''AWAITING_RESPONSE'') THEN ''Pending''
                    WHEN UPPER(t.status) = ''SUCCESS''                           THEN ''Success''
                    ELSE ''Other'' END AS status
        FROM public.fact_order_transactions t
        JOIN public.fact_order_headers o ON o.id = t.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND t.test = FALSE
          AND (:currentStartDate IS NULL OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    ),
    bands(ord, status) AS (
        VALUES (1, ''Success''), (2, ''Failed''), (3, ''Pending''), (4, ''Other'')
    )
    SELECT b.status AS status,
           COUNT(c.status) AS "Transaction Count"
    FROM bands b
    LEFT JOIN classified c ON c.status = b.status
    GROUP BY b.ord, b.status
    ORDER BY b.ord
    ',
    NULL,
    'PLOT',
    60,
    'Transaction status distribution breakdown (Success, Failed, Pending, Other).',
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
    '019fffa3-ddd3-73c3-a7d0-1e7c6562c512',
    'Failed / Pending Payment Trend',
    'Payments & Transactions/Payment Health & Reliability/PLOT/Failed / Pending Payment Trend',
    $$
    WITH
    /*date_granularity_cte*/
    scoped_txn AS (
        SELECT date_trunc(LOWER(dp.g), COALESCE(t.processed_at, t.created_at)) AS bucket,
               (UPPER(t.status) IN ('FAILURE', 'ERROR'))             AS is_failed,
               (UPPER(t.status) IN ('PENDING', 'AWAITING_RESPONSE')) AS is_pending
        FROM public.fact_order_transactions t
        JOIN public.fact_order_headers o ON o.id = t.order_id
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND t.test = FALSE
          AND COALESCE(t.processed_at, t.created_at) >= dp.start_bucket
          AND COALESCE(t.processed_at, t.created_at) <= :currentEndDate::date
    ),
    daily AS (
        SELECT s.bucket,
               COUNT(*) FILTER (WHERE s.is_failed)  AS failed_count,
               COUNT(*) FILTER (WHERE s.is_pending) AS pending_count
        FROM scoped_txn s
        GROUP BY s.bucket
    )
    SELECT to_char(df.bucket,
               CASE WHEN dp.g = 'DAY'   THEN 'Mon DD, YYYY'
                    WHEN dp.g = 'WEEK'  THEN 'Mon DD, YYYY'
                    WHEN dp.g = 'MONTH' THEN 'Mon YYYY'
                    WHEN dp.g = 'YEAR'  THEN 'YYYY'
               END
           ) AS period,
           df.bucket,
           COALESCE(d.failed_count, 0) AS failed_count,
           COALESCE(d.pending_count, 0) AS pending_count
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily d ON d.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Volume trend of failed and pending transactions grouped by dynamic date granularity.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "granularity":    { "source": "REQUEST_FILTER", "filterKey": "granularity" }
      },
      "excludeExtraParams": true,
      "conditionalSegments": [
        { "provider": "DATE_GRANULARITY_CTE", "condition": "hasFilter:startDate", "placeholder": "/*date_granularity_cte*/",
          "args": { "startDateParam": "currentStartDate", "endDateParam": "currentEndDate", "granularityParam": "granularity" } }
      ]
    }'
),
(
    '019fffa3-ddd3-7be5-89dc-101e463d6bb3',
    'Failed / Pending Transactions Report',
    'Payments & Transactions/Payment Health & Reliability/TABLE/Failed / Pending Transactions Report',
    '
    WITH scoped_txn AS (
        SELECT t.id as transaction_gid,
               o.id as order_gid,
               o.customer_id,
               COALESCE(t.processed_at, t.created_at) AS txn_at,
               UPPER(t.status) AS status,
               INITCAP(REPLACE(COALESCE(t.gateway, ''Unknown''),
                               CHR(95), CHR(32))) AS gateway,
               COALESCE(t.amount, 0) AS amount
        FROM public.fact_order_transactions t
        JOIN public.fact_order_headers o ON o.id = t.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND t.test = FALSE
          AND UPPER(t.status) IN (''FAILURE'', ''ERROR'', ''PENDING'', ''AWAITING_RESPONSE'')
          AND (:currentStartDate IS NULL OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    )
    SELECT COALESCE(s.transaction_gid, ''Unknown'') AS transaction_id,
           COALESCE(s.order_gid, ''Unknown'') AS order_id,
           s.gateway AS gateway,
           ROUND(s.amount, 2) AS amount,
           s.status AS status,
           s.txn_at::date::text AS processed_date,
           CASE WHEN LENGTH(CONCAT_WS(CHR(32), cu.first_name, cu.last_name)) > 0
                THEN CONCAT_WS(CHR(32), cu.first_name, cu.last_name)
                ELSE COALESCE(cu.email, ''Guest'') END AS customer,
           COUNT(*) OVER() AS total_records
    FROM scoped_txn s
    LEFT JOIN public.dim_customers cu ON cu.id = s.customer_id
    ORDER BY s.txn_at DESC, s.transaction_gid
    LIMIT :limit OFFSET :offset
    ',
    NULL,
    'TABLE',
    60,
    'Audit table listing failed and pending payment transactions with gateway, amount, status, date, and customer details.',
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

--changeset saugat:RW-41-4
--comment seed Reconciliation & Refund Payments tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fffa3-ddd3-72af-89f6-f1ea24b39173',
    'Refund & Reconciliation KPIs',
    'Payments & Transactions/Reconciliation & Refund Payments/KPI/Refund & Reconciliation KPIs',
    '
    WITH scoped_txn AS (
        SELECT * FROM (
            SELECT ((:currentStartDate::date IS NULL OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(t.processed_at, t.created_at)::date BETWEEN :priorStartDate::date AND :priorEndDate::date)          AS is_prior,
                   COALESCE(t.amount, 0) AS amount,
                   COALESCE(t.maximum_refundable_amount, 0) AS max_refundable,
                   (UPPER(t.kind) = ''REFUND''
                AND UPPER(t.status) = ''SUCCESS'') AS is_refund,
                   (UPPER(t.kind) IN (''SALE'', ''CAPTURE'')
                AND UPPER(t.status) = ''SUCCESS'') AS is_payment
            FROM public.fact_order_transactions t
            JOIN public.fact_order_headers o ON o.id = t.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              
              AND t.test = FALSE
        ) x
        WHERE x.is_current OR x.is_prior
    ),
    totals AS (
        SELECT COUNT(*) FILTER (WHERE is_current AND is_refund) AS cur_refund_count,
               COUNT(*) FILTER (WHERE is_prior   AND is_refund) AS prv_refund_count,
               COALESCE(SUM(amount) FILTER (WHERE is_current AND is_refund), 0) AS cur_refund_amount,
               COALESCE(SUM(amount) FILTER (WHERE is_prior   AND is_refund), 0) AS prv_refund_amount,
               COALESCE(SUM(max_refundable) FILTER (WHERE is_current AND is_payment), 0) AS cur_max_refundable,
               COALESCE(SUM(max_refundable) FILTER (WHERE is_prior   AND is_payment), 0) AS prv_max_refundable
        FROM scoped_txn
    )
    SELECT t.cur_refund_count AS refund_transactions,
           ROUND(100.0 * (t.cur_refund_count - t.prv_refund_count)
                 / NULLIF(ABS(t.prv_refund_count), 0), 2) AS refund_transactions_divergence,
           ROUND(t.cur_refund_amount, 2) AS refund_amount,
           ROUND(100 * (t.cur_refund_amount - t.prv_refund_amount)
                 / NULLIF(ABS(t.prv_refund_amount), 0), 2) AS refund_amount_divergence,
           ROUND(t.cur_max_refundable, 2) AS maximum_refundable_amount,
           ROUND(100 * (t.cur_max_refundable - t.prv_max_refundable)
                 / NULLIF(ABS(t.prv_max_refundable), 0), 2) AS maximum_refundable_amount_divergence
    FROM totals t
    ',
    NULL,
    'KPI',
    60,
    'Refund & reconciliation KPIs evaluating refund transaction count, refund dollar amount, and maximum refundable amount vs prior period.',
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
    '019fffa3-ddd3-7db7-8dbd-baf76c474af1',
    'Sales vs Payments Reconciliation',
    'Payments & Transactions/Reconciliation & Refund Payments/PLOT/Sales vs Payments Reconciliation',
    $$
    WITH
    date_params AS (
        SELECT
            g,
            CASE WHEN g = 'DAY'   THEN date_trunc('day',   :currentStartDate::date)
                 WHEN g = 'WEEK'  THEN date_trunc('week',  :currentStartDate::date)
                 WHEN g = 'MONTH' THEN date_trunc('month', :currentStartDate::date)
                 WHEN g = 'YEAR'  THEN date_trunc('year',  :currentStartDate::date)
            END AS start_bucket,
            CASE WHEN g = 'DAY'   THEN date_trunc('day',   :currentEndDate::date)
                 WHEN g = 'WEEK'  THEN date_trunc('week',  :currentEndDate::date)
                 WHEN g = 'MONTH' THEN date_trunc('month', :currentEndDate::date)
                 WHEN g = 'YEAR'  THEN date_trunc('year',  :currentEndDate::date)
            END AS end_bucket,
            CASE WHEN g = 'DAY'   THEN interval '1 day'
                 WHEN g = 'WEEK'  THEN interval '1 week'
                 WHEN g = 'MONTH' THEN interval '1 month'
                 WHEN g = 'YEAR'  THEN interval '1 year'
            END AS step
        FROM (
            SELECT COALESCE(
                NULLIF(:granularity, ''),
                CASE WHEN (:currentEndDate::date - :currentStartDate::date) > 730 THEN 'YEAR'
                     WHEN (:currentEndDate::date - :currentStartDate::date) > 180 THEN 'MONTH'
                     WHEN (:currentEndDate::date - :currentStartDate::date) > 31  THEN 'WEEK'
                     ELSE 'DAY'
                END
            ) AS g
        ) sub
    ),
    date_filler AS (
        SELECT generate_series(dp.start_bucket, dp.end_bucket, dp.step) AS bucket
        FROM date_params dp
    ),
    filtered_orders AS (
        SELECT o.id,
               date_trunc(LOWER(dp.g), o.created_at) AS bucket,
               COALESCE(o.total_price, 0) AS order_total
        FROM public.fact_order_headers o
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND o.created_at >= dp.start_bucket
          AND o.created_at <= :currentEndDate::date
    ),
    daily_orders AS (
        SELECT f.bucket, SUM(f.order_total) AS order_total
        FROM filtered_orders f
        GROUP BY f.bucket
    ),
    daily_captured AS (
        SELECT f.bucket, SUM(COALESCE(t.amount, 0)) AS captured_payments
        FROM public.fact_order_transactions t
        JOIN filtered_orders f ON f.id = t.order_id
        WHERE t.test = FALSE
          AND UPPER(t.kind) IN ('SALE', 'CAPTURE')
          AND UPPER(t.status) = 'SUCCESS'
        GROUP BY f.bucket
    )
    SELECT to_char(df.bucket,
               CASE WHEN dp.g = 'DAY'   THEN 'Mon DD, YYYY'
                    WHEN dp.g = 'WEEK'  THEN 'Mon DD, YYYY'
                    WHEN dp.g = 'MONTH' THEN 'Mon YYYY'
                    WHEN dp.g = 'YEAR'  THEN 'YYYY'
               END
           ) AS period,
           df.bucket,
           ROUND(COALESCE(d.order_total, 0), 2) AS order_total,
           ROUND(COALESCE(p.captured_payments, 0), 2) AS captured_payments
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily_orders d ON d.bucket = df.bucket
    LEFT JOIN daily_captured p ON p.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Comparison trend of order total sales vs captured payment amounts grouped by dynamic date granularity.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "granularity":    { "source": "REQUEST_FILTER", "filterKey": "granularity" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fffa3-ddd3-726f-b9ab-c57314c5f5e1',
    'Refund Transaction Trend',
    'Payments & Transactions/Reconciliation & Refund Payments/PLOT/Refund Transaction Trend',
    $$
    WITH
    date_params AS (
        SELECT
            g,
            CASE WHEN g = 'DAY'   THEN date_trunc('day',   :currentStartDate::date)
                 WHEN g = 'WEEK'  THEN date_trunc('week',  :currentStartDate::date)
                 WHEN g = 'MONTH' THEN date_trunc('month', :currentStartDate::date)
                 WHEN g = 'YEAR'  THEN date_trunc('year',  :currentStartDate::date)
            END AS start_bucket,
            CASE WHEN g = 'DAY'   THEN date_trunc('day',   :currentEndDate::date)
                 WHEN g = 'WEEK'  THEN date_trunc('week',  :currentEndDate::date)
                 WHEN g = 'MONTH' THEN date_trunc('month', :currentEndDate::date)
                 WHEN g = 'YEAR'  THEN date_trunc('year',  :currentEndDate::date)
            END AS end_bucket,
            CASE WHEN g = 'DAY'   THEN interval '1 day'
                 WHEN g = 'WEEK'  THEN interval '1 week'
                 WHEN g = 'MONTH' THEN interval '1 month'
                 WHEN g = 'YEAR'  THEN interval '1 year'
            END AS step
        FROM (
            SELECT COALESCE(
                NULLIF(:granularity, ''),
                CASE WHEN (:currentEndDate::date - :currentStartDate::date) > 730 THEN 'YEAR'
                     WHEN (:currentEndDate::date - :currentStartDate::date) > 180 THEN 'MONTH'
                     WHEN (:currentEndDate::date - :currentStartDate::date) > 31  THEN 'WEEK'
                     ELSE 'DAY'
                END
            ) AS g
        ) sub
    ),
    date_filler AS (
        SELECT generate_series(dp.start_bucket, dp.end_bucket, dp.step) AS bucket
        FROM date_params dp
    ),
    scoped_refunds AS (
        SELECT date_trunc(LOWER(dp.g), COALESCE(t.processed_at, t.created_at)) AS bucket,
               COALESCE(t.amount, 0) AS amount
        FROM public.fact_order_transactions t
        JOIN public.fact_order_headers o ON o.id = t.order_id
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND t.test = FALSE
          AND UPPER(t.kind) = 'REFUND'
          AND UPPER(t.status) = 'SUCCESS'
          AND COALESCE(t.processed_at, t.created_at) >= dp.start_bucket
          AND COALESCE(t.processed_at, t.created_at) <= :currentEndDate::date
    ),
    daily AS (
        SELECT s.bucket,
               SUM(s.amount) AS refund_amount,
               COUNT(*) AS refund_count
        FROM scoped_refunds s
        GROUP BY s.bucket
    )
    SELECT to_char(df.bucket,
               CASE WHEN dp.g = 'DAY'   THEN 'Mon DD, YYYY'
                    WHEN dp.g = 'WEEK'  THEN 'Mon DD, YYYY'
                    WHEN dp.g = 'MONTH' THEN 'Mon YYYY'
                    WHEN dp.g = 'YEAR'  THEN 'YYYY'
               END
           ) AS period,
           df.bucket,
           ROUND(COALESCE(d.refund_amount, 0), 2) AS refund_amount,
           COALESCE(d.refund_count, 0) AS refund_count
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily d ON d.bucket = df.bucket
    ORDER BY df.bucket ASC
    $$,
    NULL,
    'PLOT',
    60,
    'Refund transaction dollar amount and count trend grouped by dynamic date granularity.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "granularity":    { "source": "REQUEST_FILTER", "filterKey": "granularity" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fffa3-ddd3-7cbb-9fbc-b0387524b1f4',
    'Order Payment Reconciliation Report',
    'Payments & Transactions/Reconciliation & Refund Payments/TABLE/Order Payment Reconciliation Report',
    '
    WITH filtered_orders AS (
        SELECT o.id,
               o.created_at,
               COALESCE(o.total_price, 0) AS order_total,
               COALESCE(o.net_payment, 0) AS net_payment
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    order_txn AS (
        SELECT t.order_id,
               SUM(COALESCE(t.amount, 0)) AS transaction_amount,
               COALESCE(SUM(COALESCE(t.amount, 0)) FILTER (
                   WHERE UPPER(t.kind) IN (''SALE'', ''CAPTURE'')
                     AND UPPER(t.status) = ''SUCCESS''), 0) AS captured_amount,
               COALESCE(SUM(COALESCE(t.amount, 0)) FILTER (
                   WHERE UPPER(t.kind) = ''REFUND''
                     AND UPPER(t.status) = ''SUCCESS''), 0) AS refunded_amount
        FROM public.fact_order_transactions t
        JOIN filtered_orders f ON f.id = t.order_id
        WHERE t.test = FALSE
        GROUP BY t.order_id
    ),
    reconciled AS (
        SELECT f.id,
               f.created_at,
               f.order_total,
               f.net_payment,
               COALESCE(ot.transaction_amount, 0) AS transaction_amount,
               COALESCE(ot.captured_amount, 0) AS captured_amount,
               COALESCE(ot.refunded_amount, 0) AS refunded_amount,
               COALESCE(ot.captured_amount, 0)
                 - COALESCE(ot.refunded_amount, 0)
                 - f.net_payment AS difference
        FROM filtered_orders f
        LEFT JOIN order_txn ot ON ot.order_id = f.id
    )
    SELECT COALESCE(r.id, ''Unknown'') AS order_id,
           ROUND(r.order_total, 2) AS order_total,
           ROUND(r.net_payment, 2) AS net_payment,
           ROUND(r.transaction_amount, 2) AS transaction_amount,
           ROUND(r.captured_amount, 2) AS captured_amount,
           ROUND(r.refunded_amount, 2) AS refunded_amount,
           ROUND(r.difference, 2) AS difference,
           COUNT(*) OVER() AS total_records
    FROM reconciled r
    ORDER BY ABS(r.difference) DESC, r.created_at DESC, r.id
    LIMIT :limit OFFSET :offset
    ',
    NULL,
    'TABLE',
    60,
    'Order reconciliation report table comparing order total, net payment, transaction amount, captured amount, refunded amount, and variance difference.',
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
    '019fffa3-ddd3-7bfd-8994-043808a9ede2',
    'Refund Transaction Report',
    'Payments & Transactions/Reconciliation & Refund Payments/TABLE/Refund Transaction Report',
    '
    WITH scoped_refunds AS (
        SELECT t.id as transaction_gid,
               o.id as order_gid,
               COALESCE(t.processed_at, t.created_at) AS txn_at,
               UPPER(t.status) AS status,
               INITCAP(REPLACE(COALESCE(t.gateway, ''Unknown''),
                               CHR(95), CHR(32))) AS gateway,
               COALESCE(t.amount, 0) AS amount
        FROM public.fact_order_transactions t
        JOIN public.fact_order_headers o ON o.id = t.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND t.test = FALSE
          AND UPPER(t.kind) = ''REFUND''
          AND (:currentStartDate IS NULL OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    )
    SELECT COALESCE(s.transaction_gid, ''Unknown'') AS transaction_id,
           COALESCE(s.order_gid, ''Unknown'') AS order_id,
           ROUND(s.amount, 2) AS refund_amount,
           s.gateway AS gateway,
           COALESCE(p.id, ''None'') AS parent_transaction,
           COALESCE(s.status, ''UNKNOWN'') AS status,
           s.txn_at::date::text AS processed_date,
           COUNT(*) OVER() AS total_records
    FROM scoped_refunds s
    LEFT JOIN public.fact_order_transactions p ON p.id = s.transaction_gid
    ORDER BY s.txn_at DESC, s.transaction_gid
    LIMIT :limit OFFSET :offset
    ',
    NULL,
    'TABLE',
    60,
    'Detailed refund audit report listing transaction ID, order ID, refund amount, gateway, parent transaction ID, status, and date.',
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

--changeset saugat:RW-41-5
--comment seed Authorization & Payment Risk tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fffa3-ddd3-7db2-8979-6ceed49ee742',
    'Authorization Risk KPI',
    'Payments & Transactions/Authorization & Payment Risk/KPI/Authorization Risk KPI',
    $$
    WITH scoped_txn AS (
        SELECT * FROM (
            SELECT t.order_id,
                   ((:currentStartDate::date IS NULL OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(t.processed_at, t.created_at)::date BETWEEN :priorStartDate::date AND :priorEndDate::date)          AS is_prior,
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
        SELECT COALESCE(SUM(GREATEST(p.cur_authorized - p.cur_captured, 0)), 0) AS cur_uncaptured,
               COALESCE(SUM(GREATEST(p.prv_authorized - p.prv_captured, 0)), 0) AS prv_uncaptured
        FROM per_order p
    )
    SELECT ROUND(c.cur_uncaptured, 2) AS uncaptured_amount,
           ROUND(100 * (c.cur_uncaptured - c.prv_uncaptured)
                 / NULLIF(ABS(c.prv_uncaptured), 0), 2) AS uncaptured_amount_divergence
    FROM computed c
    $$,
    NULL,
    'KPI',
    60,
    'Authorization risk KPI tracking uncaptured authorization dollar amount vs prior period.',
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
    '019fffa3-ddd3-72e7-921a-5c061dedb213',
    'Authorization vs Capture',
    'Payments & Transactions/Authorization & Payment Risk/PLOT/Authorization vs Capture',
    $$
    WITH scoped_txn AS (
        SELECT t.order_id,
               INITCAP(REPLACE(COALESCE(t.gateway, 'Unknown'),
                               CHR(95), CHR(32))) AS gateway,
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
          AND (:currentStartDate IS NULL OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    ),
    per_order_gateway AS (
        SELECT s.gateway,
               s.order_id,
               COALESCE(SUM(s.amount) FILTER (WHERE s.is_authorized), 0) AS authorized_amount,
               COALESCE(SUM(s.amount) FILTER (WHERE s.is_captured),   0) AS captured_amount
        FROM scoped_txn s
        GROUP BY s.gateway, s.order_id
    ),
    gateway_totals AS (
        SELECT p.gateway,
               SUM(p.authorized_amount) AS authorized_amount,
               SUM(p.captured_amount) AS captured_amount,
               SUM(GREATEST(p.authorized_amount - p.captured_amount, 0)) AS uncaptured_amount
        FROM per_order_gateway p
        GROUP BY p.gateway
    )
    SELECT gt.gateway AS gateway,
           ROUND(gt.authorized_amount, 2) AS authorized_amount,
           ROUND(gt.captured_amount, 2) AS captured_amount,
           ROUND(gt.uncaptured_amount, 2) AS uncaptured_amount
    FROM gateway_totals gt
    ORDER BY gt.captured_amount DESC, gt.gateway ASC
    LIMIT :limit OFFSET :offset
    $$,
    NULL,
    'PLOT',
    60,
    'Comparison per gateway between authorized amount, captured amount, and uncaptured amount.',
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
    '019fffa3-ddd3-7fa3-835b-cd566678e1df',
    'Authorization Capture Report',
    'Payments & Transactions/Authorization & Payment Risk/TABLE/Authorization Capture Report',
    $$
    WITH filtered_orders AS (
        SELECT o.id,
               o.created_at,
               UPPER(o.financialstatus) AS financial_status
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND (:currentStartDate IS NULL OR o.created_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR o.created_at::date <= :currentEndDate::date)
    ),
    order_txn AS (
        SELECT t.order_id,
               COALESCE(SUM(COALESCE(t.amount, 0)) FILTER (
                   WHERE UPPER(t.kind) IN ('AUTHORIZATION', 'EMV_AUTHORIZATION')
                     AND UPPER(t.status) = 'SUCCESS'), 0) AS authorized_amount,
               COALESCE(SUM(COALESCE(t.amount, 0)) FILTER (
                   WHERE UPPER(t.kind) IN ('SALE', 'CAPTURE')
                     AND UPPER(t.status) = 'SUCCESS'), 0) AS captured_amount
        FROM public.fact_order_transactions t
        JOIN filtered_orders f ON f.id = t.order_id
        WHERE t.test = FALSE
        GROUP BY t.order_id
    ),
    order_gateway AS (
        SELECT DISTINCT ON (g.order_id) g.order_id, g.gateway
        FROM (
            SELECT t.order_id,
                   INITCAP(REPLACE(COALESCE(t.gateway, 'Unknown'),
                                   CHR(95), CHR(32))) AS gateway,
                   SUM(COALESCE(t.amount, 0)) AS amount
            FROM public.fact_order_transactions t
            JOIN filtered_orders f ON f.id = t.order_id
            WHERE t.test = FALSE
            GROUP BY t.order_id,
                     INITCAP(REPLACE(COALESCE(t.gateway, 'Unknown'),
                                     CHR(95), CHR(32)))
        ) g
        ORDER BY g.order_id, g.amount DESC, g.gateway ASC
    )
    SELECT COALESCE(f.id, 'Unknown') AS order_id,
           ROUND(COALESCE(ot.authorized_amount, 0), 2) AS authorized_amount,
           ROUND(COALESCE(ot.captured_amount, 0), 2) AS captured_amount,
           ROUND(GREATEST(COALESCE(ot.authorized_amount, 0)
                          - COALESCE(ot.captured_amount, 0), 0), 2) AS uncaptured_amount,
           COALESCE(f.financial_status, 'UNKNOWN') AS status,
           COALESCE(og.gateway, 'Unknown') AS gateway,
           COUNT(*) OVER() AS total_records
    FROM filtered_orders f
    LEFT JOIN order_txn ot ON ot.order_id = f.id
    LEFT JOIN order_gateway og ON og.order_id = f.id
    ORDER BY GREATEST(COALESCE(ot.authorized_amount, 0)
                      - COALESCE(ot.captured_amount, 0), 0) DESC,
             f.created_at DESC, f.id
    LIMIT :limit OFFSET :offset
    $$,
    NULL,
    'TABLE',
    60,
    'Audit table for order authorizations listing authorized amount, captured amount, uncaptured balance, status, and gateway.',
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

--changeset saugat:RW-41-6
--comment seed POS & Alternative Payment Operations tab

INSERT INTO vizkit.chart (id, name, purpose, query, metadata, chart_type, cache_ttl, description, configuration)
VALUES (
    '019fffa3-ddd3-7fcb-9184-cba9c41c659c',
    'POS & Alternative Payment KPIs',
    'Payments & Transactions/POS & Alternative Payment Operations/KPI/POS & Alternative Payment KPIs',
    '
    WITH scoped_txn AS (
        SELECT * FROM (
            SELECT ((:currentStartDate::date IS NULL OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
                AND (:currentEndDate::date   IS NULL OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)) AS is_current,
                   (:priorStartDate::date IS NOT NULL
                AND COALESCE(t.processed_at, t.created_at)::date BETWEEN :priorStartDate::date AND :priorEndDate::date)          AS is_prior,
                   COALESCE(t.amount, 0) AS amount,
                   COALESCE(t.amount_rounding, 0) AS rounding,
                   t.manual_payment_gateway AS is_manual,
                   (UPPER(t.kind) IN (''SALE'', ''CAPTURE'')
                AND UPPER(t.status) = ''SUCCESS'') AS is_payment
            FROM public.fact_order_transactions t
            JOIN public.fact_order_headers o ON o.id = t.order_id
            WHERE o.seller_id = :shopId
              AND o.test = FALSE
              
              AND t.test = FALSE
        ) x
        WHERE x.is_current OR x.is_prior
    ),
    txn_totals AS (
        SELECT COALESCE(SUM(amount) FILTER (WHERE is_current AND is_payment AND is_manual), 0) AS cur_manual,
               COALESCE(SUM(amount) FILTER (WHERE is_prior   AND is_payment AND is_manual), 0) AS prv_manual,
               COALESCE(SUM(rounding) FILTER (WHERE is_current), 0) AS cur_rounding,
               COALESCE(SUM(rounding) FILTER (WHERE is_prior),   0) AS prv_rounding
        FROM scoped_txn
    ),
    scoped_tender AS (
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
    ),
    top_brand AS (
        SELECT card_brand
        FROM scoped_tender
        GROUP BY card_brand
        ORDER BY SUM(amount) DESC NULLS LAST, card_brand ASC
        LIMIT 1
    )
    SELECT ROUND(tot.cur_manual, 2) AS manual_payment_amount,
           ROUND(100 * (tot.cur_manual - tot.prv_manual)
                 / NULLIF(ABS(tot.prv_manual), 0), 2) AS manual_payment_amount_divergence,
           ROUND(tot.cur_rounding, 2) AS cash_rounding_adjustment,
           ROUND(100 * (tot.cur_rounding - tot.prv_rounding)
                 / NULLIF(ABS(tot.prv_rounding), 0), 2) AS cash_rounding_adjustment_divergence,
           COALESCE((SELECT card_brand FROM top_brand), ''No data'') AS top_card_brand
    FROM txn_totals tot
    ',
    NULL,
    'KPI',
    60,
    'POS & alternative payment KPIs evaluating manual payment volume, cash rounding adjustment amount, and top credit card brand vs prior period.',
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
    '019fffa3-ddd3-7ac0-84ad-a47393da0230',
    'Manual vs Automated Payments',
    'Payments & Transactions/POS & Alternative Payment Operations/PLOT/Manual vs Automated Payments',
    '
    WITH classified AS (
        SELECT CASE WHEN t.manual_payment_gateway THEN ''Manual''
                    ELSE ''Automated'' END AS payment_type,
               COALESCE(t.amount, 0) AS amount
        FROM public.fact_order_transactions t
        JOIN public.fact_order_headers o ON o.id = t.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND t.test = FALSE
          AND UPPER(t.kind) IN (''SALE'', ''CAPTURE'')
          AND UPPER(t.status) = ''SUCCESS''
          AND (:currentStartDate IS NULL OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    ),
    bands(ord, payment_type) AS (
        VALUES (1, ''Automated''), (2, ''Manual'')
    )
    SELECT b.payment_type AS payment_type,
           ROUND(COALESCE(SUM(c.amount), 0), 2) AS payment_amount
    FROM bands b
    LEFT JOIN classified c ON c.payment_type = b.payment_type
    GROUP BY b.ord, b.payment_type
    ORDER BY b.ord
    ',
    NULL,
    'PLOT',
    60,
    'Proportional breakdown between manual vs automated gateway payment volume.',
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
    '019fffa3-ddd3-79b5-978e-90241244259a',
    'POS Payments by Location',
    'Payments & Transactions/POS & Alternative Payment Operations/PLOT/POS Payments by Location',
    '
    SELECT COALESCE(loc.name, ''Unknown'') AS location,
           ROUND(SUM(COALESCE(t.amount, 0)), 2) AS payment_amount
    FROM public.fact_order_transactions t
    JOIN public.fact_order_headers o ON o.id = t.order_id
    JOIN public.dim_inventory_locations loc ON loc.id = t.location_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      
      AND t.test = FALSE
      AND UPPER(t.kind) IN (''SALE'', ''CAPTURE'')
      AND UPPER(t.status) = ''SUCCESS''
      AND (:currentStartDate IS NULL OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
      AND (:currentEndDate IS NULL OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    GROUP BY COALESCE(loc.name, ''Unknown'')
    ORDER BY SUM(COALESCE(t.amount, 0)) DESC, 1 ASC
    LIMIT :limit OFFSET :offset
    ',
    NULL,
    'PLOT',
    60,
    'Point of Sale payment volume per physical store location.',
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
    '019fffa3-ddd3-70da-a2b4-ba575ac4d820',
    'Card Brand Mix',
    'Payments & Transactions/POS & Alternative Payment Operations/PLOT/Card Brand Mix',
    '
    SELECT INITCAP(REPLACE(tt.transaction_credit_card_company, CHR(95), CHR(32))) AS card_brand,
           ROUND(SUM(COALESCE(tt.amount, 0)), 2) AS "Card Payment Amount"
    FROM public.dim_tender_transactions tt
    JOIN public.fact_order_headers o ON o.id = tt.order_id
    WHERE o.seller_id = :shopId
      AND o.test = FALSE
      
      AND tt.test = FALSE
      AND tt.transaction_credit_card_company IS NOT NULL
      AND (:currentStartDate IS NULL OR tt.processed_at::date >= :currentStartDate::date)
      AND (:currentEndDate IS NULL OR tt.processed_at::date <= :currentEndDate::date)
    GROUP BY 1
    ORDER BY SUM(COALESCE(tt.amount, 0)) DESC, 1 ASC
    LIMIT :limit OFFSET :offset
    ',
    NULL,
    'PLOT',
    60,
    'Payment volume mix per credit card network/brand.',
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
    '019fffa3-ddd3-7803-b1ad-78780dcea258',
    'Cash Rounding Adjustments Trend',
    'Payments & Transactions/POS & Alternative Payment Operations/PLOT/Cash Rounding Adjustments Trend',
    '
    WITH
    date_params AS (
        SELECT
            g,
            CASE WHEN g = ''DAY''   THEN date_trunc(''day'',   :currentStartDate::date)
                 WHEN g = ''WEEK''  THEN date_trunc(''week'',  :currentStartDate::date)
                 WHEN g = ''MONTH'' THEN date_trunc(''month'', :currentStartDate::date)
                 WHEN g = ''YEAR''  THEN date_trunc(''year'',  :currentStartDate::date)
            END AS start_bucket,
            CASE WHEN g = ''DAY''   THEN date_trunc(''day'',   :currentEndDate::date)
                 WHEN g = ''WEEK''  THEN date_trunc(''week'',  :currentEndDate::date)
                 WHEN g = ''MONTH'' THEN date_trunc(''month'', :currentEndDate::date)
                 WHEN g = ''YEAR''  THEN date_trunc(''year'',  :currentEndDate::date)
            END AS end_bucket,
            CASE WHEN g = ''DAY''   THEN interval ''1 day''
                 WHEN g = ''WEEK''  THEN interval ''1 week''
                 WHEN g = ''MONTH'' THEN interval ''1 month''
                 WHEN g = ''YEAR''  THEN interval ''1 year''
            END AS step
        FROM (
            SELECT COALESCE(
                NULLIF(:granularity, ''''),
                CASE WHEN (:currentEndDate::date - :currentStartDate::date) > 730 THEN ''YEAR''
                     WHEN (:currentEndDate::date - :currentStartDate::date) > 180 THEN ''MONTH''
                     WHEN (:currentEndDate::date - :currentStartDate::date) > 31  THEN ''WEEK''
                     ELSE ''DAY''
                END
            ) AS g
        ) sub
    ),
    date_filler AS (
        SELECT generate_series(dp.start_bucket, dp.end_bucket, dp.step) AS bucket
        FROM date_params dp
    ),
    scoped_txn AS (
        SELECT date_trunc(LOWER(dp.g), COALESCE(t.processed_at, t.created_at)) AS bucket,
               COALESCE(t.amount_rounding, 0) AS rounding
        FROM public.fact_order_transactions t
        JOIN public.fact_order_headers o ON o.id = t.order_id
        CROSS JOIN date_params dp
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND t.test = FALSE
          AND COALESCE(t.processed_at, t.created_at) >= dp.start_bucket
          AND COALESCE(t.processed_at, t.created_at) <= :currentEndDate::date
    ),
    daily AS (
        SELECT s.bucket, SUM(s.rounding) AS rounding_amount
        FROM scoped_txn s
        GROUP BY s.bucket
    )
    SELECT to_char(df.bucket,
               CASE WHEN dp.g = ''DAY''   THEN ''Mon DD, YYYY''
                    WHEN dp.g = ''WEEK''  THEN ''Mon DD, YYYY''
                    WHEN dp.g = ''MONTH'' THEN ''Mon YYYY''
                    WHEN dp.g = ''YEAR''  THEN ''YYYY''
               END
           ) AS period,
           df.bucket,
           ROUND(COALESCE(d.rounding_amount, 0), 2) AS rounding_amount
    FROM date_filler df
    CROSS JOIN date_params dp
    LEFT JOIN daily d ON d.bucket = df.bucket
    ORDER BY df.bucket ASC
    ',
    NULL,
    'PLOT',
    60,
    'Cash rounding adjustment dollar volume trend grouped by dynamic date granularity.',
    '{
      "filterMappings": {
        "shopId": { "source": "AUTH_CONTEXT", "contextKey": "shopGid" },
        "userId": { "source": "AUTH_CONTEXT", "contextKey": "user_id" },
        "currentStartDate": { "source": "REQUEST_FILTER", "filterKey": "startDate" },
        "currentEndDate":   { "source": "REQUEST_FILTER", "filterKey": "endDate" },
        "granularity":    { "source": "REQUEST_FILTER", "filterKey": "granularity" }
      },
      "excludeExtraParams": true
    }'
),
(
    '019fffa3-ddd3-7b1a-a7b4-6d3cc0d9d8b7',
    'Manual Payment Report',
    'Payments & Transactions/POS & Alternative Payment Operations/TABLE/Manual Payment Report',
    '
    WITH scoped_txn AS (
        SELECT t.id,
               o.id as order_gid,
               t.gateway,
               COALESCE(t.processed_at, t.created_at) AS txn_at,
               UPPER(t.status) AS status,
               COALESCE(t.amount, 0) AS amount
        FROM public.fact_order_transactions t
        JOIN public.fact_order_headers o ON o.id = t.order_id
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
          AND t.test = FALSE
          AND t.manual_payment_gateway IS true
          AND (:currentStartDate IS NULL OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    )
    SELECT COALESCE(s.order_gid, ''Unknown'') AS order_id,
           INITCAP(REPLACE(s.gateway, CHR(95), CHR(32))) AS manual_gateway,
           ROUND(s.amount, 2) AS amount,
           s.txn_at::date::text AS processed_date,
           COALESCE(s.status, ''UNKNOWN'') AS status,
           COUNT(*) OVER() AS total_records
    FROM scoped_txn s
    ORDER BY s.txn_at DESC, s.id
    LIMIT :limit OFFSET :offset
    ',
    NULL,
    'TABLE',
    60,
    'Detailed audit log table of manual payment transactions listing order ID, gateway name, amount, date, and status.',
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
    '019fffa3-ddd3-7964-b52a-a330c2f1e7a0',
    'POS Payment Report',
    'Payments & Transactions/POS & Alternative Payment Operations/TABLE/POS Payment Report',
    '
    WITH scoped_orders AS (
        SELECT o.id
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
    ),
    pos_txn AS (
        SELECT t.order_id,
               COALESCE(loc.name, ''Unknown'') AS location,
               COALESCE(t.device_id, ''Unknown'') AS device,
               COALESCE(t.amount, 0) AS amount
        FROM public.fact_order_transactions t
        JOIN scoped_orders so ON so.id = t.order_id
        LEFT JOIN public.dim_inventory_locations loc ON loc.id = t.location_id
        WHERE t.test = FALSE
          AND UPPER(t.kind) IN (''SALE'', ''CAPTURE'')
          AND UPPER(t.status) = ''SUCCESS''
          AND (t.device_id IS NOT NULL
            OR t.location_id IS NOT NULL)
          AND (:currentStartDate IS NULL OR COALESCE(t.processed_at, t.created_at)::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR COALESCE(t.processed_at, t.created_at)::date <= :currentEndDate::date)
    ),
    order_tender AS (
        SELECT tt.order_id,
               INITCAP(REPLACE(COALESCE(tt.payment_method, ''Unattributed''),
                               CHR(95), CHR(32))) AS method,
               SUM(COALESCE(tt.amount, 0)) AS amount
        FROM public.dim_tender_transactions tt
        JOIN scoped_orders so ON so.id = tt.order_id
        WHERE tt.test = FALSE
        GROUP BY tt.order_id,
                 INITCAP(REPLACE(COALESCE(tt.payment_method, ''Unattributed''),
                                 CHR(95), CHR(32)))
    ),
    primary_method AS (
        SELECT DISTINCT ON (ot.order_id) ot.order_id, ot.method
        FROM order_tender ot
        ORDER BY ot.order_id, ot.amount DESC, ot.method ASC
    ),
    order_refunds AS (
        SELECT t.order_id,
               SUM(COALESCE(t.amount, 0)) AS refunded
        FROM public.fact_order_transactions t
        JOIN scoped_orders so ON so.id = t.order_id
        WHERE t.test = FALSE
          AND UPPER(t.kind) = ''REFUND''
          AND UPPER(t.status) = ''SUCCESS''
        GROUP BY t.order_id
    ),
    pos_by_order AS (
        SELECT p.location, p.device, p.order_id,
               SUM(p.amount) AS amount
        FROM pos_txn p
        GROUP BY p.location, p.device, p.order_id
    )
    SELECT b.location AS location,
           b.device AS device,
           ROUND(SUM(b.amount), 2) AS payment_amount,
           COALESCE(string_agg(DISTINCT pm.method, CHR(44) || CHR(32)), ''Unknown'') AS payment_method,
           ROUND(COALESCE(SUM(orf.refunded), 0), 2) AS refund_amount,
           COUNT(*) OVER() AS total_records
    FROM pos_by_order b
    LEFT JOIN primary_method pm ON pm.order_id = b.order_id
    LEFT JOIN order_refunds orf ON orf.order_id = b.order_id
    GROUP BY b.location, b.device
    ORDER BY SUM(b.amount) DESC, b.location ASC, b.device ASC
    LIMIT :limit OFFSET :offset
    ',
    NULL,
    'TABLE',
    60,
    'POS terminal report table listing location, device ID, payment amount, payment method, and refund amount.',
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
    '019fffa3-ddd3-7ca6-a8ff-5976abc98ff7',
    'Card Brand Report',
    'Payments & Transactions/POS & Alternative Payment Operations/TABLE/Card Brand Report',
    '
    WITH scoped_orders AS (
        SELECT o.id
        FROM public.fact_order_headers o
        WHERE o.seller_id = :shopId
          AND o.test = FALSE
          
    ),
    scoped_tender AS (
        SELECT tt.order_id,
               INITCAP(REPLACE(tt.transaction_credit_card_company, CHR(95), CHR(32))) AS card_brand,
               COALESCE(tt.amount, 0) AS amount
        FROM public.dim_tender_transactions tt
        JOIN scoped_orders so ON so.id = tt.order_id
        WHERE tt.test = FALSE
          AND tt.transaction_credit_card_company IS NOT NULL
          AND (:currentStartDate IS NULL OR tt.processed_at::date >= :currentStartDate::date)
          AND (:currentEndDate IS NULL OR tt.processed_at::date <= :currentEndDate::date)
    ),
    brand_totals AS (
        SELECT s.card_brand,
               COUNT(*) AS transaction_count,
               SUM(s.amount) AS amount
        FROM scoped_tender s
        GROUP BY s.card_brand
    ),
    order_brand AS (
        SELECT s.order_id, s.card_brand, SUM(s.amount) AS amount
        FROM scoped_tender s
        GROUP BY s.order_id, s.card_brand
    ),
    primary_brand AS (
        SELECT DISTINCT ON (ob.order_id) ob.order_id, ob.card_brand
        FROM order_brand ob
        ORDER BY ob.order_id, ob.amount DESC, ob.card_brand ASC
    ),
    order_txn AS (
        SELECT t.order_id,
               COALESCE(SUM(COALESCE(t.amount, 0)) FILTER (
                   WHERE UPPER(t.kind) = ''REFUND''
                     AND UPPER(t.status) = ''SUCCESS''), 0) AS refunded,
               COUNT(*) FILTER (WHERE UPPER(t.status) IN (''FAILURE'', ''ERROR'')) AS failures,
               COUNT(*) AS txn_count
        FROM public.fact_order_transactions t
        JOIN scoped_orders so ON so.id = t.order_id
        WHERE t.test = FALSE
        GROUP BY t.order_id
    ),
    brand_txn AS (
        SELECT pb.card_brand,
               COALESCE(SUM(ot.refunded), 0) AS refund_amount,
               COALESCE(SUM(ot.failures), 0) AS failures,
               COALESCE(SUM(ot.txn_count), 0) AS txn_count
        FROM primary_brand pb
        LEFT JOIN order_txn ot ON ot.order_id = pb.order_id
        GROUP BY pb.card_brand
    )
    SELECT bt.card_brand AS card_brand,
           bt.transaction_count AS transaction_count,
           ROUND(bt.amount, 2) AS amount,
           ROUND(COALESCE(bx.refund_amount, 0), 2) AS refund_amount,
           ROUND(100.0 * COALESCE(bx.failures, 0)
                 / NULLIF(bx.txn_count, 0), 2) AS failure_rate,
           COUNT(*) OVER() AS total_records
    FROM brand_totals bt
    LEFT JOIN brand_txn bx ON bx.card_brand = bt.card_brand
    ORDER BY bt.amount DESC, bt.card_brand ASC
    LIMIT :limit OFFSET :offset
    ',
    NULL,
    'TABLE',
    60,
    'Credit card brand report table listing transaction count, total amount, refund amount, and failure rate %.',
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