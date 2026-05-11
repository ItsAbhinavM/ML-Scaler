# Scalable YOLO Deployment on Kubernetes

This repository implements a reproducible, research-style comparative study for ML inference deployment using
manual, containerized, and Kubernetes DevOps workflows. It follows a design-implement-evaluate loop and aligns
metrics with the reference paper.

## Project Structure

- `app/` FastAPI YOLO inference service with Prometheus metrics
- `helm/` Helm chart for Kubernetes deployment and HPA
- `scripts/` Deployment, monitoring install, load tests, benchmark scaffolding
- `load-testing/` k6 and Locust scenarios
- `dashboards/` Grafana dashboard JSON
- `results/` CSV templates for recorded metrics

## Phase 1: YOLO Inference Service (Local)

1. Create a virtual environment and install dependencies.
2. Run the API locally:

```bash
uvicorn app.app:app --host 0.0.0.0 --port 8000
```

3. Test endpoints:

```bash
curl http://localhost:8000/health
curl http://localhost:8000/metrics
```

## Phase 2: Docker

Build and run the container:

```bash
docker build -t yolo-service:latest -f app/Dockerfile .
docker run --rm -p 8000:8000 yolo-service:latest
```

## Phase 2b: Docker Compose + Grafana (No Kubernetes)

Run the same service using Docker Compose with Prometheus + Grafana:

```bash
docker compose up --build
```

Note: the Docker Compose mode runs the API in lightweight mock-inference mode (no `torch` download). Metrics and dashboards still work.

Endpoints:

```bash
curl http://localhost:8001/health
curl http://localhost:8001/metrics
```

Inference (mock):

```bash
curl -X POST http://localhost:8001/predict -F "file=@/path/to/image.jpg"
```

UIs:

```text
Grafana:    http://localhost:3002
Prometheus: http://localhost:9090
```

Grafana is auto-provisioned with a Prometheus datasource and will load dashboards from `dashboards/`.
Use `dashboards/grafana-dashboard-docker.json` for the Docker Compose view.

## Phase 3: Kubernetes (Minikube + Helm)

```bash
minikube start --driver=docker
minikube addons enable metrics-server
./scripts/deploy.sh
```

Port-forward for local access:

```bash
kubectl port-forward svc/yolo-yolo-service 8000:80 -n yolo
```

## Phase 4: Observability

```bash
./scripts/install_monitoring.sh
```

Import `dashboards/grafana-dashboard.json` into Grafana.

## Phase 5: Load Tests

```bash
./scripts/load_test.sh
```

Change scenarios with `SCENARIO=stress_1000` or `SCENARIO=autoscale`.

## Phase 6: Failure Testing

```bash
./scripts/failure_test.sh
```

## Metrics and Results

Record deployment, scalability, and recovery metrics in the CSVs under `results/`.

## Notes

- Default YOLO model is `yolov8n.pt` (downloaded on first run).
- Adjust `helm/yolo-service/values.yaml` for resources and scaling.
