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
