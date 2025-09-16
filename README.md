
# ClickHouse Local Lab (Single Node, Ingestion + Monitoring)

## Start
```bash
docker compose up -d
```

## Create Kafka ingestion pipeline
```bash
docker exec -it ch-local clickhouse-client --multiquery --query "$(cat init/05_kafka_local.sql)"
```

## Verify ingestion
```bash
docker logs -f ch-producer
docker exec -it ch-local clickhouse-client --query "
  SELECT toStartOfMinute(event_timestamp) ts, count() c
  FROM default.log_app
  WHERE event_timestamp > now() - INTERVAL 10 MINUTE
  GROUP BY ts ORDER BY ts DESC LIMIT 20;"
```

## Run benchmarks during ingestion
```bash
docker exec -it ch-local clickhouse-client --multiquery --query "$(cat bench/queries.sql)"
docker exec -it ch-local clickhouse-client --query "$(cat bench/report.sql)"
```

## Upgrade test
```bash
CH_TAG=<new-lts-tag> docker compose up -d --force-recreate
```

## Notes
- Your storage policy from `storage_configuration.xml` is mounted.
- Schema was transformed for single-node; Kafka/MVs from your cluster schema are not used here.
- A generated view `default.log_app_distributed` points to `default.log_app`.
