-- Handles problem 3 (late-arriving inspections). All monthly files are already unioned in bronze.
-- The final result per element is chosen by inspected_at in gold, so the file a row came from does not matter.

with typed as (
    select
        trim(inspection_id) as inspection_id,
        trim(element_id) as element_id,
        cast(inspected_at as timestamp) as inspected_at,
        lower(trim(result)) as result,
        nullif(trim(defect_type), '') as defect_type,
        _source_file as source_file,
        _ingested_at as ingested_at
    from {{ source('bronze', 'quality_inspections') }}
),

deduplicated as (
    -- If a re-sent file repeats an inspection, keep the most recently loaded copy.
    select
        *,
        row_number() over (partition by inspection_id order by ingested_at desc, source_file desc) as copy_rank
    from typed
)

select
    inspection_id,
    element_id,
    inspected_at,
    result,
    defect_type,
    source_file,
    date_format(inspected_at, 'yyyy_MM')
        <> regexp_extract(source_file, 'quality_inspections_([0-9]{4}_[0-9]{2})', 1) as arrived_late
from deduplicated
where copy_rank = 1
