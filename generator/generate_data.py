"""Generate simulated precast production data with deliberate data problems.

Usage:
    uv run python generator/generate_data.py [output_dir]   (default: data/raw)

Everything here is simulated. Plants, projects and cities are invented.
A fixed seed makes the output identical on every run, so KPI answers are known.

Planted problems (see docs/PROJECT_SPEC.md section 4):
  1. Plant name variants in production_orders.plant ("Plant A", " plant a", "PLANT A", "Plant-A")
  2. Duplicate production orders, the second copy with a later updated_at
  3. Late-arriving inspections: monthly inspection files, some rows land in a later month's file
  4. Weight unit mix-up: some weights in kg instead of t, with no unit column
  5. Blank strings and missing values: missing due_date, whitespace-only project_id
  6. A plant-reported daily output table that counts scrap as output
"""

import csv
import random
import sys
from collections import Counter, defaultdict
from datetime import date, datetime, timedelta
from pathlib import Path

SEED = 42
START = date(2026, 5, 1)
END = date(2026, 10, 31)
CUTOFF = datetime(2026, 10, 31, 23, 59, 59)  # extract time: nothing after this has happened yet

PLANTS = [
    ("P01", "Plant A", "North"),
    ("P02", "Plant B", "Central"),
    ("P03", "Plant C", "South"),
]
# code, description, typical weight in t, typical cycle time in hours
ELEMENT_TYPES = [
    ("HCS", "hollow-core slab", 5.0, 6),
    ("FIL", "filigree slab", 3.0, 5),
    ("SWP", "sandwich wall panel", 7.0, 14),
    ("COL", "precast column", 4.0, 8),
    ("PBM", "prestressed beam", 8.0, 12),
    ("DTS", "double-tee slab", 12.0, 16),
    ("STR", "stair element", 3.0, 9),
]
CITIES = ["Northbridge", "Lakeside", "Eastford", "Millbrook", "Westhaven", "Stonebury"]
BUILDING_TYPES = ["residential", "office", "school", "hospital", "parking garage", "warehouse"]

# First inspection result probabilities per plant: pass, rework, scrap. Plant B has the quality problem.
FIRST_RESULT = {"P01": (0.92, 0.06, 0.02), "P02": (0.82, 0.11, 0.07), "P03": (0.90, 0.07, 0.03)}
DEFECTS = ["crack", "honeycombing", "dimension out of tolerance", "exposed rebar", "surface finish"]


def ts(value: datetime) -> str:
    return value.strftime("%Y-%m-%d %H:%M:%S")


def write_csv(path: Path, header: list[str], rows: list[list]) -> None:
    with path.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(rows)


def plant_name_variant(rng: random.Random, name: str) -> str:
    """Problem 1: about 30% of rows spell the plant name differently."""
    if rng.random() < 0.70:
        return name
    letter = name.split()[-1]
    return rng.choice([f" plant {letter.lower()}", name.upper(), f"Plant-{letter}"])


def generate(out: Path) -> None:
    rng = random.Random(SEED)
    out.mkdir(parents=True, exist_ok=True)
    stats = Counter()

    # Reference files: plants, element types, projects
    write_csv(out / "plants.csv", ["plant_id", "plant_name", "region"], [list(p) for p in PLANTS])
    write_csv(
        out / "element_types.csv",
        ["element_type_code", "description", "weight_unit"],
        [[code, desc, "t"] for code, desc, _, _ in ELEMENT_TYPES],
    )
    projects = []
    for i in range(1, 19):
        projects.append([f"PRJ{i:03d}", f"Project {i:03d}", rng.choice(CITIES), rng.choice(BUILDING_TYPES)])
    write_csv(out / "projects.csv", ["project_id", "project_name", "site_city", "building_type"], projects)
    project_city = {p[0]: p[2] for p in projects}

    # Production orders
    orders, elements, inspections, deliveries = [], [], [], []
    order_rows = []
    order_no = 0
    day = START
    while day <= END - timedelta(days=6):
        for plant_id, plant_name, _ in PLANTS:
            for _ in range(rng.choice([0, 1, 1, 2])):
                order_no += 1
                order_id = f"ORD{order_no:05d}"
                project_id = rng.choice(projects)[0]
                code, _, base_weight, base_cycle = rng.choice(ELEMENT_TYPES)
                quantity = rng.randint(3, 15)
                planned_start = datetime.combine(day, datetime.min.time()) + timedelta(hours=6)
                # 12 to 30 days gives about 87% on time overall, with Plant C clearly worse
                due_date = (planned_start + timedelta(days=rng.randint(12, 30))).date()
                created = planned_start - timedelta(days=rng.randint(5, 20))
                orders.append((order_id, plant_id, project_id, code, quantity, planned_start, due_date))

                # Problem 5: missing due dates and whitespace-only project ids
                due_text = "" if rng.random() < 0.03 else due_date.isoformat()
                project_text = "   " if rng.random() < 0.02 else project_id
                stats["missing_due_date"] += due_text == ""
                stats["blank_project_id"] += project_text.strip() == ""
                row = [
                    order_id,
                    plant_name_variant(rng, plant_name),
                    project_text,
                    code,
                    quantity,
                    ts(planned_start),
                    due_text,
                    ts(created),
                ]
                order_rows.append(row)

                # Problem 2: a second copy of the order, updated later, sometimes with a revised due date
                if rng.random() < 0.04:
                    revised = list(row)
                    revised[1] = plant_name_variant(rng, plant_name)
                    if due_text and rng.random() < 0.5:
                        revised[6] = (due_date + timedelta(days=7)).isoformat()
                    revised[7] = ts(created + timedelta(days=rng.randint(1, 5), hours=rng.randint(1, 8)))
                    order_rows.append(revised)
                    stats["duplicate_orders"] += 1

                # Produced elements for this order
                months_in = (day.year - START.year) * 12 + day.month - START.month
                cycle_factor = {"P01": 1.0, "P02": 1.05, "P03": 1.0 + 0.05 * months_in}[plant_id]
                start = planned_start + timedelta(days=rng.randint(0, 2), hours=rng.randint(0, 6))
                for n in range(1, quantity + 1):
                    cycle = base_cycle * cycle_factor * rng.uniform(0.8, 1.25)
                    end = start + timedelta(hours=cycle)
                    if end > CUTOFF:
                        break
                    element_id = f"{order_id}-{n:02d}"
                    weight_t = round(base_weight * rng.uniform(0.85, 1.15), 3)
                    # Problem 4: about 10% of weights are written in kg, with no unit column
                    if rng.random() < 0.10:
                        weight_text = f"{weight_t * 1000:.0f}"
                        stats["weight_in_kg"] += 1
                    else:
                        weight_text = f"{weight_t:.3f}"
                    elements.append([element_id, order_id, ts(start), ts(end), weight_text])
                    stats["elements"] += 1
                    start += timedelta(hours=rng.uniform(4, 14))

                    # Quality inspections: rework leads to a second inspection (pass or scrap)
                    p_pass, p_rework, _ = FIRST_RESULT[plant_id]
                    # Sandwich wall panels (insulation layer, visible facade) are the hardest to get right
                    if code == "SWP":
                        p_pass, p_rework = p_pass - 0.04, p_rework + 0.04
                    roll = rng.random()
                    first = "pass" if roll < p_pass else "rework" if roll < p_pass + p_rework else "scrap"
                    inspected_at = end + timedelta(hours=rng.uniform(2, 30))
                    if inspected_at > CUTOFF:
                        continue
                    results = [(first, inspected_at)]
                    if first == "rework":
                        second_at = inspected_at + timedelta(days=rng.uniform(1, 3))
                        if second_at <= CUTOFF:
                            results.append(("pass" if rng.random() < 0.85 else "scrap", second_at))
                    for result, at in results:
                        inspections.append([element_id, at, result, "" if result == "pass" else rng.choice(DEFECTS)])

                    # Deliveries: only elements whose final result is pass
                    final_result, final_at = results[-1]
                    if final_result == "pass":
                        delay = rng.uniform(1, 14) + (rng.uniform(0, 12) if plant_id == "P03" else 0)
                        delivered_at = max(final_at, end) + timedelta(days=delay)
                        if delivered_at <= CUTOFF:
                            deliveries.append([element_id, ts(delivered_at), project_city[project_id]])
        day += timedelta(days=1)

    write_csv(
        out / "production_orders.csv",
        [
            "order_id",
            "plant",
            "project_id",
            "element_type_code",
            "quantity",
            "planned_start",
            "due_date",
            "updated_at",
        ],
        order_rows,
    )
    write_csv(
        out / "produced_elements.csv",
        ["element_id", "order_id", "production_start", "production_end", "weight"],
        elements,
    )

    # Problem 3: inspections arrive as monthly extract files. Most land in the file for the month
    # they happened; about 5% arrive 20 to 45 days late, in a later month's file.
    by_file = defaultdict(list)
    for i, (element_id, at, result, defect) in enumerate(sorted(inspections, key=lambda r: r[1]), 1):
        received = at
        if rng.random() < 0.05:
            received = at + timedelta(days=rng.uniform(20, 45))
        if received > CUTOFF:
            received = CUTOFF
        # Count after the cutoff clamp, so the number matches what actually lands in the files
        stats["late_inspections"] += received.month != at.month
        by_file[received.strftime("%Y_%m")].append([f"INS{i:06d}", element_id, ts(at), result, defect])
    for month, rows in sorted(by_file.items()):
        write_csv(
            out / f"quality_inspections_{month}.csv",
            ["inspection_id", "element_id", "inspected_at", "result", "defect_type"],
            rows,
        )
    stats["inspections"] = len(inspections)

    write_csv(
        out / "deliveries.csv",
        ["delivery_id", "element_id", "delivered_at", "site_city"],
        [[f"DEL{i:06d}", *row] for i, row in enumerate(deliveries, 1)],
    )
    stats["deliveries"] = len(deliveries)

    # Problem 6: plants report their own daily output, counting every produced element, scrap included,
    # with their own spelling of the plant name.
    order_plant = {o[0]: o[1] for o in orders}
    plant_name = {p[0]: p[1] for p in PLANTS}
    daily = Counter()
    for element_id, order_id, _, end_text, _ in elements:
        daily[(end_text[:10], order_plant[order_id])] += 1
    write_csv(
        out / "plant_daily_output_report.csv",
        ["report_date", "plant", "elements_produced"],
        [[d, plant_name_variant(rng, plant_name[p]), n] for (d, p), n in sorted(daily.items())],
    )

    stats["orders"] = len(orders)
    print(f"Wrote files to {out}/")
    for f in sorted(out.glob("*.csv")):
        print(f"  {f.name:40s} {sum(1 for _ in f.open()) - 1:6d} rows")
    print("Planted problems:")
    print(f"  1. plant name variants: {len({r[1] for r in order_rows})} distinct spellings for 3 plants")
    print(f"  2. duplicate orders: {stats['duplicate_orders']} orders appear twice")
    print(f"  3. late inspections: {stats['late_inspections']} rows in a later month's file")
    print(f"  4. weights in kg: {stats['weight_in_kg']} of {stats['elements']} elements")
    print(
        f"  5. missing due_date: {stats['missing_due_date']}, whitespace project_id: {stats['blank_project_id']}"
    )
    print("  6. plant_daily_output_report.csv counts scrap as output")


if __name__ == "__main__":
    generate(Path(sys.argv[1] if len(sys.argv) > 1 else "data/raw"))
