# Peloton Workout History — Claude Context

You have access to my personal Peloton workout history stored in MotherDuck via the `motherduck` MCP server. The data lives in the `peloton` schema.

## How to query

Use the `query` tool with standard SQL (DuckDB dialect). Always prefix table references with `peloton.` (e.g. `SELECT * FROM peloton.workouts_v LIMIT 5`).

Prefer the flattened views below over the raw table. The underlying `peloton.workouts_raw` table stores the full JSON payload per workout and is only needed for fields not yet surfaced in the views.

Useful DuckDB functions:
- `date_trunc('month', started_at)` for monthly grouping
- `strftime(started_at, '%A')` for day-of-week
- `now() - INTERVAL 90 DAYS` for relative date filters
- `datediff('day', a, b)` for date math

## Schema

### `peloton.workouts_v` — one flattened row per workout

```
workout_id          VARCHAR    Unique ID for this workout session
started_at          TIMESTAMP  When the workout started
ride_id             VARCHAR    ID of the underlying class/ride
device_source       VARCHAR    Device used (Bike, Bike+, Tread, iOS, Android, Web, ...)
class_type          VARCHAR    Class category/type name
instructor_id       VARCHAR    Instructor ID
instructor_name     VARCHAR    Instructor full name
fitness_discipline  VARCHAR    cycling, running, strength, yoga, meditation, etc.
duration_seconds    BIGINT     Scheduled class length, in seconds
title               VARCHAR    Full class title
ride_type_id        VARCHAR    Peloton ride-type identifier
image_url           VARCHAR    Class thumbnail URL
available           BOOLEAN    Whether the class is still available (not archived)
bookmarked          BOOLEAN    Whether the class was bookmarked/favorited at workout time
joules              DOUBLE     Total work output in joules (cycling); divide by 1000 for kJ
fetched_at          TIMESTAMP  When this row was last synced from Peloton
```

**Notes:**
- `joules` is total work output and is meaningful mostly for cycling. Report it in **kilojoules** (`joules / 1000`) — that matches Peloton's "Total Output" figure.
- `duration_seconds` is the class's scheduled length; divide by 60 for minutes.
- `available` is derived from the class's archive status (an available class is one that is not archived).

### `peloton.bookmarked_options` — repeatedly-taken classes still bookmarked

Aggregated from `workouts_v`. Each row is a distinct class (`ride_id`) that is still available and was **never un-bookmarked** (the view keeps only classes where every time it was taken it ended bookmarked).

```
fitness_discipline  VARCHAR    Discipline
class_type          VARCHAR    Class type/category
instructor_name     VARCHAR    Instructor
title               VARCHAR    Class title
ride_id             VARCHAR    Class ID
duration_seconds    BIGINT     Class length in seconds
num_taken           BIGINT     How many times this class was taken
last_taken_at       TIMESTAMP  Most recent time taken
lowest_kj           DOUBLE     Lowest output across takes, in kJ
avg_kj              DOUBLE     Average output across takes, in kJ
max_kj              DOUBLE     Best output across takes, in kJ
ended_bookmarked    BIGINT     Times the class ended bookmarked (equals num_taken by definition)
```

### `peloton.workouts_raw` — raw source (advanced)

```
workout_id  VARCHAR    Primary key
start_time  TIMESTAMP  Workout start
payload     JSON       Full enriched workout payload from the Peloton API
fetched_at  TIMESTAMP  When the row was last synced
```

Use this only to extract fields not present in `workouts_v`, via JSON path access
(e.g. `payload->>'$.workout_details'->'$.ride'->>'$.title'`).

## Query patterns for common questions

**Favorite classes I keep coming back to:**
```sql
SELECT title, instructor_name, num_taken, last_taken_at, avg_kj
FROM peloton.bookmarked_options
ORDER BY num_taken DESC, last_taken_at DESC
LIMIT 10
```

**Most-used instructors:**
```sql
SELECT instructor_name, COUNT(*) AS workouts
FROM peloton.workouts_v
WHERE instructor_name IS NOT NULL
GROUP BY 1
ORDER BY workouts DESC
LIMIT 10
```

**Monthly cycling output trend (kJ):**
```sql
SELECT date_trunc('month', started_at) AS month,
       AVG(joules) / 1000 AS avg_kj,
       COUNT(*) AS rides
FROM peloton.workouts_v
WHERE fitness_discipline = 'cycling' AND joules IS NOT NULL
GROUP BY 1
ORDER BY 1
```

**Workout count by day of week:**
```sql
SELECT strftime(started_at, '%A') AS day_of_week,
       COUNT(*) AS workouts
FROM peloton.workouts_v
GROUP BY 1
ORDER BY MIN(dayofweek(started_at))
```

**Bookmarked classes I haven't taken in over a year:**
```sql
SELECT title, instructor_name, fitness_discipline, last_taken_at
FROM peloton.bookmarked_options
WHERE last_taken_at < now() - INTERVAL 365 DAYS
ORDER BY last_taken_at ASC
```

## Behavior guidelines

- For **trends over time**, always include a time axis (`started_at`) in the query.
- For questions about **instructors or repeated classes**, prefer the views over the raw table — they're already shaped for it.
- Report output in **kilojoules** (`joules / 1000`), and clarify it's *total output*, not average watts.
- Convert `duration_seconds` to minutes when presenting class lengths.
- Format dates as **Month D, YYYY** (e.g. "March 4, 2024"), not ISO.
- If a query returns more than ~20 rows, summarize the key findings instead of listing everything.
- If a question needs a field not in the views, fall back to `workouts_raw.payload` with JSON path extraction.
