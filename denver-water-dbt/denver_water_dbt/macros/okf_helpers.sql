{#
  Small builders for OKF markdown bodies. Every piece is null-safe, because a
  single NULL in a || chain nulls the whole document on both DuckDB and Snowflake.
#}

{# "- **Label:** value", or "Not available" when the value is null / blank. #}
{% macro md_line(label, expr) -%}
'- **{{ label }}:** ' || coalesce(nullif(trim(cast({{ expr }} as varchar)), ''), 'Not available')
{%- endmacro %}

{# "$1234.50", or NULL. #}
{% macro md_money(expr) -%}
case when {{ expr }} is null then null else '$' || cast(cast({{ expr }} as decimal(12, 2)) as varchar) end
{%- endmacro %}

{# "Yes" / "No", or NULL. #}
{% macro md_yes_no(expr) -%}
case when {{ expr }} then 'Yes' when not {{ expr }} then 'No' end
{%- endmacro %}

{# Markdown list text, or an italic placeholder when there is none. #}
{% macro md_list_or(expr, placeholder) -%}
coalesce(nullif(trim({{ expr }}), ''), '_{{ placeholder }}_')
{%- endmacro %}
