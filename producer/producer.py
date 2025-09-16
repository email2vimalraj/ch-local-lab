
import os, json, time, random, string
from confluent_kafka import Producer

BROKER = os.getenv("BROKER", "redpanda:9092")
TOPIC = os.getenv("TOPIC", "logs")
RPS = float(os.getenv("RPS", "500"))
BURST = int(os.getenv("BURST", "1000"))

p = Producer({"bootstrap.servers": BROKER})

hosts = [f"host-{i}" for i in range(50)]
namespaces = ["ns1","ns2","payments","risk","auth"]
pods = [f"pod-{i}" for i in range(200)]
sourcetypes = ["app:json","nginx:json","worker:json"]

def rand_id(n=16):
    import random, string
    return ''.join(random.choice('0123456789abcdef') for _ in range(n))

def make_event(i):
    ts_ms = int(time.time()*1000)
    return {
        "ts_ms": ts_ms/1000.0,
        "host": random.choice(hosts),
        "source": "/var/log/app.log",
        "sourcetype": random.choice(sourcetypes),
        "idx": "test_index",
        "body": f"message {i} key={i % 1000} status={(i*7)%600}",
        "cluster_name": "np_cluster",
        "container_id": "",
        "container_name": "",
        "namespace": random.choice(namespaces),
        "pod": random.choice(pods),
        "camr_id": f"CAMR-{i % 100}",
        "trace_id": rand_id(),
        "span_id": rand_id(),
        "fb_pod": "fb-pod-1",
        "gw_host": "gw-local"
    }

def delivery(err, msg):
    if err is not None:
        print("Delivery failed:", err)

print(f"Producing to {BROKER} topic={TOPIC} at ~{RPS} msg/s")
interval = 1.0 / RPS if RPS > 0 else 0.0
i = 0
try:
    while True:
        for _ in range(max(1, int(RPS))):
            p.produce(TOPIC, json.dumps(make_event(i)), callback=delivery)
            i += 1
        p.poll(0)
        time.sleep(interval)
except KeyboardInterrupt:
    pass
finally:
    p.flush()
