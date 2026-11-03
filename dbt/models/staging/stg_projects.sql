select
    trim(project_id) as project_id,
    trim(project_name) as project_name,
    trim(site_city) as site_city,
    trim(building_type) as building_type
from {{ source('bronze', 'projects') }}
