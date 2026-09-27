select
    profilekey,
    custkey,
    cc_type,
    cc_rate,
    mortgage_officer,
    mortgage_duration,
    mortgage_residence_type,
    mortgage_purchase_price,
    mortgage_rate,
    auto_loan_officer,
    auto_loan_duration,
    vehicle_type,
    auto_purchase_price,
    auto_loan_rate
from {{ source('burstbank', 'product_profile') }}
