select
    trim(delivery_id) as delivery_id,
    trim(element_id) as element_id,
    cast(delivered_at as timestamp) as delivered_at,
    trim(site_city) as site_city
from {{ source('bronze', 'deliveries') }}
