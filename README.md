# Finance Expense Variance Reporting

**Industry:** Retail / E-Commerce  
**Database:** PostgreSQL  
**Scope:** Full-year (Jan–Dec 2024) actuals vs budget analysis across departments and GL accounts

---

## Overview

This project provides a robust SQL framework for Budget vs. Actual (BvA) Variance Analysis. Designed for a retail environment (Mazaya Retail Group), the system identifies financial performance trends and utilizes a dynamic "Zoom" logic to isolate departments and accounts that are over budget by 5% or more on an annual basis.

---

## Business Questions Answered

- How did each department perform against budget across every GL account and month?
- Which accounts breached the acceptable variance threshold and require escalation?
- Which months triggered the breach and when did the overspend begin?
- Which departments are the worst offenders by total expense overspend?

---

## Schema Design

The project follows a normalized relational schema to ensure data integrity and eliminate redundancy:

- Dimensions: departments and gl_accounts act as the single source of truth for reference data.

- Fact Tables: budget (the plan) and actuals (the reality) store transactional monthly data.

- Data Integrity: Utilizes FOREIGN KEY constraints and SERIAL primary keys to maintain relationships between tables.

---

## Key Features

### Multi-Tiered Performance Categorization

The scripts handle different account behaviors automatically:
- Expenses: Flagged as OVER BUDGET if spending exceeds the plan.
- Revenue: Flagged as OVER TARGET if actual earnings exceed the plan.

### The Dynamic "Zoom" Engine (CTE Approach)

The core of the analysis is a two-table query logic using a Common Table Expression (CTE):
- Phase 1 (Filter): The CTE aggregates the entire year of data to find the specific dept_id and account_id combinations that failed the 5% variance threshold.
- Phase 2 (Detail): The main query performs an INNER JOIN against the CTE, effectively "zooming in" to show a month-by-month breakdown of only the problem accounts.

### Real-World Seed Data

The included seed data covers a full 12-month cycle (Jan–Dec 2024) and simulates realistic business scenarios:
- Q4 Peak Season: Increased delivery and advertising costs in November and December.
- Operational Spikes: Mid-year software subscription updates and travel fluctuations.

---

## Repository Structure

| File | Purpose |
|---|---|
| 01_schema_and_seed_data.sql | Table definitions, constraints, and 12 months of sample data. |
| 02_variance_analysis.sql | The analysis engine containing monthly, annual, and dynamic zoom queries. |
| README.md | Project documentation and usage guide. |

---

## How to Use

- Environment: Run these scripts in a PostgreSQL compatible environment.
- Setup: Execute 01_schema_and_seed_data.sql first to build the database and populate it with the 2024 dataset.
- Analysis: Run 02_variance_analysis.sql to generate reports. The final query in that file will provide the "Zoom" view of high-variance accounts.

---
