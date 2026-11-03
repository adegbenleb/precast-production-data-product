# Learning log

Write one entry for every real problem you hit. These entries become your interview stories, so be specific and honest. Use real error messages and real numbers from this project.

## Entry template
**Date / step:**
**What happened:** (the symptom, the exact error message if any)
**Cause:**
**What I did:** (the fix, with the tool or setting)
**Lesson:** (what you only learn by doing it)
**Business impact:** (why this would matter in a real company)

---

## Entry 1
**Date / step:** 2026-11-03, setup (before 0:00)
**What happened:** `dbt --version` worked and showed dbt-core 1.12.6, so dbt looked installed. But the only adapter listed was `postgres`, not `databricks`.
**Cause:** The shell still had another project's virtualenv active (`shopflow-brain/.venv`). The `dbt` on PATH belonged to that project, not this one.
**What I did:** Checked `which dbt` and `$VIRTUAL_ENV` to find where it came from. Gave this project its own uv environment with `dbt-databricks`, so the two projects never share packages.
**Lesson:** "The command runs" is not the same as "the right tool is installed". Check `which` and the adapter list, not only the version.
**Business impact:** On a team, a wrong or shared environment produces "works on my machine" failures and builds against the wrong adapter. Pinned per-project environments make dbt runs reproducible in CI and on a schedule.

## Entry 2
**Date / step:** 2026-11-03, setup (before 0:00)
**What happened:** `brew tap databricks/tap` failed with `Error: /opt/homebrew/Cellar is not writable` and `Permission denied @ rb_sysopen ... locks/...lock`.
**Cause:** Homebrew on this Mac is owned by a different macOS user account. Brew suggested `sudo chown -R` to take ownership, but that would break Homebrew for the other user.
**What I did:** Skipped brew. Downloaded the official Databricks CLI release (v1.23.0, darwin_arm64) from GitHub, verified it against the published SHA256SUMS, and installed it to `~/.local/bin`, a user-owned folder already on PATH. No sudo needed.
**Lesson:** Read the permission error before following the suggested fix. The "fix" printed by a tool can have side effects on other users. Official release binaries plus checksum verification are a clean fallback when a package manager isn't usable.
**Business impact:** On locked-down company laptops, admin rights and package managers are often unavailable. Knowing a no-sudo, verified install path keeps onboarding moving without weakening security.

## Entry 3
**Date / step:** 2026-11-03, bronze load (0:15 to 0:40)
**What happened:** The generator's summary said 222 inspections arrived in a later month's file. Querying bronze (`inspected_at` month vs. the month in `_source_file`) returned 192. Same data, two different numbers.
**Cause:** The generator counted a row as "late" before clamping its arrival date to the 31 October extract cutoff. Late October inspections pushed past the cutoff were clamped back into the October file, so they were not late at all, but were still counted.
**What I did:** Moved the count after the clamp. Re-ran the generator and checked the CSVs were byte-identical (only the summary line changed), so nothing had to be re-uploaded. Both now say 192.
**Lesson:** Reconcile the numbers a source claims against what actually landed in the platform. The data was right and the report about it was wrong, and only an independent query showed that.
**Business impact:** This is the core problem the product exists to solve: two reports, two numbers, no trust. A reconciliation check between source counts and bronze counts catches it before a manager sees mismatching figures.

## Entry 4
**Date / step:** 2026-11-04, gold KPI check (0:40 to 1:10)
**What happened:** `dbt build` passed all 86 steps, but rework rate was 0.0% for every plant. 443 of 4,855 inspected elements (9.1%) had actually needed rework.
**Cause:** The spec defined rework rate as "elements with final result rework / inspected elements". In this process every reworked element is re-inspected and ends as pass (369) or scrap (74), so "final result rework" can never happen. The definition was valid SQL, but it measured nothing.
**What I did:** Added `was_reworked` (any inspection with result rework) to `fct_element_production` and changed the rework rate definition to "elements that needed rework / inspected elements". Recorded it as decision 8.
**Lesson:** Green tests prove the data is consistent, not that a KPI means what the business thinks. Check each KPI against the real process (what happens to a reworked element?) before publishing it.
**Business impact:** A rework rate of 0% would tell plant managers they have no rework problem while 9% of elements need fixing. That is how a governed metric layer loses trust on day one.

## Entry 5
**Date / step:** 2026-11-04, gold KPI check (0:40 to 1:10)
**What happened:** On-time delivery was 97.8% overall (90 late out of 4,138), so the KPI could not tell plants apart. Elements arrived a median of 16 days before their due date.
**Cause:** The generator set due dates 18 to 40 days after planned start, while the real lead time (production, inspection, transport) is about 2 to 24 days. The simulation was too generous.
**What I did:** Tested three due date ranges locally with pandas before touching Databricks (10 to 28: 80%, 8 to 24: 68%, 12 to 30: 87% with Plant C at 73%). Chose 12 to 30, regenerated, and reloaded bronze and dbt.
**Lesson:** Profile the distribution behind a KPI (here, days early or late), not only the headline number. A KPI that is near 100% everywhere carries no decision value.
**Business impact:** A KPI that never moves gets ignored. Realistic variation is what lets leadership see which plant (here Plant C) needs attention on delivery reliability.

## Entry 6
**Date / step:** 2026-11-04, metric view (1:10 to 1:30)
**What happened:** `CREATE OR REPLACE VIEW ... WITH METRICS` failed with `[INVALID_EXTRACT_BASE_FIELD_TYPE] Can't extract a value from "plant.plant_name". Need a complex type [STRUCT, ARRAY, MAP] but got "STRING".`
**Cause:** The join to `dim_plant` was named `plant`, and so was the dimension. In a metric view, join names and dimension names share one namespace, so `plant.plant_name` resolved `plant` to the dimension (a STRING) and tried to read a struct field from it.
**What I did:** Renamed the joins after their tables (`dim_plant`, `dim_element_type`, `dim_project`) and kept the business-friendly dimension names (`plant`, `element_type`). Re-ran it, and the seven KPIs by plant matched a direct query on the fact table exactly.
**Lesson:** Name things by role: technical names for joins, business names for what users and Genie see. And verify a new metric layer against an independent query before anyone uses it.
**Business impact:** The metric view is the single definition every dashboard and Genie answer depends on. Proving it matches the certified fact table is what makes "one number per KPI" trustworthy.
