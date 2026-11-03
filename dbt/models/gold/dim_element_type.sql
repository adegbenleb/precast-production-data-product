select
    element_type_code as element_type_key,
    element_type_code,
    element_type_name
from {{ ref('stg_element_types') }}
