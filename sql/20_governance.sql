-- Step 1:10 to 1:30: row-level security. A plant manager sees only their plant's rows.
-- The filter sits on the certified fact table, so the metric view, dashboard and Genie inherit it.
-- No email addresses are written in this file: the test mapping uses current_user().

CREATE TABLE IF NOT EXISTS production_dp.ref.user_plant_access (
  user_email STRING NOT NULL COMMENT 'Databricks user name (email) of the person getting access.',
  plant_id STRING NOT NULL COMMENT 'Plant the user may see (P01, P02, P03), or ALL for production leadership and analysts.'
)
COMMENT 'Who may see which plant. Used by ref.plant_row_filter. Users without a row see no fact rows.';

CREATE OR REPLACE FUNCTION production_dp.ref.plant_row_filter(plant_key STRING)
RETURNS BOOLEAN
COMMENT 'Row filter for gold.fct_element_production: true when the current user is mapped to this plant or to ALL.'
RETURN EXISTS (
  SELECT 1
  FROM production_dp.ref.user_plant_access AS a
  WHERE a.user_email = current_user()
    AND a.plant_id IN (plant_key, 'ALL')
);

-- Test setup from the spec: map yourself to Plant A only.
DELETE FROM production_dp.ref.user_plant_access WHERE user_email = current_user();
INSERT INTO production_dp.ref.user_plant_access VALUES (current_user(), 'P01');

ALTER TABLE production_dp.gold.fct_element_production
SET ROW FILTER production_dp.ref.plant_row_filter ON (plant_key);

-- Check: you should now see only P01 in the fact table and only Plant A in the metric view.
SELECT current_user() AS me, plant_key, count(*) AS row_count
FROM production_dp.gold.fct_element_production
GROUP BY ALL;

SELECT plant, MEASURE(elements_produced) AS elements_produced
FROM production_dp.gold.production_kpis
GROUP BY ALL;
