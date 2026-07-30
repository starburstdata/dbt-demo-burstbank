select
    c.custkey,
    c.first_name,
    c.last_name,
    c.customer_segment,
    c.risk_appetite,
    c.fico,
    c.estimated_income,
    c.state,
    c.region,
    count(p.payment_date)                                                       as total_payments,
    count_if(p.is_delinquent)                                                   as delinquent_payments,
    cast(count_if(p.is_delinquent) as double)
        / nullif(count(p.payment_date), 0)                                      as delinquency_rate,
    sum(case when p.product_type = 'credit_card' then p.balance else 0 end)    as cc_balance,
    sum(case when p.product_type = 'mortgage'    then p.balance else 0 end)    as mortgage_balance,
    sum(case when p.product_type = 'auto_loan'   then p.balance else 0 end)    as auto_loan_balance
from {{ ref('dim_customers') }} c
left join {{ ref('fct_payments') }} p on c.custkey = p.custkey
group by 1, 2, 3, 4, 5, 6, 7, 8, 9
