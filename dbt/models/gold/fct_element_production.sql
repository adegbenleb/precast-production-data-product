-- Certified fact table. Grain: one row per produced element.

with inspections as (
    -- First and final result are chosen by inspected_at, not by which monthly file the row arrived in.
    -- This is what neutralises late-arriving inspections (problem 3).
    select
        element_id,
        count(*) as inspection_count,
        count_if(result = 'rework') > 0 as was_reworked,
        min_by(result, inspected_at) as first_result,
        max_by(result, inspected_at) as final_result,
        max(inspected_at) as final_inspected_at
    from {{ ref('stg_quality_inspections') }}
    group by element_id
)

select
    e.element_id,
    e.order_id,
    o.plant_id as plant_key,
    o.element_type_code as element_type_key,
    coalesce(o.project_id, 'UNKNOWN') as project_key,
    to_date(e.production_end) as production_end_date,
    e.production_start,
    e.production_end,
    (unix_timestamp(e.production_end) - unix_timestamp(e.production_start)) / 3600.0 as cycle_time_hours,
    i.inspection_count is not null as is_inspected,
    coalesce(i.inspection_count, 0) as inspection_count,
    i.first_result,
    i.final_result,
    i.final_inspected_at,
    i.first_result = 'pass' as passed_first_time,
    -- Rework rate uses this, not final_result = 'rework': reworked elements are always re-inspected,
    -- so their final result is pass or scrap and "final result rework" would always be 0.
    i.was_reworked,
    d.delivered_at,
    o.due_date,
    case
        when d.delivered_at is null or o.due_date is null then null
        else to_date(d.delivered_at) <= o.due_date
    end as delivered_on_time,
    e.weight_t
from {{ ref('stg_produced_elements') }} as e
inner join {{ ref('stg_production_orders') }} as o
    on e.order_id = o.order_id
left join inspections as i
    on e.element_id = i.element_id
left join {{ ref('stg_deliveries') }} as d
    on e.element_id = d.element_id
