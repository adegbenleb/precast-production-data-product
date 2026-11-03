select
    trim(plant_id) as plant_id,
    trim(plant_name) as plant_name,
    trim(region) as region
from {{ source('bronze', 'plants') }}
