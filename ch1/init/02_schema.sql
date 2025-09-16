-- A main log table from where users query the logs
CREATE TABLE IF NOT EXISTS default.log_app ON CLUSTER ch_np_cluster
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
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/log_app', '{replica}')
PARTITION BY toDate(event_timestamp)
ORDER BY (camr_id, index, sourcetype, host, source, event_timestamp)
TTL 
    toDate(_clickhouse_timestamp_ms) + toIntervalDay(7) TO VOLUME 'cold', 
    toDate(_clickhouse_timestamp_ms) + toIntervalDay(30)
SETTINGS 
    index_granularity = 8192, 
    storage_policy = 'move_from_hot_to_cold', 
    ttl_only_drop_parts = 1;

-- Distributed table for log_app
CREATE TABLE IF NOT EXISTS default.log_app_distributed ON CLUSTER ch_np_cluster AS default.log_app
    ENGINE = Distributed('ch_np_cluster', 'default', 'log_app', rand());

-- Kafka Consumer table to consume data from Non-Container kafka topic
CREATE TABLE IF NOT EXISTS default.kafka_consumer_table_non_container_logs ON CLUSTER ch_np_cluster
(
    `resourceLogs` Array(
        Tuple(
            resource Tuple(
                attributes Array(
                    Tuple(
                        key String,
                        value Tuple(
                            stringValue String
                        )
                    )
                )
            ),
            scopeLogs Array(
                Tuple(
                    logRecords Array(
                        Tuple(
                            observedTimeUnixNano UInt64,
                            body Tuple(
                                stringValue String
                            ),
                            attributes Array(
                                Tuple(
                                    key String,
                                    value Tuple(
                                        stringValue String
                                    )
                                )
                            ),
                            traceId String,
                            spanId String
                        )
                    )
                )
            )
        )
    )
)
ENGINE = Kafka(
        kafka_non_container_preset, -- Named collection in kafka.xml
        kafka_group_name = 'non_container_np_clickhouse_20250516',
        kafka_format = 'JSONEachRow',
        kafka_num_consumers = 16,
        kafka_thread_per_consumer = 1
);

-- Materialized view to parse through the data from the non-container kafka table and insert into `log_app` table
CREATE MATERIALIZED VIEW IF NOT EXISTS default.mv_kafka_consumer_table_non_container_logs_to_log_app ON CLUSTER ch_np_cluster TO default.log_app
AS WITH
       arrayJoin(resourceLogs) AS resource_log,
       arrayJoin(resource_log.scopeLogs) AS scope_log,
       arrayJoin(scope_log.logRecords) AS log_record
   SELECT
       CASE
           WHEN toDate(toDateTime64(toUInt64(tupleElement(tupleElement(log_record.attributes[5], 'value'), 'stringValue')), 3)) < toDate(now())
               THEN now()
            WHEN toDateTime64(toUInt64(tupleElement(tupleElement(log_record.attributes[5], 'value'), 'stringValue')), 3) > now64()
               THEN now()
            ELSE toDateTime64(toUInt64(tupleElement(tupleElement(log_record.attributes[5], 'value'), 'stringValue')), 3)
       END AS event_timestamp_ms,
       toDateTime64(toUInt64(tupleElement(tupleElement(log_record.attributes[5], 'value'), 'stringValue')), 3) AS _error_event_timestamp_ms,
       tupleElement(tupleElement(log_record.attributes[3], 'value'), 'stringValue') AS host,
       tupleElement(tupleElement(log_record.attributes[4], 'value'), 'stringValue') AS source,
       tupleElement(tupleElement(log_record.attributes[2], 'value'), 'stringValue') AS sourcetype,
       tupleElement(tupleElement(log_record.attributes[1], 'value'), 'stringValue') AS index,
       tupleElement(tupleElement(log_record.attributes[6], 'value'), 'stringValue') AS body,
       toDateTime64(tupleElement(log_record, 'observedTimeUnixNano')/1e9, 3) AS _gateway_timestamp_ms,
       tupleElement(tupleElement(log_record.attributes[7], 'value'), 'stringValue') AS _gateway_host,
       _timestamp_ms AS _kafka_timestamp_ms,
       _offset AS _kafka_offset
   FROM default.kafka_consumer_table_non_container_logs;

-- Kafka Consumer table to consume data from Container kafka topic
CREATE TABLE IF NOT EXISTS default.kafka_container_consumer_table ON CLUSTER ch_np_cluster
(
    `time` DateTime64(9),
    `host` LowCardinality(String),
    `source` LowCardinality(String),
    `sourcetype` LowCardinality(String),
    `index` LowCardinality(String),
    `camr_id` Int32,
    `fields` String,
    `event` String
)
    ENGINE = Kafka(kafka_container_preset, -- Named collection in kafka.xml
                   kafka_group_name = 'clickhouse-np-kafka-consumer-group-20250520',
                   kafka_format = 'JSONEachRow',
                   kafka_num_consumers = 16,
                   kafka_thread_per_consumer = 1);

-- Materialized view to parse through the data from the container kafka table and insert into `log_app` table
CREATE MATERIALIZED VIEW IF NOT EXISTS default.mv_kafka_container_consumer_table_to_log_app ON CLUSTER ch_np_cluster TO default.log_app
AS
WITH
    -- Extract fields from JSON once
    JSONExtract(fields, 'Map(String, String)') AS field_map,
    field_map['cluster_name'] AS cluster_name,
    field_map['container_id'] AS container_id,
    field_map['pod'] AS extracted_pod,
    field_map['namespace'] AS extracted_namespace,
    field_map['container_name'] AS extracted_container_name,
    field_map['opera_gateway'] AS _gateway_host,
    field_map['fluentbit_pod'] AS _fluentbit_pod,

    -- Determine whether to parse from source path
    startsWith(source, '/var/log/containers') AS should_parse,
    CASE
        WHEN should_parse THEN replaceOne(splitByChar('/', source)[-1], '.log', '')
        ELSE ''
        END AS filename,

    -- Split filename: pod_namespace_containername-containerid
    splitByChar('_', filename) AS parts,
    parts[1] AS parsed_pod,
    parts[2] AS parsed_namespace,
    parts[3] AS container_and_id,

    -- Extract container_name from container_and_id using last dash
    position(reverse(container_and_id), '-') AS reverse_dash_pos,
    left(container_and_id, length(container_and_id) - reverse_dash_pos) AS parsed_container_name,

    -- Derived fields: only overwrite if original is empty
    CASE
        WHEN should_parse AND extracted_pod = ''
            THEN parsed_pod
        ELSE extracted_pod
        END AS pod,

    CASE
        WHEN should_parse AND extracted_namespace = ''
            THEN parsed_namespace
        ELSE extracted_namespace
        END AS namespace,

    CASE
        WHEN should_parse AND extracted_container_name = ''
            THEN parsed_container_name
        ELSE extracted_container_name
        END AS container_name
SELECT
    CASE
        WHEN toDate(time) < toDate(now())
            THEN now()
        WHEN time > now64()
            THEN now()
        ELSE time
    END AS event_timestamp_ms,
    time AS _error_event_timestamp_ms,
    host,
    source,
    sourcetype,
    index,
    event AS body,
    cluster_name,
    container_id,
    container_name,
    namespace,
    pod,
    _fluentbit_pod,
    _gateway_host,

    -- Remove known fields from resource_attributes
    mapFilter(
            (k, v) -> NOT (k IN [
                'opera_gateway',
                'fluentbit_pod',
                'pod',
                'namespace',
                'container_name',
                'container_id',
                'cluster_name'
                ]),
            field_map
    ) AS resource_attributes,

    camr_id,
    _timestamp_ms AS _kafka_timestamp_ms,
    _offset AS _kafka_offset
FROM default.kafka_container_consumer_table
WHERE
    sourcetype!='kube:object:events' AND index!='docee_nonprod_k8events'; -- Skip the k8 events

-- Table to capture ingestion stats
CREATE TABLE IF NOT EXISTS default.log_app_ingestion_stats ON CLUSTER ch_np_cluster
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
ENGINE =  ReplicatedMergeTree('/clickhouse/tables/{shard}/log_app_ingestion_stats', '{replica}')
PARTITION BY toDate(event_timestamp)
ORDER BY (camr_id, index, cluster_name, namespace, host, container_name, pod, source, event_timestamp)
TTL
    toDate(_clickhouse_timestamp_ms) + toIntervalDay(7) TO VOLUME 'cold',
    toDate(_clickhouse_timestamp_ms) + toIntervalDay(365)
SETTINGS
    index_granularity = 8192,
    storage_policy = 'move_from_hot_to_cold',
    ttl_only_drop_parts = 1;

-- Distributed table for log_app_ingestion_stats
CREATE TABLE IF NOT EXISTS default.log_app_ingestion_stats_distributed ON CLUSTER ch_np_cluster AS default.log_app_ingestion_stats
    ENGINE = Distributed('ch_np_cluster', 'default', 'log_app_ingestion_stats', rand());

-- Materialized view to read from `log_app` table and compute the ingestion size based on length of body and insert into `log_app_ingestion_stats`
CREATE MATERIALIZED VIEW IF NOT EXISTS default.mv_log_app_stats_stream ON CLUSTER ch_np_cluster TO default.log_app_ingestion_stats
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
CREATE TABLE IF NOT EXISTS log_k8_events ON CLUSTER ch_np_cluster (
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
    ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/log_k8_events', '{replica}')
    PARTITION BY toDate(event_timestamp)
    ORDER BY (cluster_name, host, namespace, kind, name, reason, event_timestamp)
    TTL
        toDate(_clickhouse_timestamp_ms) + toIntervalDay(7) TO VOLUME 'cold',
        toDate(_clickhouse_timestamp_ms) + toIntervalDay(30)
    SETTINGS
        index_granularity = 8192,
        storage_policy = 'move_from_hot_to_cold',
        ttl_only_drop_parts = 1;

-- A materialized view to consume from kafka container logs table and select only k8 events to insert into `log_k8_events` table
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_log_k8_events ON CLUSTER ch_np_cluster TO default.log_k8_events
AS
WITH
    JSONExtract(event, 'Map(String, String)') AS event_field_map,
    JSONExtract(event_field_map['object'], 'Map(String, String)') AS object_field_map,
    JSONExtract(object_field_map['metadata'], 'Map(String, String)') AS metadata_field_map,
    JSONExtract(object_field_map['source'], 'Map(String, String)') AS source_field_map,
    JSONExtract(object_field_map['involvedObject'], 'Map(String, String)') AS involved_object_field_map,
    JSONExtract(fields, 'Map(String, String)') AS field_map,

    field_map['cluster_name'] AS cluster_name,
    field_map['opera_gateway'] AS _gateway_host,
    field_map['fluentbit_pod'] AS _fluentbit_pod,

    ifNull(parseDateTime64BestEffortOrZero(object_field_map['lastTimestamp']), now()) AS last_timestamp,
    event_field_map['type'] AS event_type,
    object_field_map['reason'] AS reason,
    object_field_map['message'] AS message,
    toUInt64OrZero(object_field_map['count']) AS count,
    involved_object_field_map['kind'] AS kind,
    metadata_field_map['name'] AS name,
    involved_object_field_map['namespace'] AS namespace,
    involved_object_field_map['uid'] AS uid,
    involved_object_field_map['fieldPath'] AS field_path,
    source_field_map['component'] AS source_component,
    source_field_map['host'] AS source_host,
    object_field_map['reportingComponent'] AS reporting_component,
    object_field_map['reportingInstance'] AS reporting_instance,
    parseDateTime64BestEffortOrZero(object_field_map['firstTimestamp']) AS first_timestamp,
    parseDateTime64BestEffortOrZero(metadata_field_map['creationTimestamp']) AS timestamp,
    toUInt64OrZero(involved_object_field_map['resourceVersion']) AS resource_version
SELECT
    timestamp,
    event_type,
    reason,
    message,
    `count`,
    kind,
    name,
    namespace,
    uid,
    field_path,
    source_component,
    host,
    source_host,
    reporting_component,
    reporting_instance,
    first_timestamp,
    last_timestamp,
    resource_version,
    event AS body,
    cluster_name,
    _gateway_host,
    _fluentbit_pod,
    _timestamp_ms AS _kafka_timestamp_ms,
    _offset AS _kafka_offset
FROM default.kafka_container_consumer_table
WHERE
    sourcetype='kube:object:events' AND
    index='docee_nonprod_k8events';

-- Distributed table for log_k8_events
CREATE TABLE IF NOT EXISTS default.log_k8_events_distributed ON CLUSTER ch_np_cluster AS default.log_k8_events
    ENGINE = Distributed('ch_np_cluster', 'default', 'log_k8_events', rand());

-- Lookups database to store lookup tables using URL engine
CREATE DATABASE IF NOT EXISTS lookups ON CLUSTER ch_np_cluster;