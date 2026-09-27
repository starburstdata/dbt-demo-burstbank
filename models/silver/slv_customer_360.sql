{#- The windows below are measured from as_of_date (dbt_project.yml), not
    current_date, so results don't drift with the calendar. Checked for strict
    YYYY-MM-DD form before it's spliced into SQL. -#}
{%- set as_of_date = var('as_of_date') | string -%}
{%- if not modules.re.match('^\d{4}-\d{2}-\d{2}$', as_of_date) -%}
    {{ exceptions.raise_compiler_error("as_of_date must be YYYY-MM-DD, got: " ~ as_of_date) }}
{%- endif -%}
{%- set as_of = "date '" ~ as_of_date ~ "'" -%}

with core as (
    select * from {{ ref('dim_customers') }}
),

interactions as (
    -- the 90 days up to and including as_of_date
    select
        customer_id,
        count(*)                            as interactions_90d,
        count_if(is_complaint)              as complaints_90d,
        count_if(reason = 'close_account')  as close_account_requests_90d,
        avg(sentiment_score)                as avg_sentiment_90d
    from {{ ref('bronze_crm_interactions') }}
    where interaction_ts >= cast({{ as_of }} as timestamp) - interval '90' day
      and interaction_ts <  cast({{ as_of }} as timestamp) + interval '1' day
    group by 1
),

digital as (
    -- activity_month is always the first of the month, so the windows are
    -- whole calendar months: the 3 complete months before as_of_date's month,
    -- and the 3 before those. A raw date_add cutoff would land mid-month and
    -- give the two windows a different number of months -- every steady
    -- customer would then look like they had dropped off.
    select
        customer_id,
        sum(logins) filter (
            where activity_month >= date_trunc('month', date_add('month', -3, {{ as_of }}))
              and activity_month <  date_trunc('month', {{ as_of }})
        ) as logins_last_3m,
        sum(logins) filter (
            where activity_month >= date_trunc('month', date_add('month', -6, {{ as_of }}))
              and activity_month <  date_trunc('month', date_add('month', -3, {{ as_of }}))
        ) as logins_prior_3m
    from {{ ref('bronze_crm_digital_activity') }}
    group by 1
)

select
    core.*,
    coalesce(i.interactions_90d, 0)            as interactions_90d,
    coalesce(i.complaints_90d, 0)              as complaints_90d,
    coalesce(i.close_account_requests_90d, 0)  as close_account_requests_90d,
    i.avg_sentiment_90d,
    coalesce(d.logins_last_3m, 0)              as logins_last_3m,
    coalesce(d.logins_prior_3m, 0)             as logins_prior_3m
from core
left join interactions i on core.custkey = i.customer_id
left join digital      d on core.custkey = d.customer_id
