#!/usr/bin/env python3
import json, subprocess, sys

# Query 1: CPU metric labels for ml-scaler
r = subprocess.run(['curl', '-s', 'http://localhost:9090/api/v1/query?query=container_cpu_usage_seconds_total{pod=~"ml-scaler.*"}'], capture_output=True, text=True)
d = json.loads(r.stdout)
print("=== CPU METRICS FOR ML-SCALER ===")
print(f"Results: {len(d['data']['result'])}")
for res in d['data']['result']:
    m = res['metric']
    print(f"  container={m.get('container','MISSING')!r}  pod={m.get('pod','?')}  cpu={m.get('cpu','?')}")

# Query 2: Memory metric labels
r = subprocess.run(['curl', '-s', 'http://localhost:9090/api/v1/query?query=container_memory_usage_bytes{pod=~"ml-scaler.*"}'], capture_output=True, text=True)
d = json.loads(r.stdout)
print(f"\n=== MEMORY METRICS FOR ML-SCALER ===")
print(f"Results: {len(d['data']['result'])}")
for res in d['data']['result']:
    m = res['metric']
    val_mb = int(res['value'][1]) / 1024 / 1024
    print(f"  container={m.get('container','MISSING')!r}  pod={m.get('pod','?')}  = {val_mb:.0f} MB")

# Query 3: HTTP request metrics
r = subprocess.run(['curl', '-s', 'http://localhost:9090/api/v1/query?query=http_requests_total{job="ml-scaler-service"}'], capture_output=True, text=True)
d = json.loads(r.stdout)
print(f"\n=== HTTP REQUEST METRICS ===")
print(f"Results: {len(d['data']['result'])}")
for res in d['data']['result']:
    m = res['metric']
    print(f"  handler={m.get('handler','?')}  method={m.get('method','?')}  status={m.get('status','?')}  = {res['value'][1]}")

# Query 4: Check if rate works
r = subprocess.run(['curl', '-s', 'http://localhost:9090/api/v1/query?query=sum(rate(http_requests_total{job="ml-scaler-service"}[5m])) by (handler)'], capture_output=True, text=True)
d = json.loads(r.stdout)
print(f"\n=== REQUEST RATE (5m) ===")
print(f"Results: {len(d['data']['result'])}")
for res in d['data']['result']:
    print(f"  handler={res['metric'].get('handler','?')}  rate={float(res['value'][1]):.4f} req/s")
