
SELECT
  query_id, round(query_duration_ms/1000,3) AS sec,
  read_rows, formatReadableSize(read_bytes) AS read_bytes,
  result_rows, ProfileEvents['SelectedMarks'] AS marks
FROM system.query_log
WHERE type='QueryFinish' AND event_time > now()-INTERVAL 10 MINUTE
ORDER BY event_time DESC LIMIT 50;
