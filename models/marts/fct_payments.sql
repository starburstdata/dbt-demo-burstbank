select
    a.custkey,
    'credit_card'       as product_type,
    a.cc_number         as product_id,
    p.payment_date,
    p.payment_amount,
    p.payment_due_date,
    p.is_delinquent,
    p.balance
from {{ ref('stg_credit_card_payments') }} p
inner join {{ ref('stg_accounts') }} a on p.cc_number = a.cc_number

union all

select
    a.custkey,
    'mortgage'          as product_type,
    a.mortgage_id       as product_id,
    p.payment_date,
    p.payment_amount,
    p.payment_due_date,
    p.is_delinquent,
    p.balance
from {{ ref('stg_mortgage_payments') }} p
inner join {{ ref('stg_accounts') }} a on p.mortgage_id = a.mortgage_id

union all

select
    a.custkey,
    'auto_loan'         as product_type,
    a.auto_loan_id      as product_id,
    p.payment_date,
    p.payment_amount,
    p.payment_due_date,
    p.is_delinquent,
    p.balance
from {{ ref('stg_auto_loan_payments') }} p
inner join {{ ref('stg_accounts') }} a on p.auto_loan_id = a.auto_loan_id
