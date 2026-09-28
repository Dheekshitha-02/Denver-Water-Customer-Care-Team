{#
  Trim space / tab / CR / LF from both ends.
  DuckDB and Snowflake both use TRIM(expr, characters), not the SQL-Server
  TRIM(characters FROM expr) form.
#}
{% macro full_trim(expr) %}
  {{ return(adapter.dispatch('full_trim', 'denver_water_dbt')(expr)) }}
{% endmacro %}

{% macro default__full_trim(expr) %}
trim({{ expr }}, chr(32) || chr(9) || chr(13) || chr(10))
{% endmacro %}
