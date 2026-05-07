# ML-Scaler: Complete Implementation Plan (Phases 4–6)

> Phases 1–3 are in [implementation_plan.md](file:///home/hkx05/.gemini/antigravity/brain/8665fab7-4533-46d3-bcd6-faa231b070fb/implementation_plan.md)

---

## Phase 4 — Prometheus + Grafana on Kubernetes (Helm)

### 4.1 — Install Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

### 4.2 — Install kube-prometheus-stack

```bash
# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install into "monitoring" namespace
kubectl create namespace monitoring

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValue=false \
  --set grafana.adminPassword=admin

# Wait for all pods
kubectl -n monitoring wait --for=condition=ready pod --all --timeout=300s
```

### 4.3 — Apply ServiceMonitor (from Phase 3)

```bash
kubectl apply -f k8s/servicemonitor.yaml
```

> [!NOTE]
> The `servicemonitor.yaml` label `release: kube-prometheus-stack` must match the Helm release name. The `serviceMonitorSelectorNilUsesHelmValue=false` flag tells Prometheus to discover ALL ServiceMonitors across namespaces.

### 4.4 — Access Grafana

```bash
# Port-forward Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3001:80 &

# Open http://localhost:3001
# Login: admin / admin
```

### 4.5 — `monitoring/grafana-dashboard.json`

```json
{
  "dashboard": {
    "title": "ML-Scaler Performance",
    "uid": "ml-scaler-perf",
    "panels": [
      {
        "id": 1,
        "title": "Request Rate (req/s)",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "rate(http_requests_total{handler=\"/predict\"}[1m])",
            "legendFormat": "{{method}} {{status}}"
          }
        ]
      },
      {
        "id": 2,
        "title": "Average Latency (ms)",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
        "targets": [
          {
            "expr": "rate(http_request_duration_seconds_sum{handler=\"/predict\"}[1m]) / rate(http_request_duration_seconds_count{handler=\"/predict\"}[1m]) * 1000",
            "legendFormat": "avg latency"
          }
        ]
      },
      {
        "id": 3,
        "title": "P95 Latency (ms)",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{handler=\"/predict\"}[1m])) * 1000",
            "legendFormat": "p95"
          }
        ]
      },
      {
        "id": 4,
        "title": "Error Rate",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
        "targets": [
          {
            "expr": "rate(http_requests_total{handler=\"/predict\", status=~\"5..\"}[1m])",
            "legendFormat": "5xx errors/s"
          }
        ]
      },
      {
        "id": 5,
        "title": "Pod Replica Count",
        "type": "stat",
        "gridPos": {"h": 8, "w": 8, "x": 0, "y": 16},
        "targets": [
          {
            "expr": "kube_deployment_status_replicas{deployment=\"ml-scaler\"}",
            "legendFormat": "replicas"
          }
        ]
      },
      {
        "id": 6,
        "title": "HPA Desired vs Current Replicas",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 16, "x": 8, "y": 16},
        "targets": [
          {
            "expr": "kube_horizontalpodautoscaler_status_desired_replicas{horizontalpodautoscaler=\"ml-scaler-hpa\"}",
            "legendFormat": "desired"
          },
          {
            "expr": "kube_horizontalpodautoscaler_status_current_replicas{horizontalpodautoscaler=\"ml-scaler-hpa\"}",
            "legendFormat": "current"
          }
        ]
      },
      {
        "id": 7,
        "title": "Pod CPU Usage",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 24},
        "targets": [
          {
            "expr": "sum(rate(container_cpu_usage_seconds_total{pod=~\"ml-scaler.*\", container!=\"\"}[1m])) by (pod)",
            "legendFormat": "{{pod}}"
          }
        ]
      },
      {
        "id": 8,
        "title": "Pod Memory Usage (MB)",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 24},
        "targets": [
          {
            "expr": "sum(container_memory_usage_bytes{pod=~\"ml-scaler.*\", container!=\"\"}) by (pod) / 1024 / 1024",
            "legendFormat": "{{pod}}"
          }
        ]
      }
    ],
    "time": {"from": "now-15m", "to": "now"},
    "refresh": "5s",
    "schemaVersion": 39
  },
  "overwrite": true
}
```

### 4.6 — Import Dashboard into Grafana

```bash
# Import via API
curl -X POST http://localhost:3001/api/dashboards/db \
  -H "Content-Type: application/json" \
  -u admin:admin \
  -d @monitoring/grafana-dashboard.json
```

### 4.7 — Verification

```bash
# Check Prometheus targets include ml-scaler
curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null || \
  kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &
# Then check: curl -s "http://localhost:9090/api/v1/targets" | grep ml-scaler

# Check Grafana dashboard exists
curl -s -u admin:admin http://localhost:3001/api/dashboards/uid/ml-scaler-perf | python3 -c "
import json,sys; d=json.load(sys.stdin); print(d['dashboard']['title'])
"
# Expected: ML-Scaler Performance
```

---

## Phase 5 — Load Testing with Locust

### 5.1 — `load-test/requirements.txt`

```
locust
```

### 5.2 — `load-test/locustfile.py`

```python
import os
from locust import HttpUser, task, between

# Path to test image relative to where locust is run (project root)
IMAGE_PATH = os.path.join(os.path.dirname(__file__), "..", "resources", "bild.jpg")


class MLScalerUser(HttpUser):
    wait_time = between(0.1, 0.5)

    @task
    def predict(self):
        with open(IMAGE_PATH, "rb") as img:
            self.client.post(
                "/predict",
                files={"file": ("bild.jpg", img, "image/jpeg")},
            )

    @task(3)
    def health_check(self):
        self.client.get("/health")
```

### 5.3 — Install Locust

```bash
pip install locust
```

### 5.4 — Run Baseline Load Test

```bash
# Make sure baseline is running
docker compose -f docker-compose.baseline.yml up -d

# Run locust (headless mode, 3 stages)
# Stage 1: 50 users, 2 minutes
locust -f load-test/locustfile.py \
  --host=http://localhost:8000 \
  --users 50 --spawn-rate 10 --run-time 2m \
  --headless --csv=load-test/results_baseline_50

# Stage 2: 200 users, 2 minutes
locust -f load-test/locustfile.py \
  --host=http://localhost:8000 \
  --users 200 --spawn-rate 20 --run-time 2m \
  --headless --csv=load-test/results_baseline_200

# Stage 3: 500 users, 2 minutes
locust -f load-test/locustfile.py \
  --host=http://localhost:8000 \
  --users 500 --spawn-rate 50 --run-time 2m \
  --headless --csv=load-test/results_baseline_500

# Take Grafana screenshots at http://localhost:3000 during each stage!

# Stop baseline
docker compose -f docker-compose.baseline.yml down
```

### 5.5 — Run Kubernetes Load Test

```bash
# Make sure K8s stack is running (Phase 3 + Phase 4)
K8S_URL=$(minikube service ml-scaler-service --url)
echo "K8s URL: $K8S_URL"

# Stage 1: 50 users
locust -f load-test/locustfile.py \
  --host=$K8S_URL \
  --users 50 --spawn-rate 10 --run-time 2m \
  --headless --csv=load-test/results_k8s_50

# Stage 2: 200 users
locust -f load-test/locustfile.py \
  --host=$K8S_URL \
  --users 200 --spawn-rate 20 --run-time 2m \
  --headless --csv=load-test/results_k8s_200

# Stage 3: 500 users
locust -f load-test/locustfile.py \
  --host=$K8S_URL \
  --users 500 --spawn-rate 50 --run-time 2m \
  --headless --csv=load-test/results_k8s_500

# Watch HPA scaling in another terminal:
# kubectl get hpa -w

# Take Grafana screenshots at http://localhost:3001 during each stage!
```

### 5.6 — Verification

```bash
# Check CSV files were generated
ls -la load-test/results_*.csv

# Each run produces 3 CSV files:
# *_stats.csv        — summary stats (avg/min/max/p50/p95/p99 latency, req/s)
# *_stats_history.csv — per-second timeseries
# *_failures.csv     — any failures

# Quick comparison
echo "=== Baseline 200 users ==="
head -5 load-test/results_baseline_200_stats.csv
echo ""
echo "=== K8s 200 users ==="
head -5 load-test/results_k8s_200_stats.csv
```

---

## Phase 6 — Results Comparison

### 6.1 — `RESULTS.md` (template to fill after load tests)

```markdown
# ML-Scaler: Performance Comparison Results

## Test Environment
- Machine: [your specs]
- Docker: v28.4.0
- Minikube: v1.38.1 (4 CPUs, 4GB RAM)
- Model: YOLOv11n
- Test image: resources/bild.jpg

## Deployment Efficiency

| Metric | Baseline Docker | Kubernetes + HPA |
|---|---|---|
| Setup Time | ~2 min (docker compose up) | ~5 min (minikube + helm) |
| Config Errors | N/A | N/A |
| Self-Healing | No | Yes (liveness probe) |
| Auto-Scaling | No (fixed 1 container) | Yes (1→5 pods via HPA) |

## Performance Under Load

### 50 Concurrent Users
| Metric | Baseline | Kubernetes |
|---|---|---|
| Avg Latency (ms) | TBD | TBD |
| P95 Latency (ms) | TBD | TBD |
| Throughput (req/s) | TBD | TBD |
| Error Rate (%) | TBD | TBD |
| Replicas | 1 | TBD |

### 200 Concurrent Users
| Metric | Baseline | Kubernetes |
|---|---|---|
| Avg Latency (ms) | TBD | TBD |
| P95 Latency (ms) | TBD | TBD |
| Throughput (req/s) | TBD | TBD |
| Error Rate (%) | TBD | TBD |
| Replicas | 1 | TBD |

### 500 Concurrent Users
| Metric | Baseline | Kubernetes |
|---|---|---|
| Avg Latency (ms) | TBD | TBD |
| P95 Latency (ms) | TBD | TBD |
| Throughput (req/s) | TBD | TBD |
| Error Rate (%) | TBD | TBD |
| Replicas | 1 | TBD |

## Grafana Screenshots
- [ ] Baseline 50 users
- [ ] Baseline 200 users
- [ ] Baseline 500 users
- [ ] K8s 50 users
- [ ] K8s 200 users
- [ ] K8s 500 users (show HPA scaling)

## Conclusion
TBD — Fill after experiments
```

---

## Master Command Sequence (Cheat Sheet)

```bash
# ============ PHASE 1 ============
docker build -t ml-scaler:latest .
docker run -d --name ml-test -p 8000:8000 ml-scaler:latest
sleep 10 && curl localhost:8000/health
curl -X POST localhost:8000/predict -F "file=@resources/bild.jpg"
curl localhost:8000/metrics | head -5
docker stop ml-test && docker rm ml-test

# ============ PHASE 2 ============
docker compose -f docker-compose.baseline.yml up -d
sleep 15
curl localhost:8000/health
curl localhost:3000/login  # Grafana: admin/admin
# Add Prometheus datasource: http://prometheus:9090

# ============ PHASE 5a (baseline load test) ============
pip install locust
locust -f load-test/locustfile.py --host=http://localhost:8000 \
  --users 50 --spawn-rate 10 --run-time 2m --headless --csv=load-test/results_baseline_50
locust -f load-test/locustfile.py --host=http://localhost:8000 \
  --users 200 --spawn-rate 20 --run-time 2m --headless --csv=load-test/results_baseline_200
locust -f load-test/locustfile.py --host=http://localhost:8000 \
  --users 500 --spawn-rate 50 --run-time 2m --headless --csv=load-test/results_baseline_500
docker compose -f docker-compose.baseline.yml down

# ============ PHASE 3 ============
minikube start --cpus=4 --memory=4096
minikube addons enable metrics-server
minikube image load ml-scaler:latest
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml
kubectl wait --for=condition=ready pod -l app=ml-scaler --timeout=120s

# ============ PHASE 4 ============
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValue=false \
  --set grafana.adminPassword=admin
kubectl -n monitoring wait --for=condition=ready pod --all --timeout=300s
kubectl apply -f k8s/servicemonitor.yaml
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3001:80 &
curl -X POST http://localhost:3001/api/dashboards/db \
  -H "Content-Type: application/json" -u admin:admin \
  -d @monitoring/grafana-dashboard.json

# ============ PHASE 5b (K8s load test) ============
K8S_URL=$(minikube service ml-scaler-service --url)
locust -f load-test/locustfile.py --host=$K8S_URL \
  --users 50 --spawn-rate 10 --run-time 2m --headless --csv=load-test/results_k8s_50
locust -f load-test/locustfile.py --host=$K8S_URL \
  --users 200 --spawn-rate 20 --run-time 2m --headless --csv=load-test/results_k8s_200
locust -f load-test/locustfile.py --host=$K8S_URL \
  --users 500 --spawn-rate 50 --run-time 2m --headless --csv=load-test/results_k8s_500

# ============ PHASE 6 ============
# Fill RESULTS.md with data from CSV files + Grafana screenshots
```
