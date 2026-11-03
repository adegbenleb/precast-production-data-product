-- Step 0:15 to 0:40: load raw CSV files from the volume into bronze Delta tables, unchanged.
-- Every column is read as STRING so the planted problems survive into bronze exactly as delivered.
-- Each table gets _ingested_at (load time) and _source_file (the file the row came from).
-- Full reload: CREATE OR REPLACE makes this safe to re-run.

CREATE OR REPLACE TABLE production_dp.bronze.plants
COMMENT 'Raw plants.csv, loaded unchanged.'
AS SELECT *, current_timestamp() AS _ingested_at, _metadata.file_path AS _source_file
FROM read_files('/Volumes/production_dp/bronze/raw_files/plants.csv',
  format => 'csv', header => true, inferColumnTypes => false);

CREATE OR REPLACE TABLE production_dp.bronze.element_types
COMMENT 'Raw element_types.csv, loaded unchanged.'
AS SELECT *, current_timestamp() AS _ingested_at, _metadata.file_path AS _source_file
FROM read_files('/Volumes/production_dp/bronze/raw_files/element_types.csv',
  format => 'csv', header => true, inferColumnTypes => false);

CREATE OR REPLACE TABLE production_dp.bronze.projects
COMMENT 'Raw projects.csv, loaded unchanged.'
AS SELECT *, current_timestamp() AS _ingested_at, _metadata.file_path AS _source_file
FROM read_files('/Volumes/production_dp/bronze/raw_files/projects.csv',
  format => 'csv', header => true, inferColumnTypes => false);

CREATE OR REPLACE TABLE production_dp.bronze.production_orders
COMMENT 'Raw production_orders.csv, loaded unchanged. Contains plant name variants, duplicate orders and blanks.'
AS SELECT *, current_timestamp() AS _ingested_at, _metadata.file_path AS _source_file
FROM read_files('/Volumes/production_dp/bronze/raw_files/production_orders.csv',
  format => 'csv', header => true, inferColumnTypes => false);

CREATE OR REPLACE TABLE production_dp.bronze.produced_elements
COMMENT 'Raw produced_elements.csv, loaded unchanged. Weight is a mix of tonnes and kilograms.'
AS SELECT *, current_timestamp() AS _ingested_at, _metadata.file_path AS _source_file
FROM read_files('/Volumes/production_dp/bronze/raw_files/produced_elements.csv',
  format => 'csv', header => true, inferColumnTypes => false);

CREATE OR REPLACE TABLE production_dp.bronze.quality_inspections
COMMENT 'Raw monthly quality_inspections_YYYY_MM.csv files, loaded unchanged. Some rows arrive in a later month''s file.'
AS SELECT *, current_timestamp() AS _ingested_at, _metadata.file_path AS _source_file
FROM read_files('/Volumes/production_dp/bronze/raw_files/quality_inspections_*.csv',
  format => 'csv', header => true, inferColumnTypes => false);

CREATE OR REPLACE TABLE production_dp.bronze.deliveries
COMMENT 'Raw deliveries.csv, loaded unchanged.'
AS SELECT *, current_timestamp() AS _ingested_at, _metadata.file_path AS _source_file
FROM read_files('/Volumes/production_dp/bronze/raw_files/deliveries.csv',
  format => 'csv', header => true, inferColumnTypes => false);

CREATE OR REPLACE TABLE production_dp.bronze.plant_daily_output_report
COMMENT 'Raw plant-reported daily output, loaded unchanged. NOT certified: counts scrapped elements as output. Use gold.fct_element_production instead.'
AS SELECT *, current_timestamp() AS _ingested_at, _metadata.file_path AS _source_file
FROM read_files('/Volumes/production_dp/bronze/raw_files/plant_daily_output_report.csv',
  format => 'csv', header => true, inferColumnTypes => false);

-- Check: row counts per table, and the "before" numbers for the planted problems.
SELECT 'plants' AS table_name, count(*) AS row_count FROM production_dp.bronze.plants
UNION ALL SELECT 'element_types', count(*) FROM production_dp.bronze.element_types
UNION ALL SELECT 'projects', count(*) FROM production_dp.bronze.projects
UNION ALL SELECT 'production_orders', count(*) FROM production_dp.bronze.production_orders
UNION ALL SELECT 'produced_elements', count(*) FROM production_dp.bronze.produced_elements
UNION ALL SELECT 'quality_inspections', count(*) FROM production_dp.bronze.quality_inspections
UNION ALL SELECT 'deliveries', count(*) FROM production_dp.bronze.deliveries
UNION ALL SELECT 'plant_daily_output_report', count(*) FROM production_dp.bronze.plant_daily_output_report;

SELECT
  count(DISTINCT plant) AS distinct_plant_spellings,
  count(*) - count(DISTINCT order_id) AS duplicate_order_rows,
  count_if(due_date IS NULL OR trim(due_date) = '') AS missing_due_dates,
  count_if(trim(project_id) = '') AS blank_project_ids
FROM production_dp.bronze.production_orders;
