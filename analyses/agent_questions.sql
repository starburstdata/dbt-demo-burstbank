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

-- Q3: Top 10 customers by engagement drop who also have an open mortgage
select d.custkey, d.engagement_drop_pct, r.mortgage_balance
from {{ ref('dp_customer_retention_risk') }} d
join {{ ref('rpt_customer_risk') }} r on d.custkey = r.custkey
where r.mortgage_balance > 0
order by d.engagement_drop_pct desc
limit 10;
