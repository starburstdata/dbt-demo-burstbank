{#
    dbt-trino's create statement for materialized views, plus a refresh.

    Trino creates a materialized view without storing its results: until the
    first REFRESH it is stale, and every query reads the source tables instead.
    dbt-trino only refreshes on later runs, so without this a fresh `dbt build`
    would leave each materialized view unmaterialized until the build after.
    The body otherwise matches dbt-trino 1.10.5's
    trino__get_create_materialized_view_as_sql.
#}
{%- macro trino__get_create_materialized_view_as_sql(target_relation, sql) -%}
  create materialized view {{ target_relation }}
  {%- set grace_period = config.get('grace_period') %}
  {%- if grace_period is not none %}
    grace period {{ grace_period }}
  {%- endif %}
    {{ properties() }}
  as
  {{ sql }}
  ;
  refresh materialized view {{ target_relation }};
{%- endmacro -%}
