select
    abbreviation,
    name                                    as state_name,
    region,
    division,
    try_cast(popestimate2019 as bigint)     as population_2019,
    try_cast(popest18plus2019 as bigint)    as population_18plus_2019,
    try_cast(pcnt_popest18plus as double)   as pct_population_18plus
from {{ source('burstbank', 'state_census') }}
-- state-level rows only; removes national/region/division summary rows. Compared
-- as a number: the source stores 40, not '040', so a string match drops every row.
where cast(sumlev as integer) = 40
