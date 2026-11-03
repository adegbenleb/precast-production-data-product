# Decisions

Important design choices and why we made them.

## 1. Catalog `production_dp`, not prefixed schemas
**Decision:** Create a dedicated catalog with schemas `bronze`, `silver`, `gold`, `ref`.
**Why:** The workspace admin group holds `CREATE_CATALOG` on the Free Edition metastore, so the preferred option from the spec was available. One catalog per data product keeps permissions and lineage in one place.

## 2. Specific precast element types instead of the five generic ones
**Decision:** The generator uses seven industry element types (hollow-core slab, filigree slab, sandwich wall panel, precast column, prestressed beam, double-tee slab, stair element) instead of wall, slab, column, beam, facade panel from the spec.
**Why:** Closer to a real precast product range, so the analysis reads like the real business. These are generic industry terms, not any company's product names, so the data stays clearly simulated. Plants, projects and cities stay invented (Plant A/B/C).
**Trade-off:** A small deviation from the spec's list. Nothing downstream depends on the specific codes.

## 3. Generated data is not committed
**Decision:** `data/` is in `.gitignore`. The generator has a fixed seed, so anyone gets identical files by running it.
**Why:** The script is the source of truth. Committing CSVs would bloat the repo and could drift from the script.

## 4. Inspections arrive as monthly extract files
**Decision:** Inspections are written as `quality_inspections_YYYY_MM.csv`, by the month the row was received, so some rows land in a later month's file (planted problem 3).
**Why:** Mirrors how a real source system delivers incremental extracts. Silver must take the final result by `inspected_at`, not by which file a row came from.

## 5. Bronze: all columns as STRING, full reload
**Decision:** Bronze tables are built with `CREATE OR REPLACE TABLE ... AS SELECT ... FROM read_files(..., inferColumnTypes => false)`.
**Why:** Strings keep the raw data exactly as delivered (kg weights, whitespace ids, blank dates), so every fix happens visibly in silver with a test. A full reload is idempotent and simple for a fixed demo dataset.
**Trade-off:** A production pipeline would load incrementally (Auto Loader or `COPY INTO`) so it only processes new files and keeps load history. That is a possible stretch step with the Lakeflow Job.

## 6. Gold keys are the stable source ids, with an UNKNOWN project member
**Decision:** `plant_key = plant_id`, `element_type_key = element_type_code`, `project_key = project_id` (or `UNKNOWN`). No hashed surrogate keys.
**Why:** The source ids are short, stable and unique, so readable keys make queries, the metric view and Genie answers easier to follow. Orders without a project point to an `UNKNOWN` row so totals stay complete and the gap stays visible.
**Trade-off:** If a source system ever reused or changed ids, or we needed history (slowly changing dimensions), we would switch to surrogate keys.

## 7. Descriptions live in dbt YAML and are pushed to Unity Catalog
**Decision:** `+persist_docs` (relation and columns) is on for all models.
**Why:** One source of truth for documentation. The same text shows in dbt docs, in Catalog Explorer and to Genie, which reads column comments to understand the data.
