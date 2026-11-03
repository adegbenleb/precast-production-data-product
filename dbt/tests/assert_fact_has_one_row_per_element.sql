-- Fan-out guard: the fact table must have exactly one row per produced element.
-- A join that duplicates or drops rows would silently distort every KPI.
select
    (select count(*) from {{ ref('fct_element_production') }}) as fact_rows,
    (select count(*) from {{ ref('stg_produced_elements') }}) as element_rows
where (select count(*) from {{ ref('fct_element_production') }})
   <> (select count(*) from {{ ref('stg_produced_elements') }})
