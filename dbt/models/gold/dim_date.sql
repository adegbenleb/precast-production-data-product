-- One row per calendar day, covering the simulated period with margin for late deliveries.

with days as (
    select explode(sequence(date'2026-01-01', date'2027-12-31', interval 1 day)) as date_day
)

select
    date_day as date_key,
    date_day,
    year(date_day) as year,
    quarter(date_day) as quarter,
    month(date_day) as month,
    date_format(date_day, 'MMMM') as month_name,
    date_trunc('month', date_day)::date as month_start,
    date_format(date_day, 'yyyy-MM') as year_month,
    weekofyear(date_day) as iso_week,
    date_trunc('week', date_day)::date as week_start,
    date_format(date_day, 'EEEE') as day_name,
    dayofweek(date_day) in (1, 7) as is_weekend
from days
