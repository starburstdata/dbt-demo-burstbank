select
    profilekey,
    custkey,
    career,
    professional_status,
    risk_appetite,
    customer_segment
from {{ source('burstbank', 'customer_profile') }}
