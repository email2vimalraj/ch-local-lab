
-- Param-driven data generator for default.log_app
-- Usage example:
--   clickhouse-client --query="SET max_insert_block_size=100000; \
--     INSERT INTO default.log_app (event_timestamp_ms, host, source, sourcetype, index, body, cluster_name, container_id, container_name, namespace, pod, resource_attributes, scope_attributes, log_attributes, camr_id, trace_id, span_id, _fluentbit_pod, _gateway_host, _kafka_offset, _error_event_timestamp_ms) \
--     SELECT * FROM generate_log_rows({rows:UInt64})" --param_rows=1000000
-- The helper view returns exactly the column list required, in correct order.

DROP VIEW IF EXISTS generate_log_rows;
CREATE VIEW generate_log_rows AS
WITH
    now64(3) AS now_ms,
    172800 AS horizon_s  -- 2 days
SELECT
    (now_ms - toIntervalSecond(intDiv(number, 1000) % horizon_s)) AS event_timestamp_ms,
    concat('host-', toString(intDiv(number, 1000))) AS host,
    '/var/log/app.log' AS source,
    'app:json' AS sourcetype,
    'test_index' AS index,
    concat('message ', toString(number), ' key=', toString(number % 1000)) AS body,
    'np_cluster' AS cluster_name,
    '' AS container_id,
    '' AS container_name,
    'ns1' AS namespace,
    concat('pod-', toString(intDiv(number, 10000))) AS pod,
    map('env','np','team','logs') AS resource_attributes,
    map('scope','default') AS scope_attributes,
    map('k','v') AS log_attributes,
    concat('CAMR-', toString(number % 100)) AS camr_id,
    hex(MD5(toString(number))) AS trace_id,
    hex(MD5(concat('s', toString(number)))) AS span_id,
    'fb-pod-1' AS _fluentbit_pod,
    'gw-local' AS _gateway_host,
    toString(number) AS _kafka_offset,
    now64(3) AS _error_event_timestamp_ms
FROM numbers({rows:UInt64});

-- Convenience procedure-style INSERT using the above view
DROP TABLE IF EXISTS tmp_generate_rows;
CREATE TABLE tmp_generate_rows AS
SELECT *
FROM generate_log_rows
LIMIT 0;

-- Helper: insert N rows quickly
-- Example: clickhouse-client --query="INSERT INTO default.log_app (...) SELECT * FROM generate_log_rows(500000)"
