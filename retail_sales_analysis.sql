
-- ============================================================
-- SOUTH AFRICAN RETAIL SALES ANALYSIS
-- Data source: Statistics South Africa
-- Database: sa_retail_analysis
-- Table: public.retail_sales_import
-- Period: January 2002 - June 2026
-- Tools: PostgreSQL, DBeaver
-- ============================================================


-- ============================================================
-- ANALYSIS 1: EXPLORE RETAIL SERIES AND RECORD COUNTS
-- ============================================================

SELECT
    h04,
    h05,
    h15,
    h16,
    h17,
    COUNT(*) AS records
FROM public.retail_sales_import
GROUP BY h04, h05, h15, h16, h17
ORDER BY h04, h05, h15, h16, h17;


-- ============================================================
-- ANALYSIS 2: RETRIEVE MONTHLY TOTAL RETAIL SALES
-- Constant prices, actual values
-- ============================================================

SELECT
    period_date,
    sales_value
FROM public.retail_sales_import
WHERE h16 = 'Actual values'
  AND h04 = 'Total'
  AND h15 = 'At constant prices'
ORDER BY period_date;


-- ============================================================
-- ANALYSIS 3: MONTH-ON-MONTH SERIES AND YEAR-ON-YEAR GROWTH
-- Compares each month with the same month in the previous year
-- ============================================================

SELECT
    period_date,
    sales_value,
    LAG(sales_value, 12) OVER (
        ORDER BY period_date
    ) AS sales_same_month_last_year,
    ROUND(
        (
            (sales_value - LAG(sales_value, 12) OVER (
                ORDER BY period_date
            ))
            / NULLIF(LAG(sales_value, 12) OVER (
                ORDER BY period_date
            ), 0)
        ) * 100,
        2
    ) AS yoy_growth_pct
FROM public.retail_sales_import
WHERE h04 = 'Total'
  AND h15 = 'At constant prices'
  AND h16 = 'Actual values'
ORDER BY period_date;


-- ============================================================
-- ANALYSIS 4: ANNUAL RETAIL SALES TOTALS
-- ============================================================

SELECT
    EXTRACT(YEAR FROM period_date) AS sales_year,
    SUM(sales_value) AS annual_sales_million
FROM public.retail_sales_import
WHERE h04 = 'Total'
  AND h15 = 'At constant prices'
  AND h16 = 'Actual values'
GROUP BY EXTRACT(YEAR FROM period_date)
ORDER BY sales_year;


-- ============================================================
-- ANALYSIS 5: ANNUAL SALES AND YEAR-ON-YEAR GROWTH
-- Includes the number of months recorded in each year
-- ============================================================

WITH annual_sales AS (
    SELECT
        EXTRACT(YEAR FROM period_date)::INT AS sales_year,
        SUM(sales_value) AS annual_sales_million,
        COUNT(*) AS months_recorded
    FROM public.retail_sales_import
    WHERE h04 = 'Total'
      AND h15 = 'At constant prices'
      AND h16 = 'Actual values'
    GROUP BY EXTRACT(YEAR FROM period_date)
),
annual_growth AS (
    SELECT
        sales_year,
        annual_sales_million,
        months_recorded,
        LAG(annual_sales_million) OVER (
            ORDER BY sales_year
        ) AS previous_year_sales
    FROM annual_sales
)
SELECT
    sales_year,
    months_recorded,
    ROUND(annual_sales_million, 2) AS annual_sales_million,
    ROUND(
        (annual_sales_million - previous_year_sales)
        / NULLIF(previous_year_sales, 0) * 100,
        2
    ) AS annual_growth_pct
FROM annual_growth
ORDER BY sales_year;


-- ============================================================
-- ANALYSIS 6: RANK STRONGEST AND WEAKEST FULL YEARS
-- Only ranks years with all 12 months recorded
-- ============================================================

WITH annual_sales AS (
    SELECT
        EXTRACT(YEAR FROM period_date)::INT AS sales_year,
        SUM(sales_value) AS annual_sales_million,
        COUNT(*) AS months_recorded
    FROM public.retail_sales_import
    WHERE h04 = 'Total'
      AND h15 = 'At constant prices'
      AND h16 = 'Actual values'
    GROUP BY EXTRACT(YEAR FROM period_date)
),
annual_growth AS (
    SELECT
        sales_year,
        annual_sales_million,
        months_recorded,
        LAG(annual_sales_million) OVER (
            ORDER BY sales_year
        ) AS previous_year_sales
    FROM annual_sales
),
ranked_years AS (
    SELECT
        sales_year,
        months_recorded,
        ROUND(
            (
                (annual_sales_million - previous_year_sales)
                / NULLIF(previous_year_sales, 0)
            ) * 100,
            2
        ) AS annual_growth_pct
    FROM annual_growth
    WHERE months_recorded = 12
)
SELECT
    sales_year,
    annual_growth_pct
FROM ranked_years
WHERE annual_growth_pct IS NOT NULL
ORDER BY annual_growth_pct DESC;


-- ============================================================
-- ANALYSIS 7: COMPARE RETAIL CATEGORIES
-- Average, minimum and maximum monthly sales
-- ============================================================

SELECT
    h05 AS retail_category,
    COUNT(*) AS months_recorded,
    ROUND(AVG(sales_value), 2) AS average_monthly_sales,
    ROUND(MIN(sales_value), 2) AS lowest_monthly_sales,
    ROUND(MAX(sales_value), 2) AS highest_monthly_sales
FROM public.retail_sales_import
WHERE h04 = 'Type of dealer'
  AND h15 = 'At constant prices'
  AND h16 = 'Actual values'
GROUP BY h05
ORDER BY average_monthly_sales DESC;


-- ============================================================
-- ANALYSIS 8: CATEGORY SALES CHANGE OVER THE AVAILABLE PERIOD
-- Compares each category's first and last recorded values
-- ============================================================

WITH category_sales AS (
    SELECT
        h05 AS retail_category,
        period_date,
        sales_value,
        FIRST_VALUE(sales_value) OVER (
            PARTITION BY h05
            ORDER BY period_date
        ) AS first_sales,
        LAST_VALUE(sales_value) OVER (
            PARTITION BY h05
            ORDER BY period_date
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND UNBOUNDED FOLLOWING
        ) AS last_sales
    FROM public.retail_sales_import
    WHERE h04 = 'Type of dealer'
      AND h15 = 'At constant prices'
      AND h16 = 'Actual values'
)
SELECT DISTINCT
    retail_category,
    ROUND(first_sales, 2) AS first_month_sales,
    ROUND(last_sales, 2) AS last_month_sales,
    ROUND(
        (last_sales - first_sales)
        / NULLIF(first_sales, 0) * 100,
        2
    ) AS total_change_pct
FROM category_sales
ORDER BY total_change_pct DESC;


-- ============================================================
-- ANALYSIS 9: MONTHLY SEASONALITY
-- Average sales by calendar month across all available years
-- ============================================================

SELECT
    EXTRACT(MONTH FROM period_date) AS month_number,
    TO_CHAR(period_date, 'Month') AS month_name,
    ROUND(AVG(sales_value), 2) AS average_sales
FROM public.retail_sales_import
WHERE h04 = 'Total'
  AND h15 = 'At constant prices'
  AND h16 = 'Actual values'
GROUP BY
    EXTRACT(MONTH FROM period_date),
    TO_CHAR(period_date, 'Month')
ORDER BY month_number;


-- ============================================================
-- DATA QUALITY CHECK 1: DUPLICATE MONTHS
-- Expected result: zero rows
-- ============================================================

SELECT
    period_date,
    COUNT(*) AS records
FROM public.retail_sales_import
WHERE h04 = 'Total'
  AND h15 = 'At constant prices'
  AND h16 = 'Actual values'
GROUP BY period_date
HAVING COUNT(*) <> 1
ORDER BY period_date;


-- ============================================================
-- DATA QUALITY CHECK 2: MISSING MONTHS
-- Expected result: zero rows for January 2002-June 2026
-- ============================================================

WITH monthly_data AS (
    SELECT DISTINCT period_date
    FROM public.retail_sales_import
    WHERE h04 = 'Total'
      AND h15 = 'At constant prices'
      AND h16 = 'Actual values'
),
expected_months AS (
    SELECT generate_series(
        DATE '2002-01-01',
        DATE '2026-06-01',
        INTERVAL '1 month'
    )::date AS expected_date
)
SELECT expected_date AS missing_month
FROM expected_months
LEFT JOIN monthly_data
    ON expected_months.expected_date = monthly_data.period_date
WHERE monthly_data.period_date IS NULL
ORDER BY expected_date;


-- ============================================================
-- DATA QUALITY CHECK 3: MISSING SALES VALUES
-- Expected result: 294 total, 294 with sales, 0 missing
-- ============================================================

SELECT
    COUNT(*) AS total_records,
    COUNT(sales_value) AS records_with_sales,
    COUNT(*) - COUNT(sales_value) AS missing_sales_values
FROM public.retail_sales_import
WHERE h04 = 'Total'
  AND h15 = 'At constant prices'
  AND h16 = 'Actual values';
