-- Fixes problem 4 (weights in kg and t mixed, with no unit column).
-- Rule: a weight above 100 is in kg. Safe because the heaviest element type is about 14 t
-- and the lightest weight written in kg is about 2,500.

with typed as (
    select
        trim(element_id) as element_id,
        trim(order_id) as order_id,
        cast(production_start as timestamp) as production_start,
        cast(production_end as timestamp) as production_end,
        cast(weight as double) as weight_raw
    from {{ source('bronze', 'produced_elements') }}
)

select
    element_id,
    order_id,
    production_start,
    production_end,
    weight_raw,
    case when weight_raw > 100 then 'kg' else 't' end as weight_unit_detected,
    case when weight_raw > 100 then weight_raw / 1000 else weight_raw end as weight_t
from typed
