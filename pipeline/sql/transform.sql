-- Transform layer for the Peloton pipeline.
-- These views sit on top of peloton.workouts_raw (the raw JSON payloads loaded
-- by peloton_pipeline.py) and expose a flat, query-friendly schema for the
-- MotherDuck MCP server. They are plain VIEWs, so they always reflect the
-- latest data with no refresh step required.

-- One flattened row per workout, extracted from the raw JSON payload.
CREATE OR REPLACE VIEW peloton.workouts_v AS
SELECT
  workout_id,
  start_time AS started_at,
  payload->>'$.workout_details'->>'$.ride_id' AS ride_id,
  payload->>'$.device_type' AS device_source,
  payload->>'$.ride_details'->'$.class_types[0]'->>'$.name' AS class_type,
  payload->>'$.workout_details'->'$.ride'->>'$.instructor_id' AS instructor_id,
  payload->>'$.ride_details'->'$.ride'->'$.instructor'->>'$.name' AS instructor_name,
  payload->'$.workout_details'->>'$.fitness_discipline' AS fitness_discipline,
  payload->'$.workout_details'->'$.ride'->'$.duration' AS duration_seconds,
  payload->>'$.workout_details'->'$.ride'->>'$.title' AS title,
  payload->>'$.workout_details'->'$.ride'->>'$.ride_type_id' AS ride_type_id,
  payload->>'$.workout_details'->'$.ride'->>'$.image_url' AS image_url,
  payload->>'$.ride_details'->'$.ride'->>'$.is_archived' AS available,
  payload->>'$.ride_details'->'$.ride'->>'$.is_favorite' AS bookmarked,
  CAST(payload->>'$.total_work' AS DOUBLE) AS joules,
  fetched_at
FROM
  peloton.workouts_raw;

-- Repeatedly-taken classes that are still bookmarked (never un-bookmarked).
-- num_taken = ended_bookmarked filters out classes that were later un-bookmarked.
CREATE OR REPLACE VIEW peloton.bookmarked_options AS
SELECT
  fitness_discipline,
  class_type,
  instructor_name,
  title,
  ride_id,
  duration_seconds,
  count(1) AS num_taken,
  max(started_at) AS last_taken_at,
  min(joules::DOUBLE) / 1000 AS lowest_kj,
  avg(joules::DOUBLE) / 1000 AS avg_kj,
  max(joules::DOUBLE) / 1000 AS max_kj,
  count(CASE WHEN bookmarked THEN 1 END) AS ended_bookmarked
FROM
  peloton.workouts_v
WHERE
  available
GROUP BY
  fitness_discipline, class_type, instructor_name, title, ride_id, duration_seconds
HAVING
  num_taken = ended_bookmarked
ORDER BY
  num_taken, last_taken_at;
