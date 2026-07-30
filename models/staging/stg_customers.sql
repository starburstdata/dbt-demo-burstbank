select
    custkey,
    first_name,
    last_name,
    street,
    city,
    state,
    postcode,
    country,
    phone,
    try_cast(dob as date)               as date_of_birth,
    gender,
    married = 'Y'                       as is_married,
    ssn,
    paycheck_dd = 'Y'                   as has_direct_deposit,
    estimated_income,
    fico,
    try_cast(registration_date as date) as registration_date
from {{ source('burstbank', 'customer') }}
