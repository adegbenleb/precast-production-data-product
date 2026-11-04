-- Row-level security: a plant manager sees only their plant's rows.
-- This file creates the access mapping and the filter function. dbt attaches the filter to
-- gold.fct_element_production in a post-hook after every build, so run this BEFORE dbt build.
-- No email addresses are written in this file: mappings use current_user().

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

-- The person running the pipeline needs all plants, or dbt's tests only see part of the data.
DELETE FROM production_dp.ref.user_plant_access WHERE user_email = current_user();
INSERT INTO production_dp.ref.user_plant_access VALUES (current_user(), 'ALL');
