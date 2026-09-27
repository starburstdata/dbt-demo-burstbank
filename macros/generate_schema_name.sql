{#
    Use the +schema values from dbt_project.yml verbatim.

    dbt's default generate_schema_name prefixes them with the profile's
    schema, which would put the medallion layers in
    lakehouse.burstbank_dbt_burstbank_bronze / _silver / _gold. The README,
    WORKSHOP.md and the workshop's verification queries all expect the plain
    names: lakehouse.burstbank_bronze, _silver, _gold, and burstbank_crm_seed
    for `dbt seed`.

    Trade-off: this removes the per-developer isolation you get from dbt's
    default, where each person's profile `schema:` prefixes their output. The
    workshop gives every attendee their own Galaxy trial account, so there is
    nothing to collide with. If you ever run this project with several people
    writing to one catalog, delete this macro and use the doubled schema names
    instead.

    Models with no custom +schema still fall back to the profile's schema.
#}

{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}

{%- endmacro %}
