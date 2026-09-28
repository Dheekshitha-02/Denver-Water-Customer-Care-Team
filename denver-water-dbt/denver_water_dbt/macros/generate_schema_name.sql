{#
  Use a model's configured schema verbatim instead of dbt's default
  "<target_schema>_<custom_schema>" concatenation, so intermediates, AI exports
  and validation views land in DENVER_DBT_INT / DENVER_AI / DENVER_DBT_VALIDATION
  exactly (and any later alias='export' model can land in a connector schema).

  Models with no custom schema fall back to the run's target schema, unchanged.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
