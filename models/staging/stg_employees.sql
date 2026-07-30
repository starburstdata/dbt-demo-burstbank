select
    employee_id,
    first_name,
    last_name,
    title,
    manger_id                       as manager_id,  -- typo in source column name
    try_cast(start_date as date)    as start_date,
    street,
    city,
    state,
    postcode,
    country,
    phone,
    try_cast(dob as date)           as date_of_birth
from {{ source('burstbank', 'employee') }}
