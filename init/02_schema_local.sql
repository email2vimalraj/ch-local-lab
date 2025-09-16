-- A main log table from where users query the logs
CREATE TABLE IF NOT EXISTS default.log_app
(
    `event_timestamp_ms` DateTime64(3) DEFAULT nowInBlock() CODEC(Delta(2), ZSTD(1)),
    `event_timestamp` DateTime DEFAULT toDateTime(event_timestamp_ms) CODEC(Delta(2), ZSTD(1)),
    `host` LowCardinality(String) CODEC(ZSTD(1)),
    `source` String CODEC(ZSTD(1)),
    `sourcetype` String CODEC(ZSTD(1)),
    `index` String CODEC(ZSTD(1)),
    `body` String CODEC(ZSTD(1)),
    `cluster_name` LowCardinality(String) CODEC(ZSTD(1)),
    `container_id` String CODEC(ZSTD(1)),
    `container_name` String CODEC(ZSTD(1)),
    `namespace` LowCardinality(String) CODEC(ZSTD(1)),
    `pod` String CODEC(ZSTD(1)),
    `resource_attributes` Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    `scope_attributes` Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    `log_attributes` Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    `camr_id` LowCardinality(String) CODEC(ZSTD(1)),
    `trace_id` String CODEC(ZSTD(1)),
    `span_id` String CODEC(ZSTD(1)),
    `_fluentbit_pod` String CODEC(ZSTD(1)),
    `_gateway_timestamp_ms` DateTime64(3) DEFAULT nowInBlock() CODEC(Delta(2), ZSTD(1)),
    `_clickhouse_timestamp_ms` DateTime64(3) DEFAULT nowInBlock() CODEC(Delta(2), ZSTD(1)),
    `_gateway_host` LowCardinality(String) CODEC(ZSTD(1)),
    `_kafka_timestamp_ms` DateTime64(3) DEFAULT nowInBlock() CODEC(Delta(2), ZSTD(1)),
    `_kafka_offset` String CODEC(ZSTD(1)),
    `_error_event_timestamp_ms` DateTime64(3) CODEC(Delta(2), ZSTD(1))

    INDEX idx_res_attr_key mapKeys(resource_attributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_res_attr_value mapValues(resource_attributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_scope_attr_key mapKeys(scope_attributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_scope_attr_value mapValues(scope_attributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_log_attr_key mapKeys(log_attributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_log_attr_value mapValues(log_attributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_body body TYPE tokenbf_v1(32768, 3, 0) GRANULARITY 8
)
ENGINE = MergeTree
PARTITION BY toDate(event_timestamp)
ORDER BY (camr_id, index, sourcetype, host, source, event_timestamp)
TTL 
    toDate(_clickhouse_timestamp_ms) + toIntervalDay(7) TO VOLUME 'cold', 
    toDate(_clickhouse_timestamp_ms) + toIntervalDay(30)
SETTINGS 
    index_granularity = 8192, 
    storage_policy = 'move_from_hot_to_cold', 
    ttl_only_drop_parts = 1;

CREATE OR REPLACE VIEW default.log_app_distributed AS SELECT * FROM default.log_app;

-- Skip the k8 events

-- Table to capture ingestion stats
CREATE TABLE IF NOT EXISTS default.log_app_ingestion_stats
(
    `event_timestamp` DateTime CODEC(Delta(2), ZSTD(1)),
    `camr_id` LowCardinality(String) CODEC(ZSTD(1)),
    `index` LowCardinality(String) CODEC(ZSTD(1)),
    `host` LowCardinality(String) CODEC(ZSTD(1)),
    `cluster_name` LowCardinality(String) CODEC(ZSTD(1)),
    `namespace` LowCardinality(String) CODEC(ZSTD(1)),
    `container_name` String CODEC(ZSTD(1)),
    `pod` String CODEC(ZSTD(1)),
    `source` String CODEC(ZSTD(1)),
    `sum_len_body` SimpleAggregateFunction(sumWithOverflow, UInt32),
    `count_total`  SimpleAggregateFunction(sumWithOverflow, UInt32),
    `_clickhouse_timestamp_ms` DateTime64(3) DEFAULT now() CODEC(Delta(2), ZSTD(1))
)
ENGINE = MergeTree
PARTITION BY toDate(event_timestamp)
ORDER BY (camr_id, index, cluster_name, namespace, host, container_name, pod, source, event_timestamp)
TTL
    toDate(_clickhouse_timestamp_ms) + toIntervalDay(7) TO VOLUME 'cold',
    toDate(_clickhouse_timestamp_ms) + toIntervalDay(365)
SETTINGS
    index_granularity = 8192,
    storage_policy = 'move_from_hot_to_cold',
    ttl_only_drop_parts = 1;

CREATE OR REPLACE VIEW default.log_app_ingestion_stats_distributed AS SELECT * FROM default.log_app_ingestion_stats;

-- Materialized view to read from `log_app` table and compute the ingestion size based on length of body and insert into `log_app_ingestion_stats`
CREATE MATERIALIZED VIEW IF NOT EXISTS default.mv_log_app_stats_stream TO default.log_app_ingestion_stats
AS
    SELECT
       toStartOfHour(event_timestamp_ms) AS event_timestamp,
       camr_id,
       index,
       host,
       cluster_name,
       namespace,
       container_name,
       pod,
       source,
       sum(length(body)) AS sum_len_body, -- Assumption: 1 char = 1 byte
       count() AS count_total
   FROM default.log_app
   GROUP BY
       camr_id,
       index,
       cluster_name,
       namespace,
       host,
       container_name,
       pod,
       source,
       toStartOfHour(event_timestamp_ms);

-- A table to store k8 events, the fields are normalized
CREATE TABLE IF NOT EXISTS log_k8_events (
    event_timestamp DateTime64(3) DEFAULT now() CODEC(Delta(2), ZSTD(1)),
    event_type LowCardinality(String) CODEC(ZSTD(1)),
    reason LowCardinality(String) CODEC(ZSTD(1)),
    message String CODEC(ZSTD(1)),
    `count` UInt64 CODEC(ZSTD(1)),
    kind LowCardinality(String) CODEC(ZSTD(1)),
    name String CODEC(ZSTD(1)),
    cluster_name LowCardinality(String) CODEC(ZSTD(1)),
    namespace LowCardinality(String) CODEC(ZSTD(1)),
    uid String CODEC(ZSTD(1)),
    field_path String CODEC(ZSTD(1)),
    source_component String CODEC(ZSTD(1)),
    host LowCardinality(String) CODEC(ZSTD(1)),
    source_host LowCardinality(String) CODEC(ZSTD(1)),
    reporting_component LowCardinality(String) CODEC(ZSTD(1)),
    reporting_instance LowCardinality(String) CODEC(ZSTD(1)),
    first_timestamp DATETIME64(3) DEFAULT now() CODEC(Delta(2), ZSTD(1)),
    last_timestamp DATETIME64(3) DEFAULT now() CODEC(Delta(2), ZSTD(1)),
    resource_version UInt64 CODEC(ZSTD(1)),
    body String CODEC(ZSTD(1)),
    `_fluentbit_pod` String CODEC(ZSTD(1)),
    `_gateway_timestamp_ms` DateTime64(3) DEFAULT now() CODEC(Delta(2), ZSTD(1)),
    `_clickhouse_timestamp_ms` DateTime64(3) DEFAULT now() CODEC(Delta(2), ZSTD(1)),
    `_gateway_host` LowCardinality(String) CODEC(ZSTD(1)),
    `_kafka_timestamp_ms` DateTime64(3) DEFAULT now() CODEC(Delta(2), ZSTD(1)),
    `_kafka_offset` String CODEC(ZSTD(1)),

    INDEX idx_body body TYPE tokenbf_v1(32768, 3, 0) GRANULARITY 8
)
    ENGINE = MergeTree
    PARTITION BY toDate(event_timestamp)
    ORDER BY (cluster_name, host, namespace, kind, name, reason, event_timestamp)
    TTL
        toDate(_clickhouse_timestamp_ms) + toIntervalDay(7) TO VOLUME 'cold',
        toDate(_clickhouse_timestamp_ms) + toIntervalDay(30)
    SETTINGS
        index_granularity = 8192,
        storage_policy = 'move_from_hot_to_cold',
        ttl_only_drop_parts = 1;

CREATE OR REPLACE VIEW default.log_k8_events_distributed AS SELECT * FROM default.log_k8_events;

-- Lookups database to store lookup tables using URL engine
CREATE DATABASE IF NOT EXISTS lookups;