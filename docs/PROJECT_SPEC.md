# Project spec: Production data product for precast elements

## 1. Business requirement
Plant managers and production leadership want to compare **output, quality, cycle time, and delivery reliability** across plants and element types, with **one agreed definition per key figure**, and be able to ask follow-up questions themselves. Today (in this scenario) each plant reports differently, names plants and element types inconsistently, and numbers do not match between reports.

Decisions this product supports:
- Which plant or element type has a quality problem (scrap and rework)?
- Are we delivering on time to construction sites?
- Where are cycle times growing?

Users: plant managers (see only their plant), production leadership (all plants), analysts.

## 2. Architecture
Raw CSV files in a volume, then **bronze** (raw Delta tables), **silver** (cleaned, standardised, deduplicated dbt models), **gold** (star schema), a **metric view** (one definition per KPI), then an **AI/BI dashboard** and a **Genie space**. Quality, governance, and Git run across all layers.

## 3. Simulated source data (generate about 3 to 6 months, 3 plants)
| File | Grain | Key columns |
| --- | --- | --- |
| plants.csv | one row per plant | plant_id, plant_name, region |
| element_types.csv | one row per type | element_type_code, description (wall, slab, column, beam, facade panel), weight_unit |
| projects.csv | one row per project | project_id, project_name, site_city, building_type |
| production_orders.csv | one row per order | order_id, plant (name as text), project_id, element_type_code, quantity, planned_start, due_date |
| produced_elements.csv | one row per produced element | element_id, order_id, production_start, production_end, weight |
| quality_inspections.csv | one row per inspection | inspection_id, element_id, inspected_at, result (pass, rework, scrap), defect_type |
| deliveries.csv | one row per delivered element | delivery_id, element_id, delivered_at, site_city |

## 4. Planted data problems (the generator must create these on purpose)
1. **Plant name variants:** the same plant appears as "Plant A", " plant a", "PLANT A", "Plant-A".
2. **Duplicate production orders:** some orders appear twice, with a later `updated_at` on the second.
3. **Late-arriving quality inspections:** some inspections arrive in a later file than their production date.
4. **Unit mix-up:** some element weights are in kg, others in t, without a unit column on those rows.
5. **Blanks and missing values:** blank strings and missing due dates in some orders.
6. **Two candidate output tables:** a raw-style table that counts all produced elements including scrap, next to the certified gold fact table. Genie must be made to use the certified one.

Each problem must be detected and handled in silver or gold, with a dbt test or a documented rule, and logged in the learning log.

## 5. Gold model
- `fct_element_production`: grain = one row per produced element. Columns: element_id, order_id, plant_key, element_type_key, project_key, production_end_date, cycle_time_hours, final_result (pass, rework, scrap), passed_first_time (boolean), delivered_at, due_date, delivered_on_time (boolean), weight_t.
- Dimensions: `dim_plant`, `dim_element_type`, `dim_project`, `dim_date`.
- Reference mapping: `ref.plant_name_mapping` (variant name to plant_id), maintained as data, not code.

## 6. KPI definitions (agreed definitions, built once in the metric view)
| KPI | Definition |
| --- | --- |
| Elements produced | Count of elements with a production end date in the period (date logic: production end date) |
| Scrap rate | Elements with final result scrap / inspected elements |
| Rework rate | Elements with final result rework / inspected elements |
| First pass yield | Elements that passed at the first inspection / inspected elements |
| On-time delivery rate | Elements delivered on or before the due date / delivered elements |
| Average cycle time (hours) | Average of production end minus production start |
| Total weight produced (t) | Sum of weight in tonnes, after unit standardisation |

Dimensions in the metric view: plant, region, element type, project building type, production month, production week.

## 7. Governance
- Comments on every gold table and column, and on the metric view's dimensions and measures.
- Row filter on `fct_element_production`: a plant manager sees only their plant (use a small mapping table of user emails to plant_id; test it with your own email mapped to Plant A).
- Check lineage in Catalog Explorer from the metric view back to bronze.

## 8. Consumers
- AI/BI dashboard on the metric view: KPI counters, trend by month, comparison by plant and element type.
- Genie space using the metric view and certified gold tables, with instructions and 5 benchmark questions with known answers. Record which questions Genie got wrong at first and how you fixed it.

## 9. Two-hour plan
| Time | Step |
| --- | --- |
| Before | Free Edition sign-up, Databricks CLI login, dbt-databricks installed, Git repo |
| 0:00 to 0:15 | Catalog, schemas, volume |
| 0:15 to 0:40 | Data generator with planted problems, upload, bronze tables |
| 0:40 to 1:10 | dbt staging (silver) and star schema (gold) with tests and descriptions |
| 1:10 to 1:30 | Metric view, comments, row filter |
| 1:30 to 1:45 | AI/BI dashboard and Genie space with benchmark questions |
| 1:45 to 2:00 | README, learning log, commit |

## 10. Acceptance checklist
- [ ] All six planted problems detected and handled, each with a test or documented rule
- [ ] dbt build passes; distinct plant names drop from the variants to exactly 3
- [ ] Gold star schema with descriptions on all tables and columns
- [ ] Metric view returns all seven KPIs by plant and month
- [ ] Row filter works (your user sees only Plant A when mapped)
- [ ] Dashboard and Genie space working; Genie answers the 5 benchmark questions correctly after fixes
- [ ] Learning log has at least 5 real entries
- [ ] README explains architecture, decisions, and how to run
