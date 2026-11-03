{#
  Use the custom schema name exactly (silver, gold, ref) instead of dbt's default
  "<target_schema>_<custom_schema>", which would create silver_silver, silver_gold and so on.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
