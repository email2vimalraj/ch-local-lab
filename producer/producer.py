
import os, json, time, random
from confluent_kafka import Producer

BROKER = os.getenv("BROKER", "redpanda:9092")
TOPIC = os.getenv("TOPIC", "logs")
RPS = float(os.getenv("RPS", "1000"))
p = Producer({"bootstrap.servers": BROKER})

hosts = [f"host-{i}" for i in range(200)]
namespaces = ["ns1","ns2","payments","risk","auth"]
pods = [f"pod-{i}" for i in range(1000)]
sourcetypes = ["app:json","nginx:json","worker:json"]

def make_event(i):
    ts_ms = int(time.time()*1000) / 1000.0
    return {
        "ts_ms": ts_ms,
        "host": random.choice(hosts),
        "source": "/var/log/app.log",
        "sourcetype": random.choice(sourcetypes),
        "idx": "test_index",
        "body": f"message {i} key={i % 1000}",
        "cluster_name": "np_cluster",
        "container_id": "",
        "container_name": "",
        "namespace": random.choice(namespaces),
        "pod": random.choice(pods),
        "camr_id": f"CAMR-{i % 100}",
        "trace_id": f"{i:016x}",
        "span_id": f"{(i*7)%2**64:016x}",
        "fb_pod": "fb-pod-1",
        "gw_host": "gw-local"
    }

print(f"Producing to {BROKER} topic={TOPIC} at ~{RPS} msg/s")
i = 0
try:
    while True:
        for _ in range(int(max(1,RPS))):
            p.produce(TOPIC, json.dumps(make_event(i)))
            i += 1
        p.poll(0)
        time.sleep(1.0)
except KeyboardInterrupt:
    pass
finally:
    p.flush()
