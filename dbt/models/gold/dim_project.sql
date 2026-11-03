select
    project_id as project_key,
    project_id,
    project_name,
    site_city,
    building_type
from {{ ref('stg_projects') }}

union all

-- Unknown member: orders with a blank project point here instead of dropping out of totals.
select
    'UNKNOWN' as project_key,
    cast(null as string) as project_id,
    'Unknown project' as project_name,
    'Unknown' as site_city,
    'Unknown' as building_type
