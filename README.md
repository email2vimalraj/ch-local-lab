
# ClickHouse Cluster Lab — 2 Shards × 2 Replicas

## Topology
- Keeper quorum: 3 nodes (keeper1..3) on 9181
- ClickHouse: 4 nodes ch1..ch4 (2 shards × 2 replicas)
  - Shard 1: ch1 (replica1), ch2 (replica2)
  - Shard 2: ch3 (replica1), ch4 (replica2)
- Monitoring: Prometheus (9090) + Grafana (3000, admin/admin)
- Kafka: Redpanda (9092) + Python producer (RPS env)

## Start
```bash
docker compose up -d
# wait till all four CH nodes are healthy
```

## Initialize schema (run ONCE against ch1; ON CLUSTER propagates)
```bash
docker exec -it ch1 clickhouse-client --multiquery --query "$(cat /docker-entrypoint-initdb.d/01_init.sql)"
docker exec -it ch1 clickhouse-client --multiquery --query "$(cat /docker-entrypoint-initdb.d/02_schema.sql)"
docker exec -it ch1 clickhouse-client --multiquery --query "$(cat /docker-entrypoint-initdb.d/03_udf.sql)"
```

> If your SQL already includes ON CLUSTER, the above will apply to all 4 nodes.

## Ingestion via Kafka
Create local lab Kafka ingestion (simple JSONEachRow → buffer → log_app). Run on ch1:
```bash
docker exec -it ch1 clickhouse-client --multiquery --query "
CREATE DATABASE IF NOT EXISTS default;
$(cat /docker-entrypoint-initdb.d/05_kafka_local.sql)
"
```

Producer is already sending ~2000 msg/s. Tune rate:
- Edit `docker-compose.yml` -> `producer` env `RPS=<value>`
- `docker compose up -d --force-recreate --no-deps producer`

## Validate
- `http://localhost:3000` Grafana (admin/admin)
- Prometheus targets should show ch1..ch4 & node exporters
- Run queries from ch1:
```bash
clickhouse-client -h localhost --port 9000 --query "SELECT count() FROM default.log_app"
```

## Notes
- Cluster name: `ch_np_cluster` (matches remote_servers & macros)
- Replication uses Keeper at keeper1..3
- Prometheus endpoint on each node: `:9363/metrics`
