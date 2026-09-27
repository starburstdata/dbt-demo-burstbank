{{ config(materialized=var('crm_bronze_materialization')) }}

select
    cast(customer_id as varchar)     as customer_id,
    cast(activity_month as date)     as activity_month,
    cast(logins as integer)          as logins,
    cast(bill_pay_events as integer) as bill_pay_events,
    cast(app_rating as integer)      as app_rating
from {{ crm_table('crm_digital_activity') }}
