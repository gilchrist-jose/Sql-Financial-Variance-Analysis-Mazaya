-- ============================================================
-- MAZAYA RETAIL GROUP — Finance Expense Variance Reporting
-- Script 2 of 4: Core Variance Report
-- Dialect: PostgreSQL
-- ============================================================
-- WHAT THIS QUERY DOES (business language first):
-- Joins budget to actuals on the three grain columns
-- (dept_id, account_id, month), pulls in department names
-- and account details, then calculates:
--   1. Variance amount       = actual - budget
--   2. Variance %            = variance / budget × 100
--   3. Variance label        = FAVORABLE or UNFAVORABLE
--      (direction flips depending on account type)
-- ============================================================


-- ============================================================
-- PART A: Month-level detail
-- One row per department + account + month
-- ============================================================

SELECT

    d.dept_name,
    g.account_code,
    g.account_name,
    g.account_type,
    TO_CHAR(b.month, 'Mon YYYY')            AS month,

    b.budget_amount,
    a.actual_amount,

    -- Variance amount: actual minus budget.
    -- Positive = overspent (for expenses). Negative = underspent.
    -- Sign carries meaning — do not use ABS() here.
    (a.actual_amount - b.budget_amount)     AS variance_amount,

    -- Variance percentage: size of variance relative to budget.
    -- NULLIF prevents division-by-zero if budget is ever zero.
    ROUND(
        (a.actual_amount - b.budget_amount)
        / NULLIF(b.budget_amount, 0) * 100
    , 2)                                    AS variance_pct,

    -- Variance classification — the core business logic.
    -- The same positive variance means opposite things depending
    -- on account type. A revenue account beating budget is good.
    -- An expense account beating budget means overspend.
    -- Interview answer: "I embedded account_type into the CASE WHEN
    -- so classification is always directionally correct. A flat rule
    -- of positive variance = bad would produce wrong results for
    -- revenue accounts."
    CASE
        WHEN g.account_type = 'EXPENSE' AND a.actual_amount > b.budget_amount THEN 'UNFAVORABLE'
        WHEN g.account_type = 'EXPENSE' AND a.actual_amount < b.budget_amount THEN 'FAVORABLE'
        WHEN g.account_type = 'REVENUE' AND a.actual_amount > b.budget_amount THEN 'FAVORABLE'
        WHEN g.account_type = 'REVENUE' AND a.actual_amount < b.budget_amount THEN 'UNFAVORABLE'
        ELSE 'ON BUDGET'
    END                                     AS variance_flag

FROM budget b

    -- Core JOIN: matches budget to actuals on all three grain columns.
    -- Joining on fewer than three columns produces a cartesian product —
    -- January budget would match all 12 months of actuals, inflating
    -- every figure by 12x. All three columns are required.
    JOIN actuals a
        ON  b.dept_id    = a.dept_id
        AND b.account_id = a.account_id
        AND b.month      = a.month

    -- Lookup JOINs: swap IDs for human-readable names.
    JOIN departments d ON b.dept_id    = d.dept_id
    JOIN gl_accounts g ON b.account_id = g.account_id

ORDER BY
    d.dept_name,
    g.account_code,
    b.month;


-- ============================================================
-- PART B: Annual summary — rolled up by department + account
-- Aggregates the full year into one row per dept/account.
-- ============================================================

SELECT

    d.dept_name,
    g.account_code,
    g.account_name,
    g.account_type,

    SUM(b.budget_amount)                                    AS annual_budget,
    SUM(a.actual_amount)                                    AS annual_actual,
    SUM(a.actual_amount - b.budget_amount)                  AS annual_variance,

    -- Variance % calculated on full-year totals, not averaged
    -- across monthly percentages. Averaging percentages is a
    -- common analytical mistake — always work from base totals.
    ROUND(
        SUM(a.actual_amount - b.budget_amount)
        / NULLIF(SUM(b.budget_amount), 0) * 100
    , 2)                                                    AS annual_variance_pct,

    CASE
        WHEN g.account_type = 'EXPENSE'
             AND SUM(a.actual_amount) > SUM(b.budget_amount) THEN 'UNFAVORABLE'
        WHEN g.account_type = 'EXPENSE'
             AND SUM(a.actual_amount) < SUM(b.budget_amount) THEN 'FAVORABLE'
        WHEN g.account_type = 'REVENUE'
             AND SUM(a.actual_amount) > SUM(b.budget_amount) THEN 'FAVORABLE'
        WHEN g.account_type = 'REVENUE'
             AND SUM(a.actual_amount) < SUM(b.budget_amount) THEN 'UNFAVORABLE'
        ELSE 'ON BUDGET'
    END                                                     AS annual_variance_flag

FROM budget b
    JOIN actuals     a ON  b.dept_id    = a.dept_id
                       AND b.account_id = a.account_id
                       AND b.month      = a.month
    JOIN departments d ON  b.dept_id    = d.dept_id
    JOIN gl_accounts g ON  b.account_id = g.account_id

-- Every column in SELECT that is not inside an aggregate function
-- must appear in GROUP BY. Aggregates (SUM) collapse the 12
-- monthly rows per dept/account combination into one.
GROUP BY
    d.dept_name,
    g.account_code,
    g.account_name,
    g.account_type

ORDER BY
    d.dept_name,
    g.account_code;
