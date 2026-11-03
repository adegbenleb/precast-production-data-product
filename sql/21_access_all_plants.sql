-- Switch the current user to leadership access (all plants), after testing the Plant A filter.
-- Needed for building the dashboard and Genie space, and for dbt tests that count every fact row.

DELETE FROM production_dp.ref.user_plant_access WHERE user_email = current_user();
INSERT INTO production_dp.ref.user_plant_access VALUES (current_user(), 'ALL');

SELECT current_user() AS me, plant_key, count(*) AS row_count
FROM production_dp.gold.fct_element_production
GROUP BY ALL
ORDER BY plant_key;
