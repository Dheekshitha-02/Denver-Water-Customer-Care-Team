{#
  Contact-point normalization shared by Genesys interactions and CC&B persons,
  so the customer match compares like with like.

  normalize_phone: digits only; a leading US country code '1' on an 11-digit
                   number is dropped; empty results become NULL.
  normalize_email: lower-cased and trimmed; empty results become NULL.
#}
{% macro normalize_phone(expr) %}
  {{ return(adapter.dispatch('normalize_phone', 'denver_water_dbt')(expr)) }}
{% endmacro %}

{% macro default__normalize_phone(expr) %}
{%- set digits = "regexp_replace(cast(" ~ expr ~ " as varchar), '[^0-9]', '')" -%}
case
    when length({{ digits }}) = 11 and left({{ digits }}, 1) = '1' then substr({{ digits }}, 2)
    else nullif({{ digits }}, '')
end
{% endmacro %}

{% macro duckdb__normalize_phone(expr) %}
{%- set digits = "regexp_replace(cast(" ~ expr ~ " as varchar), '[^0-9]', '', 'g')" -%}
case
    when length({{ digits }}) = 11 and left({{ digits }}, 1) = '1' then substr({{ digits }}, 2)
    else nullif({{ digits }}, '')
end
{% endmacro %}

{% macro normalize_email(expr) %}
nullif(lower(trim(cast({{ expr }} as varchar))), '')
{% endmacro %}
