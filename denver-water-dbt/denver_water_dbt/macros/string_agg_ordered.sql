{#
  Ordered string aggregation.
  separator: 'blank_line' (default, two newlines) | 'line' (one newline) | 'semicolon' ('; ')

  DuckDB:    string_agg(expr, <sep> order by ...)
  Snowflake: listagg(expr, <sep>) within group (order by ...)

  Snowflake's LISTAGG requires a CONSTANT delimiter, so chr(10)||chr(10) is
  rejected there; the '\n' literals are constant and parse as real newlines.
#}
{% macro string_agg_ordered(expr, order_by, separator='blank_line') %}
  {{ return(adapter.dispatch('string_agg_ordered', 'denver_water_dbt')(expr, order_by, separator)) }}
{% endmacro %}

{% macro default__string_agg_ordered(expr, order_by, separator) %}
{%- set sep = {'blank_line': "'\\n\\n'", 'line': "'\\n'", 'semicolon': "'; '"}[separator] -%}
listagg({{ expr }}, {{ sep }}) within group (order by {{ order_by }})
{% endmacro %}

{% macro duckdb__string_agg_ordered(expr, order_by, separator) %}
{%- set sep = {'blank_line': "chr(10) || chr(10)", 'line': "chr(10)", 'semicolon': "'; '"}[separator] -%}
string_agg({{ expr }}, {{ sep }} order by {{ order_by }})
{% endmacro %}
