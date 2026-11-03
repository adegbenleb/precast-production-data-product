-- Problem 1: the 12 plant name spellings in bronze must collapse to exactly 3 plants.
-- Returns a row (fails) if the count is anything other than 3.
select count(distinct plant_id) as plant_count
from {{ ref('stg_production_orders') }}
having count(distinct plant_id) <> 3
