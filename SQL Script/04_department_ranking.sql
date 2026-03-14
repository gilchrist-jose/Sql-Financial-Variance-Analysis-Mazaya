-- ============================================================
-- MAZAYA RETAIL GROUP — Finance Expense Variance Reporting
-- Script 4 of 4: Department Ranking by Overspend
-- Dialect: PostgreSQL
-- ============================================================
-- WHAT THIS QUERY DOES (business language first):
-- Ranks departments from worst to best based on total expense
-- overspend across the full year. Produces a clean leaderboard
-- for executive reporting, with an account-level drill-down
-- showing what is driving each department's position.
-- ============================================================
-- KEY SQL CONCEPT: Window Functions vs GROUP BY
-- GROUP BY   → collapses multiple rows into one per group
-- DENSE_RANK() OVER() → adds a rank column without collapsing rows
-- PARTITION BY → resets the rank counter per group (within-group ranking)
-- ============================================================


-- ============================================================
-- PART A: Department overspend leaderboard
-- One row per department, ranked by total annual overspend.
-- Only EXPENSE accounts — revenue variance is a separate
-- conversation from cost discipline.
-- ============================================================

SELECT

    dept_rank,
    dept_name,
    total_budget,
    total_actual,
    total_overspend,
    overspend_pct,

    -- Spend discipline label — turns a number into a narrative.
    -- overspend_pct is allowed to go negative here so that
    -- underspending departments are correctly labelled
    -- 'Under Budget' rather than 'On Budget'.
    CASE
        WHEN overspend_pct > 10  THEN 'Significantly Over Budget'
        WHEN overspend_pct > 5   THEN 'Moderately Over Budget'
        WHEN overspend_pct > 0   THEN 'Slightly Over Budget'
        WHEN overspend_pct = 0   THEN 'On Budget'
        ELSE                          'Under Budget'
    END                                             AS spend_discipline

FROM (

    -- Inner query: does all the heavy lifting.
    -- Calculates aggregates, assigns department rank.
    -- Outer query simply selects from this result and
    -- adds the spend discipline label on top.
    SELECT

        d.dept_name,
        SUM(b.budget_amount)                        AS total_budget,
        SUM(a.actual_amount)                        AS total_actual,

        -- GREATEST floors total_overspend at zero.
        -- A department that underspent has negative variance.
        -- Letting that flow into the display column would be
        -- misleading — negative overspend is not overspend.
        -- GREATEST(negative_number, 0) returns 0 cleanly.
        -- NOTE: overspend_pct is NOT floored because it feeds
        -- the CASE WHEN label — negative values correctly
        -- trigger the 'Under Budget' branch.
        GREATEST(
            SUM(a.actual_amount - b.budget_amount), 0
        )                                           AS total_overspend,

        ROUND(
            SUM(a.actual_amount - b.budget_amount)
            / NULLIF(SUM(b.budget_amount), 0) * 100
        , 2)                                        AS overspend_pct,

        -- DENSE_RANK() window function.
        -- OVER() is what makes this a window function —
        -- without it this would throw an error.
        -- ORDER BY raw variance DESC → rank 1 = highest overspend.
        -- DENSE_RANK() chosen over RANK() because tied departments
        -- get consecutive ranks (1,1,2) rather than skipped ranks
        -- (1,1,3) — cleaner for a business audience.
        -- Ranks on raw variance sum, not GREATEST version, so
        -- underspending departments correctly rank last.
        DENSE_RANK() OVER (
            ORDER BY SUM(a.actual_amount - b.budget_amount) DESC
        )                                           AS dept_rank

    FROM budget b
        JOIN actuals     a ON  b.dept_id    = a.dept_id
                           AND b.account_id = a.account_id
                           AND b.month      = a.month
        JOIN departments d ON  b.dept_id    = d.dept_id
        JOIN gl_accounts g ON  b.account_id = g.account_id

    -- EXPENSE accounts only — including revenue would distort
    -- the ranking. A department beating revenue target would show
    -- a large positive variance and rank as a top overspender
    -- for entirely the wrong reason.
    WHERE g.account_type = 'EXPENSE'

    -- GROUP BY dept_name only — we want one row per department.
    -- All other columns are either aggregated (SUM, DENSE_RANK)
    -- or derived from the aggregates, so they don't need to
    -- appear here.
    GROUP BY d.dept_name

) ranked_departments

ORDER BY dept_rank;


-- ============================================================
-- PART B: Account-level breakdown within each department
-- Shows what is driving each department's overspend.
-- Part A tells you which departments have a problem.
-- Part B tells you which accounts within those departments
-- are causing it.
-- ============================================================

SELECT

    d.dept_name,
    g.account_code,
    g.account_name,
    SUM(b.budget_amount)                            AS total_budget,
    SUM(a.actual_amount)                            AS total_actual,
    SUM(a.actual_amount - b.budget_amount)          AS variance_amount,
    ROUND(
        SUM(a.actual_amount - b.budget_amount)
        / NULLIF(SUM(b.budget_amount), 0) * 100
    , 2)                                            AS variance_pct,

    -- Account rank WITHIN each department.
    -- PARTITION BY d.dept_name resets the rank counter for each
    -- department — so every department has its own internal
    -- rank 1, 2, 3 for its accounts independently.
    -- This is the key distinction:
    --   OVER(ORDER BY x)              → one global ranking
    --   OVER(PARTITION BY y ORDER BY x) → one ranking per group
    -- Interview answer: "PARTITION BY is the window function
    -- equivalent of GROUP BY — it defines the subset of rows
    -- the rank resets over. Without it you get a global ranking.
    -- With it you get an independent ranking per department."
    DENSE_RANK() OVER (
        PARTITION BY d.dept_name
        ORDER BY SUM(a.actual_amount - b.budget_amount) DESC
    )                                               AS account_rank_within_dept

FROM budget b
    JOIN actuals     a ON  b.dept_id    = a.dept_id
                       AND b.account_id = a.account_id
                       AND b.month      = a.month
    JOIN departments d ON  b.dept_id    = d.dept_id
    JOIN gl_accounts g ON  b.account_id = g.account_id

WHERE g.account_type = 'EXPENSE'

-- GROUP BY at dept + account level — one row per combination.
-- Part A grouped by dept_name only (one row per department).
-- Part B groups by dept + account (one row per account per dept).
GROUP BY
    d.dept_name,
    g.account_code,
    g.account_name

ORDER BY
    d.dept_name,
    account_rank_within_dept;
