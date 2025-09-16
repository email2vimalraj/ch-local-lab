
-- Kafka ingestion using Redpanda (topic 'logs')
DROP TABLE IF EXISTS default.kafka_logs_raw;
CREATE TABLE default.kafka_logs_raw
(
    ts_ms           Nullable(DateTime64(3)),
    host            String,
    source          String,
    sourcetype      String,
    idx             String,
    body            String,
    cluster_name    String,
    container_id    String,
    container_name  String,
    namespace       String,
    pod             String,
    camr_id         String,
    trace_id        String,
    span_id         String,
    fb_pod          String,
    gw_host         String
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'redpanda:9092',
    kafka_topic_list = 'logs',
    kafka_group_name = 'ch-local-consumer',
    kafka_format = 'JSONEachRow',
    kafka_num_consumers = 2,
    kafka_flush_interval_ms = 2000;

DROP TABLE IF EXISTS default.kafka_logs_buffer;
CREATE TABLE default.kafka_logs_buffer
(
    ts_ms           Nullable(DateTime64(3)),
    host            String,
    source          String,
    sourcetype      String,
    idx             String,
    body            String,
    cluster_name    String,
    container_id    String,
    container_name  String,
    namespace       String,
    pod             String,
    camr_id         String,
    trace_id        String,
    span_id         String,
    fb_pod          String,
    gw_host         String,
    _kafka_offset   String
)
ENGINE = MergeTree
ORDER BY (coalesce(ts_ms, now64(3)), host);

DROP VIEW IF EXISTS default.mv_kafka_to_buffer;
CREATE MATERIALIZED VIEW default.mv_kafka_to_buffer
TO default.kafka_logs_buffer
AS
SELECT
    ts_ms, host, source, sourcetype, idx, body, cluster_name, container_id, container_name,
    namespace, pod, camr_id, trace_id, span_id, fb_pod, gw_host,
    toString(_offset) AS _kafka_offset
FROM default.kafka_logs_raw;

DROP VIEW IF EXISTS default.mv_buffer_to_log_app;
CREATE MATERIALIZED VIEW default.mv_buffer_to_log_app
TO default.log_app
AS
SELECT
    coalesce(ts_ms, now64(3))                                       AS event_timestamp_ms,
    host, source, sourcetype, idx AS index, body,
    coalesce(cluster_name, 'np_cluster')                             AS cluster_name,
    coalesce(container_id, '')                                       AS container_id,
    coalesce(container_name, '')                                     AS container_name,
    coalesce(namespace, '')                                          AS namespace,
    coalesce(pod, '')                                                AS pod,
    map('env','np')                                                  AS resource_attributes,
    map('scope','kafka')                                             AS scope_attributes,
    map()                                                            AS log_attributes,
    coalesce(camr_id, 'CAMR-0')                                      AS camr_id,
    coalesce(trace_id, '')                                           AS trace_id,
    coalesce(span_id, '')                                            AS span_id,
    coalesce(fb_pod, 'fb-pod')                                       AS _fluentbit_pod,
    coalesce(gw_host, 'gw-local')                                     AS _gateway_host,
    _kafka_offset,
    now64(3)                                                         AS _error_event_timestamp_ms;
