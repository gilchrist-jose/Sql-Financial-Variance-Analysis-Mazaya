-- ============================================================
-- MAZAYA RETAIL GROUP — Finance Expense Variance Reporting
-- Script 3 of 4: Threshold Flagging — Breach Detection
-- Dialect: PostgreSQL
-- ============================================================
-- WHAT THIS QUERY DOES (business language first):
-- Surfaces only the department + account combinations that have
-- materially breached their budget threshold on an annual basis.
-- "Material" is defined as an UNFAVORABLE variance exceeding 5%
-- of the annual budget. Everything under that threshold is noise.
-- ============================================================
-- KEY SQL CONCEPT: HAVING vs WHERE
-- WHERE  → filters raw rows BEFORE aggregation (GROUP BY)
-- HAVING → filters aggregated results AFTER aggregation
-- We must use HAVING here because variance_pct is a calculated
-- aggregate — it does not exist until after GROUP BY runs.
-- Using WHERE on an aggregate throws an error in PostgreSQL.
-- ============================================================


-- ============================================================
-- PART A: Department + account combinations breaching 5%
-- Annual view — full year actuals vs budget
-- ============================================================

SELECT

    d.dept_name,
    g.account_code,
    g.account_name,
    g.account_type,

    SUM(b.budget_amount)                                AS annual_budget,
    SUM(a.actual_amount)                                AS annual_actual,
    SUM(a.actual_amount - b.budget_amount)              AS annual_variance,

    ROUND(
        SUM(a.actual_amount - b.budget_amount)
        / NULLIF(SUM(b.budget_amount), 0) * 100
    , 2)                                                AS variance_pct,

    -- Severity banding — tells leadership not just THAT something
    -- breached but HOW BADLY. Three bands give an instant priority
    -- signal so finance can triage without reading every number.
    CASE
        WHEN g.account_type = 'EXPENSE'
             AND ROUND(
                    SUM(a.actual_amount - b.budget_amount)
                    / NULLIF(SUM(b.budget_amount), 0) * 100
                , 2) > 10                               THEN 'CRITICAL'
        WHEN g.account_type = 'EXPENSE'
             AND ROUND(
                    SUM(a.actual_amount - b.budget_amount)
                    / NULLIF(SUM(b.budget_amount), 0) * 100
                , 2) BETWEEN 5 AND 10                  THEN 'WARNING'
        WHEN g.account_type = 'REVENUE'
             AND ROUND(
                    SUM(a.actual_amount - b.budget_amount)
                    / NULLIF(SUM(b.budget_amount), 0) * 100
                , 2) < -10                              THEN 'CRITICAL'
        WHEN g.account_type = 'REVENUE'
             AND ROUND(
                    SUM(a.actual_amount - b.budget_amount)
                    / NULLIF(SUM(b.budget_amount), 0) * 100
                , 2) < -5                               THEN 'WARNING'
    END                                                 AS severity

FROM budget b
    JOIN actuals     a ON  b.dept_id    = a.dept_id
                       AND b.account_id = a.account_id
                       AND b.month      = a.month
    JOIN departments d ON  b.dept_id    = d.dept_id
    JOIN gl_accounts g ON  b.account_id = g.account_id

GROUP BY
    d.dept_name,
    g.account_code,
    g.account_name,
    g.account_type

-- HAVING enforces the threshold filter after aggregation.
-- Cannot use WHERE here — the variance does not exist yet
-- at the WHERE stage. WHERE runs before GROUP BY and SUM.
-- Favorable variances are intentionally excluded — finance
-- does not escalate because a department underspent.
HAVING
    (
        g.account_type = 'EXPENSE'
        AND ROUND(
                SUM(a.actual_amount - b.budget_amount)
                / NULLIF(SUM(b.budget_amount), 0) * 100
            , 2) > 5
    )
    OR
    (
        g.account_type = 'REVENUE'
        AND ROUND(
                SUM(a.actual_amount - b.budget_amount)
                / NULLIF(SUM(b.budget_amount), 0) * 100
            , 2) < -5
    )

-- Sort by absolute variance amount — biggest cash exposure first.
-- Sorting by % alone is misleading: a 50% variance on a 5,000 AED
-- account matters far less than a 15% variance on 500,000 AED.
ORDER BY
    ABS(SUM(a.actual_amount - b.budget_amount)) DESC;


-- ============================================================
-- PART B: Month-by-month breach timeline
-- For the accounts flagged in Part A, shows exactly which
-- months triggered a breach — helping finance trace root cause.
--
-- Part A is the filter. Part B is the drill-down.
-- Only accounts that appeared in Part A belong here —
-- there is no value in drilling into accounts that never
-- breached at the annual level.
-- ============================================================

SELECT

    d.dept_name,
    g.account_name,
    g.account_type,
    TO_CHAR(b.month, 'Mon YYYY')                        AS month,
    b.budget_amount,
    a.actual_amount,
    (a.actual_amount - b.budget_amount)                 AS variance_amount,
    ROUND(
        (a.actual_amount - b.budget_amount)
        / NULLIF(b.budget_amount, 0) * 100
    , 2)                                                AS variance_pct,

    -- Month-level breach flag.
    -- WHERE is correct here (not HAVING) — we are filtering
    -- on row-level values, not aggregates. No GROUP BY in this
    -- query so variance is calculated per individual row directly.
    CASE
        WHEN g.account_type = 'EXPENSE'
             AND (a.actual_amount - b.budget_amount)
                 / NULLIF(b.budget_amount, 0) * 100 > 5   THEN 'BREACH'
        WHEN g.account_type = 'REVENUE'
             AND (a.actual_amount - b.budget_amount)
                 / NULLIF(b.budget_amount, 0) * 100 < -5  THEN 'BREACH'
        ELSE 'WITHIN THRESHOLD'
    END                                                 AS monthly_status

FROM budget b
    JOIN actuals     a ON  b.dept_id    = a.dept_id
                       AND b.account_id = a.account_id
                       AND b.month      = a.month
    JOIN departments d ON  b.dept_id    = d.dept_id
    JOIN gl_accounts g ON  b.account_id = g.account_id

-- Filter to the three accounts confirmed as breaching in Part A.
-- dept_id used instead of dept_name to avoid case sensitivity
-- issues with string matching — IDs are unambiguous.
-- Account 5400: Delivery & Fulfilment (Logistics, dept_id=3)
-- Account 5200: Digital Advertising   (Marketing, dept_id=1)
-- Account 5500: Software & Subscriptions (E-Commerce, dept_id=4)
WHERE
    g.account_code IN ('5400', '5200', '5500')
    AND b.dept_id IN (3, 1, 4)

ORDER BY
    d.dept_name,
    g.account_name,
    b.month;
