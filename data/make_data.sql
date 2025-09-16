
CREATE OR REPLACE VIEW generate_log_rows AS
SELECT
    now64(3) - toIntervalSecond(intDiv(number,1000)%172800) AS event_timestamp_ms,
    concat('host-', toString(intDiv(number,1000))) AS host,
    '/var/log/app.log' AS source,
    'app:json' AS sourcetype,
    'test_index' AS index,
    concat('message ', toString(number), ' key=', toString(number%1000)) AS body,
    'np_cluster' AS cluster_name,
    '' AS container_id, '' AS container_name,
    'ns1' AS namespace,
    concat('pod-', toString(intDiv(number,10000))) AS pod,
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
