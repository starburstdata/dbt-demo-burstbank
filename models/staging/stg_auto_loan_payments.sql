select
    auto_loan_id,
    try_cast(payment_date as date)      as payment_date,
    payment_amount,
    try_cast(payment_due_date as date)  as payment_due_date,
    delinquent_payment = 'Y'            as is_delinquent,
    balance
from {{ source('burstbank', 'auto_loan_payment') }}
