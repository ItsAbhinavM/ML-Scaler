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
