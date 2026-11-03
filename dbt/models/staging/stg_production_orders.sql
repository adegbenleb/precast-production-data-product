-- Fixes problem 1 (plant name variants), 2 (duplicate orders) and 5 (blanks).

with cleaned as (
    select
        trim(order_id) as order_id,
        trim(plant) as plant_name_raw,
        -- Problem 1: remove formatting noise. " plant a", "PLANT A" and "Plant-A" all become "PLANT A".
        upper(trim(regexp_replace(plant, '[^A-Za-z0-9]+', ' '))) as plant_name_normalized,
        -- Problem 5: whitespace-only and empty strings become NULL.
        nullif(trim(project_id), '') as project_id,
        upper(trim(element_type_code)) as element_type_code,
        cast(quantity as int) as quantity,
        cast(planned_start as timestamp) as planned_start,
        cast(nullif(trim(due_date), '') as date) as due_date,
        cast(updated_at as timestamp) as updated_at
    from {{ source('bronze', 'production_orders') }}
),

deduplicated as (
    -- Problem 2: an order can appear more than once. Keep the most recently updated version.
    select
        *,
        row_number() over (partition by order_id order by updated_at desc) as version_rank
    from cleaned
)

select
    o.order_id,
    m.plant_id,
    o.plant_name_raw,
    o.project_id,
    o.element_type_code,
    o.quantity,
    o.planned_start,
    o.due_date,
    o.updated_at
from deduplicated as o
left join {{ ref('plant_name_mapping') }} as m
    on o.plant_name_normalized = m.variant_name
where o.version_rank = 1
