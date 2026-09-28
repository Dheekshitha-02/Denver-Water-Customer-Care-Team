{% macro markdown_link(name_expr, url_expr) %}
case
    when {{ name_expr }} is null or trim(cast({{ name_expr }} as varchar)) = '' then ''
    when {{ url_expr }} is null or trim(cast({{ url_expr }} as varchar)) = '' then cast({{ name_expr }} as varchar)
    else '['
        || replace(cast({{ name_expr }} as varchar), ']', '\]')
        || ']('
        || cast({{ url_expr }} as varchar)
        || ')'
end
{% endmacro %}
