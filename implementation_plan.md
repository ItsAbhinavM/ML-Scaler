# ML-Scaler: Complete Implementation Plan (Phases 1–3)

> Phases 4–6 are in [implementation_plan_part2.md](file:///home/hkx05/.gemini/antigravity/brain/8665fab7-4533-46d3-bcd6-faa231b070fb/implementation_plan_part2.md)

## Project Structure (Final)

```
ML-Scaler/
├── main.py                          # Enhanced FastAPI app
├── requirements.txt                 # Updated deps
├── Dockerfile                       # Updated (bake YOLO weights)
├── docker-compose.baseline.yml      # Baseline: app + prometheus + grafana
├── monitoring/
│   ├── prometheus-baseline.yml      # Prometheus config for baseline
│   └── grafana-dashboard.json       # Grafana dashboard JSON
├── k8s/
│   ├── deployment.yaml              # K8s Deployment
│   ├── service.yaml                 # K8s Service (NodePort)
│   ├── hpa.yaml                     # HorizontalPodAutoscaler
│   └── servicemonitor.yaml          # Prometheus ServiceMonitor
├── load-test/
│   ├── locustfile.py                # Locust load test
│   └── requirements.txt             # locust dependency
├── resources/
│   └── bild.jpg                     # Test image (existing)
└── RESULTS.md                       # Final comparison
```

---

## Phase 1 — Enhance FastAPI App

### 1.1 — `requirements.txt`

```
ultralytics
fastapi
uvicorn
python-multipart
prometheus-fastapi-instrumentator
```

### 1.2 — `main.py`

```python
import os
import time
import shutil

from fastapi import FastAPI, UploadFile
from fastapi.responses import JSONResponse
from prometheus_fastapi_instrumentator import Instrumentator
from ultralytics import YOLO

app = FastAPI(title="ML-Scaler YOLO API")

# Instrument Prometheus metrics at /metrics
Instrumentator().instrument(app).expose(app)

model = YOLO("yolo11n.pt")


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/predict")
async def predict(file: UploadFile):
    os.makedirs("input", exist_ok=True)
    os.makedirs("output", exist_ok=True)
    file_path = f"input/{file.filename}"

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    start = time.time()
    results = model(file_path)
    inference_time = time.time() - start

    detections = []
    for box in results[0].boxes:
        detections.append({
            "class": results[0].names[int(box.cls[0])],
            "confidence": float(box.conf[0]),
            "bbox": box.xyxy[0].tolist(),
        })

    return JSONResponse(content={
        "status": "done",
        "inference_time_ms": round(inference_time * 1000, 2),
        "detections": detections,
    })
```

### 1.3 — `Dockerfile`

```dockerfile
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 libxcb1 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir \
    --extra-index-url https://download.pytorch.org/whl/cpu \
    -r requirements.txt

COPY . .

# Pre-download YOLO weights during build
RUN python -c "from ultralytics import YOLO; YOLO('yolo11n.pt')"

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### 1.4 — Verification

```bash
# Build image
docker build -t ml-scaler:latest .

# Run container
docker run -d --name ml-test -p 8000:8000 ml-scaler:latest

# Wait 10s for startup, then test
sleep 10
curl http://localhost:8000/health
# Expected: {"status":"ok"}

curl http://localhost:8000/metrics | head -20
# Expected: Prometheus text format metrics

curl -X POST http://localhost:8000/predict -F "file=@resources/bild.jpg"
# Expected: JSON with status, inference_time_ms, detections

# Cleanup
docker stop ml-test && docker rm ml-test
```

---

## Phase 2 — Baseline Docker Deployment + Monitoring

### 2.1 — `monitoring/prometheus-baseline.yml`

```yaml
global:
  scrape_interval: 5s

scrape_configs:
  - job_name: "ml-api"
    static_configs:
      - targets: ["ml-api:8000"]
```

### 2.2 — `docker-compose.baseline.yml`

```yaml
version: "3.8"

services:
  ml-api:
    image: ml-scaler:latest
    container_name: ml-api
    ports:
      - "8000:8000"
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus-baseline.yml:/etc/prometheus/prometheus.yml
    depends_on:
      - ml-api

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_SECURITY_ADMIN_USER=admin
    depends_on:
      - prometheus
```

### 2.3 — Verification

```bash
# Start baseline stack
docker compose -f docker-compose.baseline.yml up -d

# Wait 15s, then verify
sleep 15

# 1. API works
curl http://localhost:8000/health

# 2. Prometheus scraping
curl -s "http://localhost:9090/api/v1/targets" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for t in d['data']['activeTargets']:
    print(t['labels']['job'], t['health'])
"
# Expected: ml-api up

# 3. Grafana accessible
curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/login
# Expected: 200
```

---

## Phase 3 — Kubernetes Deployment with HPA

### 3.1 — `k8s/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ml-scaler
  labels:
    app: ml-scaler
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ml-scaler
  template:
    metadata:
      labels:
        app: ml-scaler
    spec:
      containers:
        - name: ml-scaler
          image: ml-scaler:latest
          imagePullPolicy: Never
          ports:
            - containerPort: 8000
          resources:
            requests:
              cpu: "250m"
              memory: "512Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
          livenessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 15
            periodSeconds: 5
```

### 3.2 — `k8s/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ml-scaler-service
  labels:
    app: ml-scaler
spec:
  type: NodePort
  selector:
    app: ml-scaler
  ports:
    - protocol: TCP
      port: 8000
      targetPort: 8000
      nodePort: 30080
```

### 3.3 — `k8s/hpa.yaml`

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ml-scaler-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ml-scaler
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```

### 3.4 — `k8s/servicemonitor.yaml`

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ml-scaler-monitor
  labels:
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app: ml-scaler
  endpoints:
    - port: "8000"
      path: /metrics
      interval: 5s
  namespaceSelector:
    matchNames:
      - default
```

### 3.5 — Commands (in order)

```bash
# 1. Stop baseline if running
docker compose -f docker-compose.baseline.yml down

# 2. Start minikube
minikube start --cpus=4 --memory=4096

# 3. Enable metrics-server (needed for HPA)
minikube addons enable metrics-server

# 4. Load Docker image into minikube
minikube image load ml-scaler:latest

# 5. Apply K8s manifests
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml

# 6. Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=ml-scaler --timeout=120s

# 7. Get the service URL
minikube service ml-scaler-service --url
# Note this URL — used for load testing in Phase 5
```

### 3.6 — Verification

```bash
# Check pods
kubectl get pods -l app=ml-scaler
# Expected: 1/1 Running

# Check HPA
kubectl get hpa
# Expected: ml-scaler-hpa with TARGETS showing cpu%

# Check service
kubectl get svc ml-scaler-service
# Expected: NodePort 30080

# Test API through K8s
K8S_URL=$(minikube service ml-scaler-service --url)
curl $K8S_URL/health
# Expected: {"status":"ok"}

curl -X POST $K8S_URL/predict -F "file=@resources/bild.jpg"
# Expected: JSON with detections
```

---

> **Next:** See [Phases 4–6](file:///home/hkx05/.gemini/antigravity/brain/8665fab7-4533-46d3-bcd6-faa231b070fb/implementation_plan_part2.md) for Prometheus/Grafana Helm stack, load testing with Locust, and results comparison.
