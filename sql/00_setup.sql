-- Step 0:00 to 0:15: catalog, layer schemas and the raw file volume.
-- Safe to re-run: every statement uses IF NOT EXISTS.

CREATE CATALOG IF NOT EXISTS production_dp
COMMENT 'Practice production data product for precast elements. Simulated data only.';

CREATE SCHEMA IF NOT EXISTS production_dp.bronze
COMMENT 'Raw source data loaded unchanged from CSV files, plus _ingested_at and _source_file.';

CREATE SCHEMA IF NOT EXISTS production_dp.silver
COMMENT 'Cleaned, standardised and deduplicated staging models built by dbt.';

CREATE SCHEMA IF NOT EXISTS production_dp.gold
COMMENT 'Certified star schema (facts and dimensions) and the metric view. Use this layer for reporting.';

CREATE SCHEMA IF NOT EXISTS production_dp.ref
COMMENT 'Reference data maintained as data, not code, such as the plant name mapping and user to plant access.';

CREATE VOLUME IF NOT EXISTS production_dp.bronze.raw_files
COMMENT 'Landing folder for the raw CSV files from the data generator.';

SHOW SCHEMAS IN production_dp;
