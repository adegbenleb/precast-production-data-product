-- Test the row filter (spec section 7): map yourself to Plant A only, then check what you can see.
-- Run after dbt build. Switch back with sql/22_access_all_plants.sql.

DELETE FROM production_dp.ref.user_plant_access WHERE user_email = current_user();
INSERT INTO production_dp.ref.user_plant_access VALUES (current_user(), 'P01');

-- Expect only P01 in the fact table and only Plant A in the metric view.
SELECT current_user() AS me, plant_key, count(*) AS row_count
FROM production_dp.gold.fct_element_production
GROUP BY ALL;

SELECT plant, MEASURE(elements_produced) AS elements_produced
FROM production_dp.gold.production_kpis
GROUP BY ALL;
