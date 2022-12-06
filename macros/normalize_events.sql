{% macro normalize_events(event_name, flat_cols = [], sde_col = '', sde_keys = [], sde_types = [], context_cols = [], context_keys = [], context_types = [], context_aliases = [], test = false) %}
    {{ return(adapter.dispatch('normalize_events', 'snowplow_normalize')(event_name, flat_cols, sde_col, sde_keys, sde_types, context_cols, context_keys, context_types, context_aliases, test)) }}
{% endmacro %}

{% macro snowflake__normalize_events(event_name, flat_cols, sde_col, sde_keys, sde_types, context_cols, context_keys, context_types, context_aliases, test) %}
{# Remove down to major version for Snowflake columns, drop 2 last _X values #}
{%- set sde_col = '_'.join(sde_col.split('_')[:-2]) -%}
{%- set context_cols_clean = [] -%}
{%- for ind in range(context_cols|length) -%}
    {% do context_cols_clean.append('_'.join(context_cols[ind].split('_')[:-2])) -%}
{%- endfor -%}

select
    event_id
    , collector_tstamp
    -- Flat columns from event table
    {% if flat_cols|length > 0 %}
    {%- for col in flat_cols -%}
    , {{ col }}
    {% endfor -%}
    {%- endif -%}
    -- self describing events column from event table
    {% if sde_col != '' %}
    {%- for key, type in zip(sde_keys, sde_types) -%}
    , {{ sde_col }}:{{ key }}::{{ type }} as {{ snowplow_normalize.snakeify_case(key) }}
    {% endfor -%}
    {%- endif -%}
    -- context column(s) from the event table
    {% if context_cols_clean|length > 0 %}
    {%- for col, col_ind in zip(context_cols_clean, range(context_cols_clean|length)) -%}
    {%- for key, type in zip(context_keys[col_ind], context_types[col_ind]) -%}
    {% if context_aliases|length > 0 -%}
    , {{ col }}[0]:{{ key }}::{{ type }} as {{ context_aliases[col_ind] }}_{{ snowplow_normalize.snakeify_case(key) }}
    {% else -%}
    , {{ col }}[0]:{{ key }}::{{ type }} as {{ snowplow_normalize.snakeify_case(key) }}
    {%- endif -%}
    {%- endfor -%}
    {%- endfor -%}
    {%- endif %}
from
    {{ ref('snowplow_normalize_base_events_this_run') }}
where
    event_name = '{{ event_name }}'
    {% if not test %}
        and {{ snowplow_utils.is_run_with_new_events("snowplow_normalize") }}
    {%- endif -%}
{% endmacro %}


{% macro bigquery__normalize_events(event_name, flat_cols, sde_col, sde_keys, sde_types, context_cols, context_keys, context_types, context_aliases, test) %}
{# Replace keys with snake_case where needed #}
{%- set sde_keys_clean = [] -%}
{%- set context_keys_clean = [] -%}
{%- for ind in range(sde_keys|length) -%}
    {% do sde_keys_clean.append(snowplow_normalize.snakeify_case(sde_keys[ind])) -%}
{%- endfor -%}
{%- for ind1 in range(context_keys|length) -%}
    {%- set context_key_clean = [] -%}
    {%- for ind2 in range(context_keys[ind1]|length) -%}
        {% do context_key_clean.append(snowplow_normalize.snakeify_case(context_keys[ind1][ind2])) -%}
    {%- endfor -%}
    {% do context_keys_clean.append(context_key_clean) -%}
{%- endfor -%}

select
    event_id
    , collector_tstamp
    -- Flat columns from event table
    {% if flat_cols|length > 0 %}
    {%- for col in flat_cols -%}
    , {{ col }}
    {% endfor -%}
    {%- endif -%}
    -- self describing events column from event table
    {% if sde_col != '' %}
    {%- for key, type in zip(sde_keys_clean, sde_types) -%}
    , {{ sde_col }}.{{ key }} as {{ key }}
    {% endfor -%}
    {%- endif -%}
    -- context column(s) from the event table
    {% if context_cols|length > 0 %}
    {%- for col, col_ind in zip(context_cols, range(context_cols|length)) -%}
    {%- for key in context_keys_clean[col_ind] -%}
    {% if context_aliases|length > 0 -%}
    , {{ col }}[SAFE_OFFSET(0)].{{ key }} as {{ context_aliases[col_ind] }}_{{ key }}
    {% else -%}
    , {{ col }}[SAFE_OFFSET(0)].{{ key }} as {{ key }}
    {%- endif -%}
    {%- endfor -%}
    {%- endfor -%}
    {%- endif %}
from
    {{ ref('snowplow_normalize_base_events_this_run') }}
where
    event_name = '{{ event_name }}'
    {% if not test %}
        and {{ snowplow_utils.is_run_with_new_events("snowplow_normalize") }}
    {%- endif -%}
{% endmacro %}

{% macro databricks__normalize_events(event_name, flat_cols, sde_col, sde_keys, sde_types, context_cols, context_keys, context_types, context_aliases, test) %}
{# Remove down to major version for Databricks columns, drop 2 last _X values #}
{%- set sde_col = '_'.join(sde_col.split('_')[:-2]) -%}
{%- set context_cols_clean = [] -%}
{%- for ind in range(context_cols|length) -%}
    {% do context_cols_clean.append('_'.join(context_cols[ind].split('_')[:-2])) -%}
{%- endfor -%}

{# Replace keys with snake_case where needed #}
{%- set sde_keys_clean = [] -%}
{%- set context_keys_clean = [] -%}
{%- for ind in range(sde_keys|length) -%}
    {% do sde_keys_clean.append(snowplow_normalize.snakeify_case(sde_keys[ind])) -%}
{%- endfor -%}
{%- for ind1 in range(context_keys|length) -%}
    {%- set context_key_clean = [] -%}
    {%- for ind2 in range(context_keys[ind1]|length) -%}
        {% do context_key_clean.append(snowplow_normalize.snakeify_case(context_keys[ind1][ind2])) -%}
    {%- endfor -%}
    {% do context_keys_clean.append(context_key_clean) -%}
{%- endfor -%}

select
    event_id
    , collector_tstamp
    {% if target.type in ['databricks', 'spark'] -%}
    , DATE(collector_tstamp) as collector_tstamp_date
    {%- endif %}
    -- Flat columns from event table
    {% if flat_cols|length > 0 %}
    {%- for col in flat_cols -%}
    , {{ col }}
    {% endfor -%}
    {%- endif -%}
    -- self describing events column from event table
    {% if sde_col != '' %}
    {%- for key, type in zip(sde_keys_clean, sde_types) -%}
    , {{ sde_col }}.{{ key }} as {{ key }}
    {% endfor -%}
    {%- endif -%}
    -- context column(s) from the event table
    {% if context_cols_clean|length > 0 %}
    {%- for col, col_ind in zip(context_cols_clean, range(context_cols_clean|length)) -%}
    {%- for key in context_keys_clean[col_ind] -%}
    {% if context_aliases|length > 0 -%}
    , {{ col }}[0].{{ key }} as {{ context_aliases[col_ind] }}_{{ key }}
    {% else -%}
    , {{ col }}[0].{{ key }} as {{ key }}
    {%- endif -%}
    {%- endfor -%}
    {%- endfor -%}
    {%- endif %}
from
    {{ ref('snowplow_normalize_base_events_this_run') }}
where
    event_name = '{{ event_name }}'
    {% if not test %}
        and {{ snowplow_utils.is_run_with_new_events("snowplow_normalize") }}
    {%- endif -%}
{% endmacro %}