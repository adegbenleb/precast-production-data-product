# Production data product for precast elements (practice project)

An end-to-end data product on **Databricks Free Edition**, built with **simulated data** for three invented
precast concrete plants (Plant A, B and C). It takes messy CSV extracts through bronze, silver and gold layers,
defines every KPI once in a **Unity Catalog metric view**, and serves an **AI/BI dashboard** and a
**Genie space** for natural-language questions. Row-level security, documentation and lineage are part of the
build, not added afterwards.

**The business question:** plant managers and production leadership want to compare output, quality, cycle time
and delivery reliability across plants and element types, using one agreed definition per KPI.

**What the data shows** (May to October 2026):

| Plant | Elements | Scrap | Rework | First pass yield | On-time delivery | Avg cycle time |
|---|---|---|---|---|---|---|
| Plant A | 1,555 | 2.9% | 6.8% | 91.2% | 92.4% | 10.1 h |
| Plant B | 1,680 | **8.0%** | **11.0%** | **82.3%** | 93.8% | 10.5 h |
| Plant C | 1,626 | 4.2% | 8.1% | 89.2% | **72.6%** | **11.9 h** |

Plant B has a quality problem. Plant C has a delivery problem and growing cycle times (9.6 h in May, 13.1 h in
August). Sandwich wall panels are the hardest element type to get right first time (84.5% first pass yield).

## Architecture

```
generator/generate_data.py          13 CSV files with 6 planted data problems
        │  databricks fs cp
        ▼
/Volumes/production_dp/bronze/raw_files        Unity Catalog volume
        │  sql/01_bronze.sql  (read_files, all columns STRING, + _ingested_at, _source_file)
        ▼
bronze   8 raw Delta tables, unchanged
        │  dbt (dbt-databricks on the serverless SQL warehouse)
        ▼
silver   7 staging views: clean, standardise, deduplicate        ref.plant_name_mapping (dbt seed)
        │
        ▼
gold     star schema: fct_element_production + dim_plant, dim_element_type, dim_project, dim_date
        │  row filter ref.plant_row_filter, driven by ref.user_plant_access
        ▼
gold.production_kpis   metric view (YAML 1.1): 7 KPIs, 6 dimensions, comments, synonyms, formats
        │
        ├──► AI/BI dashboard "Precast Production KPIs"
        └──► Genie space "Precast Production KPIs" (instructions + 5 benchmark questions)
```

| Layer | Tool | Stored as | Why |
|---|---|---|---|
| Raw files | Unity Catalog volume | Files | Governed file storage; the only option on Free Edition |
| Bronze | SQL `read_files` | Delta tables, full reload | Keep data exactly as delivered, so every fix is visible downstream |
| Silver | dbt staging models | Views | Always current, no stored copy, small data |
| Gold | dbt dimensional models | Delta tables | Read often by the dashboard, metric view and Genie |
| Metrics | Metric view | View `WITH METRICS` | One definition per KPI, correct at any grain via `MEASURE()` |

## Planted data problems and how each is handled

| # | Problem in the source | Fix | Proof |
|---|---|---|---|
| 1 | Plant names in 12 spellings (`" plant a"`, `"PLANT A"`, `"Plant-A"`) | Code removes formatting noise; `ref.plant_name_mapping` maps names to plant ids as data | Test: exactly 3 plants; `plant_id` not null and present in `dim_plant` |
| 2 | Duplicate production orders with a later `updated_at` | Keep the latest version per `order_id` | `unique` test on `order_id` |
| 3 | Inspections arriving in a later month's file | Union all files; first and final result chosen by `inspected_at`, not by file; `arrived_late` flag | `unique` on `inspection_id`, `accepted_values` on result |
| 4 | Weights in kg on some rows and t on others, with no unit column | Documented rule: a weight above 100 is kg | Test: every `weight_t` between 0.5 and 50 |
| 5 | Blank strings and missing due dates | `nullif(trim(...), '')`; `UNKNOWN` project member; no due date means excluded from the on-time rate | Relationship tests |
| 6 | An uncertified plant report that counts scrap as output | Left in bronze with a "NOT certified" comment; Genie instructed to use certified gold only | Genie benchmark question 1 |

## KPI definitions (metric view `production_dp.gold.production_kpis`)

| KPI | Definition |
|---|---|
| Elements produced | Count of elements with a production end date in the period |
| Scrap rate | Elements with final result scrap / inspected elements |
| Rework rate | Elements that needed rework at any inspection / inspected elements ([decision 8](docs/decisions.md)) |
| First pass yield | Elements that passed their first inspection / inspected elements |
| On-time delivery rate | Elements delivered on or before the due date / delivered elements with a due date |
| Average cycle time (hours) | Average of production end minus production start |
| Total weight produced (t) | Sum of weight in tonnes after unit standardisation |

Dimensions: plant, region, element type, building type, production month, production week. All periods use the
production end date.

## Governance

- **Documentation:** every silver and gold table and column has a description in dbt YAML, written to Unity
  Catalog as comments with `persist_docs`. The metric view's dimensions and measures have comments and synonyms.
- **Row filter:** `gold.fct_element_production` is filtered by `ref.plant_row_filter`, which looks up
  `ref.user_plant_access`. A plant manager mapped to `P01` sees only Plant A, in the table, the metric view, the
  dashboard and Genie. `ALL` gives leadership access, and users without a row see nothing. A dbt post-hook
  attaches the filter after every build, because `CREATE OR REPLACE` would drop it.
- **Lineage:** Catalog Explorer shows the path from the metric view back through gold and silver to bronze.
- **Dashboard:** published without embedded credentials, so each viewer's own access applies.

## Genie benchmark

Five questions with verified answers ([genie/benchmarks.md](genie/benchmarks.md)), two of them traps.
Round 1, with no instructions and the uncertified table in the space, scored 4 of 5: for a ranking question Genie
put `MEASURE()` inside `ORDER BY`, which metric views reject. After adding instructions
([genie/instructions.md](genie/instructions.md)), round 2 scored 5 of 5. Rerun it any time with
`scripts/genie_benchmark.py`.

## Key decisions

Full reasoning and trade-offs are in [docs/decisions.md](docs/decisions.md). The main ones:

- A dedicated `production_dp` catalog with `bronze`, `silver`, `gold` and `ref` schemas.
- Bronze reads every column as STRING and fully reloads. Incremental loading (Auto Loader) is the production
  alternative.
- Readable gold keys (`P01`, `HCS`) instead of hashed surrogate keys, with an `UNKNOWN` project member.
- Rework rate changed from the spec's "final result rework", which is always 0% because reworked elements are
  re-inspected.
- The row filter sits on the fact table, so every consumer inherits it.
- Specific precast element types (hollow-core slab, sandwich wall panel, double-tee slab and others) instead of
  generic ones.

## What went wrong and what I learned

[docs/LEARNING_LOG.md](docs/LEARNING_LOG.md) has eight real entries with the exact errors and numbers. Highlights:

- All 86 dbt tests passed, but rework rate was 0% and on-time delivery 98%. Green tests do not prove a KPI
  means what the business thinks.
- The generator reported 222 late inspections; bronze showed 192. An independent query showed that the report
  about the data was wrong, not the data.
- The metric view failed because a join and a dimension shared the name `plant`.
- After adding the row filter, a dbt test failed because the pipeline itself could only see Plant A.

## How to run it

**Prerequisites:** a Databricks Free Edition workspace, the
[Databricks CLI](https://docs.databricks.com/dev-tools/cli/install.html), [uv](https://docs.astral.sh/uv/) and
Python 3.12.

```
git clone https://github.com/adegbenleb/precast-production-data-product.git
cd precast-production-data-product
uv sync
databricks auth login --profile blessing
```

The scripts default to the CLI profile `blessing` and this project's warehouse. To use your own, set
`DATABRICKS_CONFIG_PROFILE` and `DATABRICKS_WAREHOUSE_ID` (SQL Warehouses → your warehouse → Connection details).
Copy `dbt/profiles.example.yml` to `dbt/profiles.yml` and fill in your host and warehouse HTTP path.

Then, in this order:

```
uv run python scripts/run_sql.py sql/00_setup.sql
uv run python generator/generate_data.py
databricks fs cp -r --overwrite data/raw dbfs:/Volumes/production_dp/bronze/raw_files/ -p blessing
uv run python scripts/run_sql.py sql/01_bronze.sql
uv run python scripts/run_sql.py sql/20_governance.sql
cd dbt
uv run dbt build --profiles-dir .
cd ..
uv run python scripts/run_sql.py sql/10_metric_view.sql
```

| Script | What it does |
|---|---|
| `00_setup.sql` | Catalog, schemas, volume |
| `01_bronze.sql` | Loads the CSVs into bronze and prints the "before" counts of the planted problems |
| `20_governance.sql` | Access table and row filter function; gives you access to all plants |
| `dbt build` | Seed, silver, gold and 73 tests; attaches the row filter to the fact table |
| `10_metric_view.sql` | Creates the metric view and checks the seven KPIs by plant and month |

**Test the row filter:** `sql/21_test_plant_a.sql` maps you to Plant A and shows you only see Plant A.
`sql/22_access_all_plants.sql` switches you back.

**Dashboard:** in Databricks, Dashboards → Create → Import, and choose
`dashboards/precast_production_kpis.lvdash.json`.

**Genie:** create a space on the metric view and the gold tables, paste the instructions from
`genie/instructions.md`, then run `uv run python scripts/genie_benchmark.py <space_id>`.

## Repository layout

```
generator/      data generator with the six planted problems
sql/            setup, bronze load, metric view, governance
dbt/            silver and gold models, seed, tests, descriptions
dashboards/     AI/BI dashboard definition
genie/          Genie instructions and benchmark results
scripts/        SQL runner and Genie benchmark runner
docs/           spec, decisions, learning log
```

## Possible next steps

- Schedule `dbt build` as a Lakeflow Job, running as a service principal with `ALL` access.
- Load bronze incrementally with Auto Loader instead of a full reload.
- Map access by Databricks groups instead of individual users.
- Deploy with Declarative Automation Bundles.

All data is simulated. Plants, projects and cities are invented and do not represent any real company.
