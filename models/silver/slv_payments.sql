{{
  config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='payment_key',
    on_schema_change='append_new_columns',
    properties={
      "format": "'PARQUET'",
      "partitioning": "ARRAY['month(payment_date)']"
    }
  )
}}

with unioned as (

    select
        'credit_card'     as product_type,
        a.custkey,
        a.cc_number       as product_id,
        p.payment_date,
        p.payment_amount,
        p.payment_due_date,
        p.is_delinquent   as is_late,
        p.balance
    from {{ ref('stg_credit_card_payments') }} p
    inner join {{ ref('stg_accounts') }} a on p.cc_number = a.cc_number

    union all

    select
        'mortgage'        as product_type,
        a.custkey,
        a.mortgage_id     as product_id,
        p.payment_date,
        p.payment_amount,
        p.payment_due_date,
        p.is_delinquent   as is_late,
        p.balance
    from {{ ref('stg_mortgage_payments') }} p
    inner join {{ ref('stg_accounts') }} a on p.mortgage_id = a.mortgage_id

    union all

    select
        'auto_loan'       as product_type,
        a.custkey,
        a.auto_loan_id    as product_id,
        p.payment_date,
        p.payment_amount,
        p.payment_due_date,
        p.is_delinquent   as is_late,
        p.balance
    from {{ ref('stg_auto_loan_payments') }} p
    inner join {{ ref('stg_accounts') }} a on p.auto_loan_id = a.auto_loan_id

)

select
    -- The bronze payment tables carry no payment id, so the key is built from
    -- the columns that identify a payment. payment_amount is included because
    -- product + date alone would collide if an account ever paid twice in one
    -- day -- which would fail the unique test and break the incremental MERGE.
    {{ dbt_utils.generate_surrogate_key(['product_type', 'product_id', 'payment_date', 'payment_amount']) }} as payment_key,
    product_type,
    custkey,
    product_id,
    payment_date,
    payment_amount,
    payment_due_date,
    is_late,
    balance
from unioned

{% if is_incremental() %}
-- >= rather than >, so the most recent day already loaded is re-read on every
-- run and payments that arrived late for that date still land. Re-reading it
-- is safe because the MERGE matches on payment_key: rows already loaded are
-- rewritten with the same values, only genuinely new ones are inserted.
where payment_date >= (select max(payment_date) from {{ this }})
{% endif %}
