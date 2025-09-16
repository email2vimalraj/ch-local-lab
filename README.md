# ClickHouse Local Lab (Single Node, LTS)

This bundle spins up a **single ClickHouse node** (default tag: `24.8.12.28-lts`), loads a **single-node version of your schema**, and gives you parametric **data generation** + **bench queries** to validate performance and later compare upgrades/config changes.

## 1) Start

```bash
cd ch-local-lab
docker compose up -d
# Wait for healthy
docker compose logs -f clickhouse
```

> To try another version (e.g., next LTS), override the env var:

```bash
CH_TAG=24.xx.yy.zz-lts docker compose up -d --force-recreate
```

## 2) Load sample data

Insert N rows using the param-driven generator:

```bash
# 1 million rows
docker exec -it ch-local clickhouse-client --query "
  INSERT INTO default.log_app (
    event_timestamp_ms, host, source, sourcetype, index, body, cluster_name, container_id, container_name,
    namespace, pod, resource_attributes, scope_attributes, log_attributes, camr_id, trace_id, span_id,
    _fluentbit_pod, _gateway_host, _kafka_offset, _error_event_timestamp_ms
  )
  SELECT * FROM generate_log_rows({rows:UInt64})
" --param_rows=1000000
```

You can repeat with larger `--param_rows` values to scale up (e.g., 5–10M on a beefy laptop).

## 3) Run bench queries

```bash
docker exec -it ch-local clickhouse-client --multiquery --query "
  SET log_queries=1;
  $(cat bench/queries.sql)
"
# Then pull a quick report from system.query_log:
docker exec -it ch-local clickhouse-client --query "$(cat bench/report.sql)"
```

## 4) Try your controls (one-by-one)

- **Settings profiles / quotas / workload lanes**: copy your SQL here and `docker exec` to apply.
- Re-run step 3 and compare `read_rows`, `read_bytes`, `sec` from `system.query_log`.

## Notes

- The schema was **auto-transformed** to single-node:
  - `ON CLUSTER` removed
  - `ReplicatedMergeTree(...)` → `MergeTree`
  - `Distributed(...)` tables replaced by **views** pointing to the local base tables
  - Kafka/MV ingestion objects are **omitted** in this lab
- The distributed alias `default.log_app_distributed` is created as a **view** of `default.log_app` so your queries work unchanged.
- Your storage policy from `storage_configuration.xml` is mounted to keep TTL behavior consistent.

## Git Hygiene / Ignored Paths

The repo includes a `.gitignore` tuned for this lab so you don't accidentally commit ephemeral or bulky runtime artifacts:

- `data_dir/` – local ClickHouse parts & metadata generated at runtime
- `logs/` – container / ClickHouse logs
- `bench/*.csv|tsv|json|out|log` – benchmark result exports (SQL definitions remain tracked)
- `prometheus-data/` – optional Prometheus TSDB if you map one
- `grafana/grafana.db` – Grafana's local SQLite state
- Generic `*.log`, temporary `*.tmp|*.bak|*.old` files
- Editor folders: `.vscode/`, `.idea/`, swap files
- System cruft: `.DS_Store`
- Local override configs under `config/local/`
- Environment files `*.env` except any template like `env.example`

Initialization SQL in `init/`, schema/data SQL in `data/`, and configuration XML under `config/` are explicitly whitelisted so they always remain under version control.
