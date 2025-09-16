
-- Warmup & basic counts
SELECT count() FROM default.log_app WHERE event_timestamp >= now() - INTERVAL 1 HOUR;

-- Scan last 24h with lightweight projection (time filter only)
SELECT count() FROM default.log_app WHERE event_timestamp >= now() - INTERVAL 24 HOUR;

-- 2-day window, simulate a "wide" scan (avoid SELECT *)
SELECT count() FROM default.log_app WHERE event_timestamp >= now() - INTERVAL 48 HOUR;

-- Metadata filter (uses minmax indexes once populated)
SELECT count() FROM default.log_app WHERE event_timestamp >= now() - INTERVAL 24 HOUR AND index='test_index' AND namespace='ns1';

-- Token bloom on body
SELECT count() FROM default.log_app WHERE event_timestamp >= now() - INTERVAL 24 HOUR AND body ILIKE '%key=42%';

-- Group-by shape
SELECT namespace, count() AS c FROM default.log_app WHERE event_timestamp >= now() - INTERVAL 6 HOUR GROUP BY namespace ORDER BY c DESC LIMIT 10;
