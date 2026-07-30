select
    c.custkey,
    c.first_name,
    c.last_name,
    c.city,
    c.state,
    c.country,
    c.date_of_birth,
    c.gender,
    c.is_married,
    c.has_direct_deposit,
    c.estimated_income,
    c.fico,
    c.registration_date,
    cp.career,
    cp.professional_status,
    cp.risk_appetite,
    cp.customer_segment,
    sc.state_name,
    sc.region,
    sc.division,
    sc.population_2019       as state_population_2019
from {{ ref('stg_customers') }} c
left join {{ ref('stg_customer_profiles') }} cp on c.custkey = cp.custkey
left join {{ ref('stg_state_census') }} sc      on c.state = sc.abbreviation
