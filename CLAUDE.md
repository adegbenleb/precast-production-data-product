# Instructions for Claude Code

## Project
A small, end-to-end **production data product** on **Databricks Free Edition**, built to practise the exact stack of a Data Engineer role in precast construction manufacturing (Databricks, Delta Lake, Unity Catalog, dbt, a metric layer with metric views, AI/BI dashboards, Genie). The data is **simulated**. Never use or imply real company data, real plant names, or real customers. Use neutral names: Plant A, Plant B, Plant C.

The full requirements are in `docs/PROJECT_SPEC.md`. Read it before writing any code.

## How we work
- I (Blessing) write and run the code with you. Explain each step briefly before you do it, so I understand and can explain it in an interview.
- Work in small steps. After each step, stop, tell me what to run and what result to expect, and wait for my result.
- When something fails, do not silently work around it. Show me the error, explain the cause, then fix it. Every real problem we hit must be written into `docs/LEARNING_LOG.md` (see the template there): what happened, the cause, the fix, the lesson, and the business impact.
- Prefer simple, readable solutions. This must run on Databricks Free Edition: serverless only, one SQL warehouse, Unity Catalog, volumes for files.
- Keep everything in Git with small, clear commits.

## Stack and conventions
- Catalog: `production_dp` (or the workspace default catalog if creating catalogs is not allowed; then use schemas with a `pdp_` prefix). Schemas: `bronze`, `silver`, `gold`, `ref`.
- Raw files go into a Unity Catalog volume: `/Volumes/<catalog>/bronze/raw_files/`.
- Data generation: Python (pandas or plain Python), writing CSV files with deliberate data problems (see the spec).
- Bronze: load files unchanged into Delta tables, adding `_ingested_at` and `_source_file`.
- Silver and gold: **dbt** with the `dbt-databricks` adapter, using the SQL warehouse. Staging models in silver, dimensional models in gold. dbt tests on keys and accepted values. Descriptions on every model and column.
- Metric layer: a Unity Catalog **metric view** created with `CREATE OR REPLACE VIEW ... WITH METRICS LANGUAGE YAML AS $$ ... $$`, version 1.1, defining dimensions and measures exactly as in the spec.
- Consumers: an AI/BI dashboard on the metric view, and a Genie space (Genie Agent) using the metric view and certified gold tables.
- Governance: table and column comments, a row filter so a plant manager sees only their plant, and Unity Catalog lineage.
- Stretch only if time allows: a Lakeflow Job that runs the dbt build on a schedule; a Declarative Automation Bundle (formerly Databricks Asset Bundles) for deployment.

## Definition of done
See the acceptance checklist in `docs/PROJECT_SPEC.md`. Update `README.md` at the end with the architecture, the decisions we made and why, and how to run it.
