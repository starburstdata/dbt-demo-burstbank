with payments as (
    select
        custkey,
        count(payment_date)       as total_payments,
        count_if(is_delinquent)   as delinquent_payments
    from {{ ref('fct_payments') }}
    group by 1
),

-- Current outstanding balance per product, from the account record. Not summed
-- from fct_payments: its `balance` is the running balance at each payment, so
-- adding it up counts the same balance once per payment.
balances as (
    select
        custkey,
        sum(coalesce(cc_balance, 0))         as cc_balance,
        sum(coalesce(mortgage_balance, 0))   as mortgage_balance,
        sum(coalesce(auto_loan_balance, 0))  as auto_loan_balance
    from {{ ref('stg_accounts') }}
    group by 1
)

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
    coalesce(p.total_payments, 0)                                   as total_payments,
    coalesce(p.delinquent_payments, 0)                              as delinquent_payments,
    cast(p.delinquent_payments as double)
        / nullif(p.total_payments, 0)                               as delinquency_rate,
    coalesce(b.cc_balance, 0)                                       as cc_balance,
    coalesce(b.mortgage_balance, 0)                                 as mortgage_balance,
    coalesce(b.auto_loan_balance, 0)                                as auto_loan_balance
from {{ ref('dim_customers') }} c
left join payments p on c.custkey = p.custkey
left join balances b on c.custkey = b.custkey
