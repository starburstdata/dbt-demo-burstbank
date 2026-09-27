select
    custkey,
    product_type,
    product_id,
    payment_date,
    payment_amount,
    payment_due_date,
    is_late      as is_delinquent,
    balance
from {{ ref('slv_payments') }}
