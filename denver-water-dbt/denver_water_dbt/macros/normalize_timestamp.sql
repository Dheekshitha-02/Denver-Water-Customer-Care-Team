{#
  Normalize a timestamp-like source column to a UTC TIMESTAMP (no time zone).

  Snowflake: Fivetran types these columns TIMESTAMP_TZ (verified in Step 0);
             the cast to timestamp_tz also accepts ISO strings.
  DuckDB:    the connector debug warehouse stores ISO strings (VARCHAR), some
             with a trailing 'Z' and some naive. Naive values are read as UTC
             because profiles.yml sets TimeZone = UTC for the dev target.
#}
{% macro normalize_timestamp(expr) %}
  {{ return(adapter.dispatch('normalize_timestamp', 'denver_water_dbt')(expr)) }}
{% endmacro %}

{% macro default__normalize_timestamp(expr) %}
cast(convert_timezone('UTC', cast({{ expr }} as timestamp_tz)) as timestamp_ntz)
{% endmacro %}

{% macro duckdb__normalize_timestamp(expr) %}
cast(timezone('UTC', try_cast({{ expr }} as timestamptz)) as timestamp)
{% endmacro %}


{#
  Normalize a date-like source column to DATE.

  Snowflake: CC&B date columns are already DATE (verified in Step 0).
  DuckDB:    stored as 'YYYY-MM-DD' strings; unparseable values become NULL.
#}
{% macro normalize_date(expr) %}
  {{ return(adapter.dispatch('normalize_date', 'denver_water_dbt')(expr)) }}
{% endmacro %}

{% macro default__normalize_date(expr) %}
cast({{ expr }} as date)
{% endmacro %}

{% macro duckdb__normalize_date(expr) %}
try_cast({{ expr }} as date)
{% endmacro %}
