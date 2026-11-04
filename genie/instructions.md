# Genie space: Precast Production KPIs

## Title
Precast Production KPIs

## Description
Ask questions about output, quality (scrap, rework, first pass yield), cycle time and on-time delivery
for Plant A, Plant B and Plant C. Simulated data, May to October 2026.

## Data sources
- `production_dp.gold.production_kpis` (metric view, the preferred source for every KPI)
- `production_dp.gold.fct_element_production` (certified fact table, one row per produced element)
- `production_dp.gold.dim_plant`, `dim_element_type`, `dim_project`, `dim_date`

Final space (round 3): only the six sources above. The uncertified bronze table was removed after round 2.

Round 1 of the benchmark deliberately also includes `production_dp.bronze.plant_daily_output_report`,
the uncertified plant-reported output table (it counts scrapped elements as output and spells plant names
12 different ways), with no instructions. That shows what Genie does with two candidate tables and no guidance.
The instructions below are the fix.

## General instructions (paste into the space's Instructions)

- For any KPI, use the metric view `production_dp.gold.production_kpis` and its measures with `MEASURE(...)`: elements_produced, inspected_elements, scrap_rate, rework_rate, first_pass_yield, on_time_delivery_rate, avg_cycle_time_hours, total_weight_t. Never write your own formula for these KPIs.
- To rank, sort or filter on a measure, compute it once in SELECT with MEASURE() and use its alias in ORDER BY and HAVING. Never put MEASURE() inside ORDER BY or HAVING: metric views reject it. Example: `SELECT plant, MEASURE(on_time_delivery_rate) AS otd FROM production_dp.gold.production_kpis GROUP BY ALL ORDER BY otd ASC LIMIT 1`.
- Rework rate means elements that needed rework at any inspection divided by inspected elements (`MEASURE(rework_rate)`). Do not compute it from `final_result = 'rework'`: reworked elements are always re-inspected, so that would always be 0%.
- All periods use the production end date (`production_month`, `production_week` in the metric view, `production_end_date` in the fact table).
- Only use certified gold tables. Never use any table in the bronze or silver schema.
- There are exactly three plants: Plant A (North), Plant B (Central), Plant C (South).
- Show rates as percentages with one decimal place.
- The data covers 1 May 2026 to 31 October 2026. If a question has no period, use the whole period.
