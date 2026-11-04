# Genie benchmark questions

Expected answers were verified with SQL against `production_dp.gold.production_kpis` on 2026-11-04
(generator seed 42, user mapped to ALL plants).

| # | Question | Expected answer | What it tests |
|---|---|---|---|
| 1 | How many elements did each plant produce? | Plant A 1,555 · Plant B 1,680 · Plant C 1,626 (total 4,861) | Trap: the uncertified plant report splits this across 12 plant spellings |
| 2 | What is the scrap rate by plant? | Plant A 2.9% · Plant B 8.0% · Plant C 4.2% | Correct denominator (inspected elements, not all produced) |
| 3 | What is the rework rate for Plant B? | 11.0% | Trap: `final_result = 'rework'` gives 0.0% |
| 4 | Which plant has the lowest on-time delivery rate, and what is it? | Plant C, 72.6% | Denominator excludes undelivered elements and missing due dates |
| 5 | How did Plant C's average cycle time change from May to October 2026? | 9.6 h in May to 12.9 h in October (peak 13.1 h in August) | Monthly grain on production end date |

## Results

Record each run here: what Genie answered, whether it was right, and what fixed it.

### Round 1: 2026-11-04, no instructions, uncertified bronze table included in the space

| # | Result | What Genie did |
|---|---|---|
| 1 | Correct | Used `MEASURE(elements_produced)` from the metric view. Ignored the uncertified plant report. |
| 2 | Correct | Used `MEASURE(scrap_rate)`: 2.9%, 8.0%, 4.2%. |
| 3 | Correct | Used `MEASURE(rework_rate)`: 11.0%. Did not fall into the `final_result = 'rework'` trap. |
| 4 | **Failed** | Wrote `ORDER BY MEASURE(on_time_delivery_rate)` and `HAVING MEASURE(...)`. Error: `[METRIC_VIEW_INVALID_MEASURE_FUNCTION_INPUT] The MEASURE() (or AGG()) function only takes an attribute as input, but got "on_time_delivery_rate"`. |
| 5 | Correct | 9.6 h in May to 12.9 h in October, peak 13.1 h in August. |

Score: 4 of 5. The traps did not catch Genie because the metadata already steered it: metric view comments
and synonyms, and the "NOT certified" comment on the bronze table.

**Fix:** added the general instructions from `genie/instructions.md` to the space, including a rule to compute a
measure once in SELECT and use its alias in ORDER BY and HAVING, with an example query.

### Round 2: 2026-11-04, with instructions

| # | Result | What Genie did |
|---|---|---|
| 1 | Correct | Plant A 1,555, Plant B 1,680, Plant C 1,626. |
| 2 | Correct | 2.9%, 8.0%, 4.2%. |
| 3 | Correct | 11.0%, and explained it as "required rework at any inspection", the governed definition. |
| 4 | Correct | Computed `MEASURE(on_time_delivery_rate)` once and ranked it with `RANK() OVER`: Plant C, 72.6%. |
| 5 | Correct | 9.6 h in May, peak 13.1 h in August, 12.9 h in October. |

Score: 5 of 5.

### Round 3: 2026-11-04, final space (uncertified bronze table removed, instructions kept)

Data sources: the metric view and the five certified gold tables only.

| # | Result | Answer |
|---|---|---|
| 1 | Correct | Plant A 1,555, Plant B 1,680, Plant C 1,626 |
| 2 | Correct | 2.9%, 8.0%, 4.2% |
| 3 | Correct | 11.0% |
| 4 | Correct | Plant C, 72.6% |
| 5 | Correct | 9.6 h in May, peak 13.1 h in August, 12.9 h in October |

Score: 5 of 5. The final space contains certified data only, as defence in depth next to the instructions.
