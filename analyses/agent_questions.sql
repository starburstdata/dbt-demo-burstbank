-- Q1: How many high-risk customers do we have, and what's their total balance exposure?
select retention_risk_tier, count(*) as customers, sum(total_outstanding_balance) as exposure_usd
from {{ ref('dp_customer_retention_risk') }}
group by 1
order by 3 desc;

-- Q2: Which country has the most high-risk customers?
select country, count(*) as high_risk_customers
from {{ ref('dp_customer_retention_risk') }}
where retention_risk_tier = 'high'
group by 1
order by 2 desc;

-- Q3: Which 3 mortgage holders' app engagement dropped the most?
-- Top 3 rather than a longer list: further down, several customers tie on the
-- same drop, so a top 10 has more than one correct answer.
select d.custkey, d.engagement_drop_pct, r.mortgage_balance
from {{ ref('dp_customer_retention_risk') }} d
join {{ ref('rpt_customer_risk') }} r on d.custkey = r.custkey
where r.mortgage_balance > 0
order by d.engagement_drop_pct desc, r.mortgage_balance desc
limit 3;
