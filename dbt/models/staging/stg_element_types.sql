select
    upper(trim(element_type_code)) as element_type_code,
    trim(description) as element_type_name,
    trim(weight_unit) as weight_unit
from {{ source('bronze', 'element_types') }}
