# SQL Finance Expense Variance Reporting — Mazaya Retail Group

An end to end SQL analysis project simulating the finance expense variance reporting workflow for a retail and e-commerce company. Built in PostgreSQL using pgAdmin.

---

## Business Context

Mazaya Retail Group operates across four business units Marketing, Store Operations, Logistics & Warehouse, and E-Commerce & Technology. The finance team tracks monthly actuals against annual budgets across nine GL accounts covering both expense and revenue lines.

This showcases the workflow of pulling budget and actuals data from a finance system, structuring it into a relational model, and answering the key questions a CFO or finance manager would ask at month end and year end:

- Are departments spending within their approved budgets?
- Which accounts have materially breached the acceptable variance threshold?
- When exactly did the breach begin and which months are driving it?
- Which departments are the worst offenders by total expense overspend?

---

## Database Schema

The analysis is built across four related tables:

| Table | Description | Rows |
|---|---|---|
| `departments` | Master list of 6 business units | 6 |
| `gl_accounts` | Chart of accounts — 7 expense and 3 revenue accounts | 10 |
| `budget` | Monthly budgeted amounts per department per GL account for 2024 | 120 |
| `actuals` | Monthly actual amounts per department per GL account for 2024 | 120 |

**Relationships:**
- `departments` → `budget` (one to many on `dept_id`)
- `departments` → `actuals` (one to many on `dept_id`)
- `gl_accounts` → `budget` (one to many on `account_id`)
- `gl_accounts` → `actuals` (one to many on `account_id`)

**Grain:** `dept_id + account_id + month` one row per department, GL account, and period in both the budget and actuals tables. All JOINs between the two tables enforce this three-column grain to prevent cartesian products.

---

## Analysis Queries & SQL Techniques

### Q1 — Monthly Performance: All Accounts
*How is each department performing against budget across all account types on a month by month basis?*

Joins all four tables and calculates variance amount and percentage per department, account, and month. CASE WHEN logic is account type aware a revenue account beating budget is classified as OVER TARGET while the same positive variance on an expense account is classified as OVER BUDGET.

**Techniques:** Multi table JOIN on composite grain · Calculated columns · Account type aware CASE WHEN · NULLIF for division by zero protection

---

### Q2 — Monthly Performance: Expense Accounts Only
*How are expense accounts specifically tracking against budget each month?*

Filters to expense accounts using WHERE before aggregation. CASE WHEN logic simplifies to two branches OVER BUDGET and UNDER BUDGET since revenue rows are excluded at the filter stage rather than handled in the classification logic.

**Techniques:** WHERE for pre aggregation filtering · Simplified CASE WHEN · ORDER BY variance

---

### Q3 — Annual Expense Summary
*Which expense accounts ended the year over or under budget when the full twelve months are rolled up?*

Aggregates monthly rows to a single annual figure per department and account. Variance percentage calculated on full year totals rather than averaged monthly percentages averaging percentages is a common analytical mistake that produces incorrect results.

**Techniques:** GROUP BY with multiple aggregations · SUM · ROUND · Annual variance percentage on base totals

---

### Q4 — Breach Detection: Accounts Exceeding 5% Threshold
*Which expense accounts have breached the 5% materiality threshold on an annual basis?*

Filters the annual summary to surface only department and account combinations where overspend exceeds 5% of the annual budget the point at which a variance is considered material and requires a management response.

**Techniques:** HAVING for post-aggregation filtering · HAVING vs WHERE distinction · ORDER BY absolute variance amount

---

### Q5 — Monthly Drill-Down on Breaching Accounts
*For the accounts that breached the threshold when exactly did the overspend begin?*

Uses a CTE to dynamically identify the breaching department and account combinations from the annual data, then joins the main query to that CTE to produce a month by month breakdown. The CTE JOIN acts as a dynamic filter automatically capturing any combination that breaches the threshold without hardcoding names or IDs.

**Techniques:** CTE (WITH clause) · INNER JOIN as dynamic filter · HAVING inside CTE · Month level variance and percentage

---

## Key Findings

- **Logistics & Warehouse — Delivery & Fulfilment** recorded the most severe breach — overspending by 24% in both November and December, driven by White Friday and peak season fulfilment volume
- **Marketing — Digital Advertising** breached in Q4, reaching 19% over budget in November as campaign spend accelerated ahead of the year-end retail period
- **E-Commerce & Technology — Software & Subscriptions** showed a mid-year step change from June onward, consistent with a new tool being added — an unbudgeted recurring cost that persisted for the remainder of the year
- **Marketing — Travel & Entertainment** breached annually at 8.3% — modest in absolute terms but flagged by the threshold logic
- **Online Sales Revenue** beat budget by AED 120,000 for the year — E-Commerce outperformed on the revenue line despite overspending on software costs
- **In-Store Sales Revenue** missed target by AED 241,000 — the summer dip in June, July, and August accounts for the majority of the shortfall, consistent with Dubai's seasonal retail pattern

---

## Files

```
├── schema_and_seed_data.sql
└── Solution_script.sql
```

---

## Tools Used

- **PostgreSQL** — database and query execution
- **pgAdmin 4** — query development and result validation
