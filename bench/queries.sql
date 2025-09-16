
SELECT count() FROM default.log_app WHERE event_timestamp >= now() - INTERVAL 1 HOUR;
SELECT count() FROM default.log_app WHERE event_timestamp >= now() - INTERVAL 24 HOUR;
SELECT count() FROM default.log_app WHERE event_timestamp >= now() - INTERVAL 48 HOUR;
SELECT count() FROM default.log_app WHERE event_timestamp >= now() - INTERVAL 24 HOUR AND index='test_index' AND namespace='ns1';
SELECT count() FROM default.log_app WHERE event_timestamp >= now() - INTERVAL 24 HOUR AND body ILIKE '%key=42%';
SELECT namespace, count() AS c FROM default.log_app WHERE event_timestamp >= now() - INTERVAL 6 HOUR GROUP BY namespace ORDER BY c DESC LIMIT 10;
