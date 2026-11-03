-- Step 1:10 to 1:30: the metric layer. One agreed definition per KPI, built once.
-- Consumers (AI/BI dashboard, Genie, analysts) query this view with MEASURE(...) instead of writing their own formulas.
-- Rates use try_divide: Databricks SQL runs in ANSI mode, where dividing by zero raises an error instead of returning NULL.

CREATE OR REPLACE VIEW production_dp.gold.production_kpis
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
comment: >
  Certified production KPIs for precast elements: output, quality, cycle time and delivery reliability.
  One agreed definition per KPI. All periods use the production end date.
  Rework rate counts elements that needed rework at any inspection (see docs/decisions.md, decision 8).
source: production_dp.gold.fct_element_production

joins:
  - name: plant
    source: production_dp.gold.dim_plant
    on: source.plant_key = plant.plant_key
  - name: element_type
    source: production_dp.gold.dim_element_type
    on: source.element_type_key = element_type.element_type_key
  - name: project
    source: production_dp.gold.dim_project
    on: source.project_key = project.project_key

dimensions:
  - name: plant
    expr: plant.plant_name
    display_name: Plant
    comment: Plant that produced the element (Plant A, Plant B, Plant C).
    synonyms: [factory, site, werk]
  - name: region
    expr: plant.region
    display_name: Region
    comment: Region the plant belongs to (North, Central, South).
  - name: element_type
    expr: element_type.element_type_name
    display_name: Element Type
    comment: Precast element type, for example hollow-core slab or sandwich wall panel.
    synonyms: [product, product type, element]
  - name: building_type
    expr: project.building_type
    display_name: Building Type
    comment: Type of building the project is for. Unknown when the order had no project.
  - name: production_month
    expr: DATE_TRUNC('MONTH', source.production_end_date)
    display_name: Production Month
    comment: First day of the month in which production finished.
    synonyms: [month]
  - name: production_week
    expr: DATE_TRUNC('WEEK', source.production_end_date)
    display_name: Production Week
    comment: Monday of the week in which production finished.
    synonyms: [week]

measures:
  - name: elements_produced
    expr: COUNT(1)
    display_name: Elements Produced
    comment: Count of elements with a production end date in the period. Includes elements later scrapped.
    synonyms: [output, production volume, units produced]
  - name: inspected_elements
    expr: COUNT_IF(source.is_inspected)
    display_name: Inspected Elements
    comment: Elements with at least one quality inspection. Denominator of scrap rate, rework rate and first pass yield.
  - name: scrap_rate
    expr: TRY_DIVIDE(COUNT_IF(source.final_result = 'scrap'), COUNT_IF(source.is_inspected))
    display_name: Scrap Rate
    comment: Elements with final result scrap divided by inspected elements.
    synonyms: [scrap, scrap percentage]
  - name: rework_rate
    expr: TRY_DIVIDE(COUNT_IF(source.was_reworked), COUNT_IF(source.is_inspected))
    display_name: Rework Rate
    comment: Elements that needed rework at any inspection divided by inspected elements.
    synonyms: [rework, rework percentage]
  - name: first_pass_yield
    expr: TRY_DIVIDE(COUNT_IF(source.passed_first_time), COUNT_IF(source.is_inspected))
    display_name: First Pass Yield
    comment: Elements that passed at their first inspection divided by inspected elements.
    synonyms: [FPY, yield, right first time]
  - name: on_time_delivery_rate
    expr: TRY_DIVIDE(COUNT_IF(source.delivered_on_time), COUNT(source.delivered_on_time))
    display_name: On-Time Delivery Rate
    comment: Elements delivered on or before the due date divided by delivered elements that have a due date.
    synonyms: [OTD, on-time delivery, delivery reliability]
  - name: avg_cycle_time_hours
    expr: AVG(source.cycle_time_hours)
    display_name: Average Cycle Time (hours)
    comment: Average of production end minus production start, in hours.
    synonyms: [cycle time, production time]
  - name: total_weight_t
    expr: SUM(source.weight_t)
    display_name: Total Weight Produced (t)
    comment: Sum of element weight in tonnes, after unit standardisation.
    synonyms: [tonnage, weight produced]
$$;

-- Check: all seven KPIs by plant. Compare with the direct query on the fact table.
SELECT
  plant,
  MEASURE(elements_produced) AS elements_produced,
  ROUND(MEASURE(scrap_rate) * 100, 1) AS scrap_pct,
  ROUND(MEASURE(rework_rate) * 100, 1) AS rework_pct,
  ROUND(MEASURE(first_pass_yield) * 100, 1) AS fpy_pct,
  ROUND(MEASURE(on_time_delivery_rate) * 100, 1) AS otd_pct,
  ROUND(MEASURE(avg_cycle_time_hours), 1) AS avg_cycle_h,
  ROUND(MEASURE(total_weight_t), 0) AS weight_t
FROM production_dp.gold.production_kpis
GROUP BY ALL
ORDER BY plant;

-- Check: by plant and month (acceptance checklist: all seven KPIs by plant and month).
SELECT
  plant,
  production_month,
  MEASURE(elements_produced) AS elements_produced,
  ROUND(MEASURE(scrap_rate) * 100, 1) AS scrap_pct,
  ROUND(MEASURE(on_time_delivery_rate) * 100, 1) AS otd_pct,
  ROUND(MEASURE(avg_cycle_time_hours), 1) AS avg_cycle_h
FROM production_dp.gold.production_kpis
GROUP BY ALL
ORDER BY plant, production_month;
