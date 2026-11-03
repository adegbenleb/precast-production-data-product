-- Problem 4: after unit standardisation every weight must be a plausible precast element weight in tonnes.
-- A value outside 0.5 to 50 t means the kg rule missed a row or misread one.
select element_id, weight_raw, weight_t
from {{ ref('stg_produced_elements') }}
where weight_t < 0.5 or weight_t > 50
