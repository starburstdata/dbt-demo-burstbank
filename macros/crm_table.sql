{#
    The CRM table a bronze model reads, chosen by the crm_mode var:

    - postgres: the live table, through the `crm` source (federated).
    - seed:     the seed loaded by `dbt seed`, through ref().

    Seed mode has to use ref() rather than a source pointed at the seed's
    schema. With a source, dbt doesn't know the model depends on the seed, so
    `dbt build` can create the view, or run its tests, before or while the seed
    is being loaded -- and fail on a table that doesn't exist yet.
#}
{% macro crm_table(name) -%}
    {%- if var('crm_mode') == 'postgres' -%}
        {{ source('crm', name) }}
    {%- elif var('crm_mode') == 'seed' -%}
        {{ ref(name) }}
    {%- else -%}
        {{ exceptions.raise_compiler_error("crm_mode must be 'postgres' or 'seed', got: " ~ var('crm_mode')) }}
    {%- endif -%}
{%- endmacro %}
