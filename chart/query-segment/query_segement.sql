INSERT INTO
    query_segment (id, name, query)
VALUES (
        'c6b65345-4a56-42b7-8495-2c8e2279b001',
        'COMPARISON_WINDOW_CTE',
        'windows AS (
    SELECT :<currentStartParam>::date AS cur_start,
           :<currentEndParam>::date   AS cur_end,
           :<priorStartParam>::date   AS prv_start,
           :<priorEndParam>::date     AS prv_end
),'
    ),
    (
        'c6b65345-4a56-42b7-8495-2c8e2279b002',
        'DATE_GRANULARITY_CTE',
        'date_params AS (
    SELECT
        g,
        CASE WHEN g = ''DAY''     THEN date_trunc(''day'',     :<startDateParam>::date)
             WHEN g = ''WEEK''    THEN date_trunc(''week'',    :<startDateParam>::date)
             WHEN g = ''MONTH''   THEN date_trunc(''month'',   :<startDateParam>::date)
             WHEN g = ''QUARTER'' THEN date_trunc(''quarter'', :<startDateParam>::date)
             WHEN g = ''YEAR''    THEN date_trunc(''year'',    :<startDateParam>::date)
        END AS start_bucket,
        CASE WHEN g = ''DAY''     THEN date_trunc(''day'',     :<endDateParam>::date)
             WHEN g = ''WEEK''    THEN date_trunc(''week'',    :<endDateParam>::date)
             WHEN g = ''MONTH''   THEN date_trunc(''month'',   :<endDateParam>::date)
             WHEN g = ''QUARTER'' THEN date_trunc(''quarter'', :<endDateParam>::date)
             WHEN g = ''YEAR''    THEN date_trunc(''year'',    :<endDateParam>::date)
        END AS end_bucket,
        CASE WHEN g = ''DAY''     THEN interval ''1 day''
             WHEN g = ''WEEK''    THEN interval ''1 week''
             WHEN g = ''MONTH''   THEN interval ''1 month''
             WHEN g = ''QUARTER'' THEN interval ''3 months''
             WHEN g = ''YEAR''    THEN interval ''1 year''
        END AS step
    FROM (
        SELECT COALESCE(
            NULLIF(:<granularityParam>, ''''),
            CASE WHEN (:<endDateParam>::date - :<startDateParam>::date) > 730 THEN ''YEAR''
                 WHEN (:<endDateParam>::date - :<startDateParam>::date) > 365 THEN ''QUARTER''
                 WHEN (:<endDateParam>::date - :<startDateParam>::date) > 180 THEN ''MONTH''
                 WHEN (:<endDateParam>::date - :<startDateParam>::date) > 31  THEN ''WEEK''
                 ELSE ''DAY''
            END
        ) AS g
    ) sub
),
date_filler AS (
    SELECT generate_series(dp.start_bucket, dp.end_bucket, dp.step) AS bucket
    FROM date_params dp
),'
    );