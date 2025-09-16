
SELECT
  query_id,
  round(query_duration_ms/1000,3) AS sec,
  read_rows, formatReadableSize(read_bytes) AS read_bytes,
  result_rows, ProfileEvents['SelectedMarks'] AS marks,
  written_rows, formatReadableSize(written_bytes) AS written_bytes,
  toString(exception) AS exception, is_initial_query, client_name, client_version
FROM system.query_log
WHERE type = 'QueryFinish'
  AND event_time > now() - INTERVAL 10 MINUTE
  AND query ILIKE '%log_app%'
ORDER BY event_time DESC
LIMIT 50;
