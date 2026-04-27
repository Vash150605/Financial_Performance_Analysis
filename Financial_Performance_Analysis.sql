CREATE TABLE financial_table (
    company_id          INT,
    company_name        VARCHAR(150),
    industry            VARCHAR(60),
    region              VARCHAR(60),
    country             VARCHAR(60),
    year                SMALLINT,
    quarter             SMALLINT,
    month               SMALLINT,
    revenue             NUMERIC(18,2),
    cost                NUMERIC(18,2),
    operating_expenses  NUMERIC(18,2),
    esg_score           NUMERIC(6,2),
    environmental_score NUMERIC(6,2),
    social_score        NUMERIC(6,2),
    governance_score    NUMERIC(6,2),
    debt_to_equity      NUMERIC(8,4),
    roe                 NUMERIC(8,4),
    roa                 NUMERIC(8,4)
);

-- Calculated Columns
ALTER TABLE financial_table
    ADD COLUMN gross_profit        NUMERIC(18,2),
    ADD COLUMN net_profit          NUMERIC(18,2),
    ADD COLUMN gross_margin_pct    NUMERIC(8,2),
    ADD COLUMN net_margin_pct      NUMERIC(8,2),
    ADD COLUMN cost_revenue_ratio  NUMERIC(8,4),
    ADD COLUMN opex_revenue_ratio  NUMERIC(8,4),
    ADD COLUMN esg_tier            VARCHAR(20),
    ADD COLUMN profit_risk_profile VARCHAR(40),
    ADD COLUMN leverage_flag       VARCHAR(20),
    ADD COLUMN performance_flag    VARCHAR(20),
    ADD COLUMN revenue_outlier_flag VARCHAR(20);

--Profit figures
UPDATE financial_table SET
    gross_profit = revenue - cost,
    net_profit   = revenue - cost - operating_expenses
WHERE revenue IS NOT NULL
  AND cost IS NOT NULL
  AND operating_expenses IS NOT NULL;

--Margin and ratio percentages
UPDATE financial_table SET
    gross_margin_pct   = ROUND(((revenue - cost) / NULLIF(revenue,0)) * 100, 2),
    net_margin_pct     = ROUND(((revenue - cost - operating_expenses) / NULLIF(revenue,0)) * 100, 2),
    cost_revenue_ratio = ROUND(cost / NULLIF(revenue,0), 4),
    opex_revenue_ratio = ROUND(operating_expenses / NULLIF(revenue,0), 4)
WHERE revenue IS NOT NULL;

--ESG tier
UPDATE financial_table SET
    esg_tier = CASE
        WHEN esg_score >= 75 THEN 'High ESG'
        WHEN esg_score >= 50 THEN 'Medium ESG'
        WHEN esg_score >= 25 THEN 'Low ESG'
        ELSE 'Very Low ESG'
    END
WHERE esg_score IS NOT NULL;

--Profit/risk profile 
UPDATE financial_table SET
    profit_risk_profile = CASE
        WHEN net_margin_pct > 15 AND esg_score < 50  THEN 'High Profit / High Risk'
        WHEN net_margin_pct > 15 AND esg_score >= 75 THEN 'High Profit / Low Risk'
        WHEN net_margin_pct > 15                     THEN 'High Profit / Medium Risk'
        WHEN net_margin_pct >= 0 AND esg_score < 50  THEN 'Moderate Profit / High Risk'
        WHEN net_margin_pct < 0                      THEN 'Loss Making'
        ELSE 'Standard'
    END
WHERE net_margin_pct IS NOT NULL AND esg_score IS NOT NULL;

-- Leverage flag
UPDATE financial_table SET
    leverage_flag = CASE
        WHEN debt_to_equity > 2.5  THEN 'High Leverage'
        WHEN debt_to_equity > 1.5  THEN 'Medium Leverage'
        WHEN debt_to_equity <= 1.5 THEN 'Low Leverage'
    END
WHERE debt_to_equity IS NOT NULL;

--Performance flag
UPDATE financial_table SET
    performance_flag = CASE
        WHEN roa < 0  THEN 'Distressed'
        WHEN roa < 3  THEN 'Underperforming'
        WHEN roa < 8  THEN 'Normal'
        ELSE 'Strong'
    END
WHERE roa IS NOT NULL;

--Revenue outlier flag
UPDATE financial_table fe
SET revenue_outlier_flag = CASE
    WHEN fe.revenue > (
        SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY revenue)
             + 1.5 * (  PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY revenue)
                      - PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY revenue))
        FROM financial_table WHERE revenue IS NOT NULL
    ) THEN 'Outlier'
    ELSE 'Normal'
END
WHERE revenue IS NOT NULL;

--Verifying everything
SELECT
    company_name,
    gross_margin_pct,
    net_margin_pct,
    esg_tier,
    profit_risk_profile,
    leverage_flag,
    performance_flag,
    revenue_outlier_flag
FROM financial_table
LIMIT 20;

SELECT * FROM financial_table;