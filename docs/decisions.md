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
