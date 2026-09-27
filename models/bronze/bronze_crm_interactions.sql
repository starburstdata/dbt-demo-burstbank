{{ config(materialized=var('crm_bronze_materialization')) }}

select
    cast(interaction_id as varchar)        as interaction_id,
    cast(customer_id as varchar)           as customer_id,
    cast(interaction_ts as timestamp(6))   as interaction_ts,
    lower(channel)                         as channel,        -- call | chat | branch | email
    lower(reason)                          as reason,         -- fees | rates | service | close_account | other
    cast(is_complaint as boolean)          as is_complaint,
    cast(sentiment_score as double)        as sentiment_score -- -1.0 to 1.0
from {{ crm_table('crm_interactions') }}
