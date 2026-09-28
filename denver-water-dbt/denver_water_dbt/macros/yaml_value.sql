{% macro yaml_value(expr) %}
case
    when {{ expr }} is null or trim(cast({{ expr }} as varchar)) = '' then ''
    when {% if target.type == 'duckdb' %}regexp_matches{% else %}regexp_like{% endif %}(cast({{ expr }} as varchar), '^[A-Za-z0-9 _./:-]+$')
        then cast({{ expr }} as varchar)
    else '"' || replace(cast({{ expr }} as varchar), '"', '\"') || '"'
end
{% endmacro %}
