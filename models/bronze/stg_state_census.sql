select
    abbreviation,
    name                                    as state_name,
    region,
    division,
    try_cast(popestimate2019 as bigint)     as population_2019,
    try_cast(popest18plus2019 as bigint)    as population_18plus_2019,
    try_cast(pcnt_popest18plus as double)   as pct_population_18plus
from {{ source('burstbank', 'state_census') }}
where sumlev = '040'  -- state-level rows only; removes national/region/division summary rows
