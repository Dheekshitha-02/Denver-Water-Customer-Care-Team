{#
  Format a timestamp-like expression as a string.
  precision: 'date' -> YYYY-MM-DD
             'datetime_minute' -> YYYY-MM-DD HH:MM
#}
{% macro format_ts(expr, precision='date') %}
  {{ return(adapter.dispatch('format_ts', 'denver_water_dbt')(expr, precision)) }}
{% endmacro %}

{% macro default__format_ts(expr, precision) %}
{%- if precision == 'datetime_minute' -%}
to_char(try_cast({{ expr }} as timestamp), 'YYYY-MM-DD HH24:MI')
{%- else -%}
to_char(try_cast({{ expr }} as timestamp), 'YYYY-MM-DD')
{%- endif -%}
{% endmacro %}

{% macro duckdb__format_ts(expr, precision) %}
{%- if precision == 'datetime_minute' -%}
strftime(try_cast({{ expr }} as timestamp), '%Y-%m-%d %H:%M')
{%- else -%}
strftime(try_cast({{ expr }} as timestamp), '%Y-%m-%d')
{%- endif -%}
{% endmacro %}

{#
  Snowflake rejects TRY_CAST from TIMESTAMP_TZ / DATE, so normalize via varchar:
  to_varchar accepts a timestamp, date or string, and try_to_timestamp parses it
  (NULL on failure).
#}
{% macro snowflake__format_ts(expr, precision) %}
{%- if precision == 'datetime_minute' -%}
to_char(try_to_timestamp(to_varchar({{ expr }})), 'YYYY-MM-DD HH24:MI')
{%- else -%}
to_char(try_to_timestamp(to_varchar({{ expr }})), 'YYYY-MM-DD')
{%- endif -%}
{% endmacro %}
