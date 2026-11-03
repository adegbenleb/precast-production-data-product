select
    plant_id as plant_key,
    plant_id,
    plant_name,
    region
from {{ ref('stg_plants') }}
