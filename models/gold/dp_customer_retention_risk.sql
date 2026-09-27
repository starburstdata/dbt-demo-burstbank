{{ config(materialized='table') }}

with c as (select * from {{ ref('slv_customer_360') }}),
     r as (select * from {{ ref('rpt_customer_risk') }}),

base as (
    select
        c.custkey,
        c.state,
        c.country,
        c.customer_segment                                  as segment,
        cast(r.delinquency_rate as double)                  as delinquency_rate,
        cast(r.cc_balance + r.mortgage_balance + r.auto_loan_balance as decimal(18, 2)) as total_outstanding_balance,
        c.complaints_90d,
        c.close_account_requests_90d,
        cast(case when c.logins_prior_3m = 0 then 0
                  else greatest(least(1.0e0 - (cast(c.logins_last_3m as double) / c.logins_prior_3m), 1), 0)
             end as double)                                 as engagement_drop_pct
    from c
    join r on c.custkey = r.custkey
)

-- Ratios are computed in double: in Trino a literal like 1.0 or 3.0 is a
-- one-decimal DECIMAL, which would round e.g. a 64.3% login drop to 60%.
--
-- Delinquency thresholds are set from sample.burstbank's actual distribution
-- (median ~3%, 99th percentile ~7%, max under 10%), so payment history moves
-- customers between tiers alongside the CRM signals. The weights are
-- illustrative, not a fitted model.
select
    *,
    cast(least(100,
          40 * least(delinquency_rate / 0.08, 1)             -- full weight at 8%+ late
        + 25 * least(complaints_90d / 3e0, 1)
        + 20 * least(close_account_requests_90d, 1)
        + 15 * engagement_drop_pct
    ) as integer)                                           as retention_risk_score,
    -- cast to unbounded varchar: the case expression alone types as
    -- varchar(6) (the longest literal), which the enforced contract's
    -- `varchar` would not match.
    cast(case
        when delinquency_rate >= 0.07 or close_account_requests_90d > 0 then 'high'
        when complaints_90d >= 2 or delinquency_rate >= 0.05            then 'medium'
        else 'low'
    end as varchar)                                         as retention_risk_tier
from base
