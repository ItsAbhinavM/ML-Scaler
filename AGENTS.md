# AGENTS.md
# Scalable YOLO Deployment on Kubernetes: A DevOps Comparative Study

## Project Overview

This project implements a DevOps-driven framework for deploying and benchmarking a YOLO-based machine learning inference service.

The goal is not only to deploy a scalable ML model, but also to experimentally compare different deployment strategies and demonstrate improvements in:

- Deployment efficiency
- Scalability under load
- Reliability and self-healing
- Mean Time to Recovery (MTTR)
- Automation effectiveness

The implementation should reproduce a research-style comparative study between:

1. Manual VM-style deployment
2. Containerized deployment without orchestration
3. Fully automated Kubernetes + DevOps deployment

The final system should demonstrate:
- Elastic scaling using Kubernetes HPA
- Automated recovery from failures
- Continuous monitoring with Prometheus and Grafana
- Measurable improvements over non-orchestrated deployments

# Reference Material

A research paper converted to Markdown is available at:

reference-paper.md

The paper serves as:
- architectural guidance
- benchmarking reference
- evaluation methodology reference
- comparative study blueprint

The agent should use the paper to:
- mirror the experimental structure
- align benchmark metrics
- reproduce deployment comparisons
- replicate observability goals
- match scalability evaluation methodology

Important:
- Treat the paper as conceptual guidance, not strict implementation requirements.
- Prefer lightweight and reproducible tooling over enterprise-heavy frameworks.
- The implementation should remain practical for local Kubernetes environments using minikube.

---

# System Constraints

## Infrastructure
- Local Kubernetes cluster using minikube
- Docker driver
- Linux environment preferred
- GPU support optional

## ML Model
- YOLO (Ultralytics implementation)

## Backend API
- FastAPI preferred

## Containerization
- Docker

## Kubernetes Tooling
- kubectl
- helm

## Observability Stack
- Prometheus
- Grafana
- kube-prometheus-stack

## Load Testing
Preferred tools:
- k6
- Locust
- ApacheBench (ab)

---

# Primary Objectives

The agent must implement the following capabilities:

## 1. Reproducible ML Deployment
- Containerize the YOLO inference service
- Ensure deterministic builds
- Maintain environment consistency

## 2. Scalable Kubernetes Deployment
- Deploy the model on Kubernetes
- Enable horizontal autoscaling
- Configure resource requests and limits

## 3. Observability
- Export application metrics
- Monitor latency, throughput, resource usage
- Track pod restarts and recovery

## 4. Comparative Benchmarking
The system must compare:
- Manual deployment
- Docker-only deployment
- Kubernetes + DevOps deployment

## 5. Reliability Testing
- Simulate pod failures
- Measure automatic recovery time
- Validate Kubernetes self-healing

---

# Deployment Modes

## Mode 1 — Manual Baseline
Purpose:
- Simulate traditional VM/manual deployment

Requirements:
- Run YOLO service using raw Python execution
OR
- Run using plain docker run commands

Characteristics:
- No orchestration
- No autoscaling
- Manual recovery
- Minimal automation

---

## Mode 2 — Containerized Only
Purpose:
- Evaluate benefits of containerization without orchestration

Requirements:
- Dockerized FastAPI inference service
- Manual container startup
- No Kubernetes
- No HPA
- No CI/CD

Characteristics:
- Improved portability
- Moderate automation
- Manual scaling

---

## Mode 3 — DevOps + Kubernetes
Purpose:
- Full scalable production-style deployment

Requirements:
- Kubernetes deployment using Helm
- HPA enabled
- Monitoring stack enabled
- Automated recovery
- Metrics instrumentation

Characteristics:
- High automation
- Self-healing
- Elastic scaling
- Observable infrastructure

---

# Required Project Structure

The agent should generate a structure similar to:

.
├── app/
│   ├── app.py
│   ├── model.py
│   ├── metrics.py
│   ├── requirements.txt
│   └── Dockerfile
│
├── helm/
│   └── yolo-service/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── templates/
│       └── charts/
│
├── scripts/
│   ├── deploy.sh
│   ├── load_test.sh
│   ├── benchmark.sh
│   ├── failure_test.sh
│   └── install_monitoring.sh
│
├── load-testing/
│   ├── k6.js
│   └── locustfile.py
│
├── dashboards/
│   └── grafana-dashboard.json
│
├── results/
│   ├── deployment_metrics.csv
│   ├── scalability_results.csv
│   └── recovery_metrics.csv
│
└── README.md

---

# Phase 1 — YOLO Inference Service

## Requirements

Implement:
- FastAPI inference API
- YOLO model loading
- Image upload endpoint
- JSON detection responses

## Dependencies
Use:
- ultralytics
- torch
- opencv-python
- fastapi
- uvicorn
- prometheus_client

## Required API Endpoints

### Health Check
GET /health

### Inference
POST /predict

### Metrics
GET /metrics

---

# Metrics Instrumentation

The inference service MUST expose Prometheus metrics.

Track:
- Total requests
- Request latency
- Inference duration
- Error count
- Active requests

Use:
- prometheus_client

---

# Docker Requirements

## Dockerfile
Use:
- python:slim
OR
- CUDA-compatible image if GPU enabled

Requirements:
- Multi-stage build preferred
- Small image size preferred
- Proper dependency caching
- Expose FastAPI port

## Validation
The agent must:
- Build the image
- Run locally
- Verify inference works

---

# Phase 2 — Kubernetes Orchestration

## Minikube Setup

Requirements:
- Start minikube with Docker driver
- Enable metrics-server
- Enable ingress if needed

Example:
minikube start --driver=docker

---

# Helm Deployment

The agent must:

## Generate Chart
Use:
helm create yolo-service

## Configure Deployment
Include:
- Resource requests/limits
- Liveness probes
- Readiness probes
- Rolling updates

## Configure Service
Use:
- NodePort
OR
- LoadBalancer

---

# Horizontal Pod Autoscaler (HPA)

The system MUST support autoscaling.

## HPA Requirements
Scale based on:
- CPU utilization
- Memory utilization

Suggested thresholds:
- CPU > 60%
- Memory > 70%

## HPA Goals
Demonstrate:
- Pod replication under load
- Automatic scale-down
- Improved throughput

---

# Phase 3 — Observability & Monitoring

## Monitoring Stack

Install:
- kube-prometheus-stack using Helm

Include:
- Prometheus
- Grafana
- Alertmanager

---

# Prometheus Requirements

Prometheus must scrape:
- Kubernetes metrics
- Node metrics
- YOLO application metrics

Track:
- CPU usage
- Memory usage
- Request throughput
- Latency
- Pod restart events
- HPA events

---

# Grafana Dashboard Requirements

Create dashboards visualizing:

## Infrastructure Metrics
- CPU usage per pod
- Memory usage per pod
- Network traffic
- Pod replica count

## Application Metrics
- Request throughput (req/sec)
- Average latency
- P95 latency
- Error rate
- Inference time

## Reliability Metrics
- Pod restart count
- Recovery timelines
- HPA scaling activity

---

# Failure Injection & Reliability Testing

The agent MUST implement resilience testing.

## Failure Scenarios

### Pod Deletion
Delete active YOLO pods during traffic.

Measure:
- Recovery time
- Service availability
- Request failures

### High Load
Generate sustained traffic to trigger HPA.

Measure:
- Replica scaling
- Latency stability
- Throughput improvement

---

# Benchmarking Requirements

The project MUST collect measurable data.

## Metrics to Collect

### Deployment Metrics
- Deployment time
- Configuration errors
- MTTR

### Performance Metrics
- Throughput (req/sec)
- Average latency
- P95 latency

### Scalability Metrics
- HPA response time
- Replica count changes
- Resource utilization

### Reliability Metrics
- Pod recovery time
- Restart frequency
- Availability

---

# Comparative Analysis

The system should generate comparative benchmark outputs between:

| Deployment Mode | Deployment Time | Throughput | MTTR | Automation |
|-----------------|----------------|------------|------|------------|

The project should demonstrate:
- Reduced deployment time
- Lower MTTR
- Better elasticity
- Higher throughput
- Improved reliability

---

# Load Testing

Preferred tool:
- k6

## Required Tests

### Baseline Test
Low concurrent traffic.

### Stress Test
Increasing concurrent requests:
- 500
- 1000
- 5000

### Autoscaling Test
Sustained traffic until HPA triggers.

---

# Automation Goals

The project should aim for:
- Fully reproducible deployment
- Minimal manual intervention
- MTTR near 9 minutes or lower
- One-command deployment scripts

---

# Optional CI/CD

Preferred:
- GitHub Actions

Suggested Pipeline:
1. Run tests
2. Build Docker image
3. Push image
4. Deploy using Helm
5. Run smoke tests

---

# Deliverables

The agent must generate:

## Source Code
- FastAPI service
- Docker configuration
- Helm charts
- Load testing scripts

## Infrastructure
- Kubernetes manifests
- HPA configuration
- Monitoring setup

## Observability
- Grafana dashboards
- Prometheus configs

## Benchmark Results
- CSV results
- Comparison tables
- Latency metrics
- Throughput metrics

## Documentation
- Setup instructions
- Deployment guide
- Benchmarking guide
- Architecture explanation

---

# Success Criteria

The implementation is considered successful if it demonstrates:

## Deployment Efficiency
- Faster deployment than manual approaches

## Reliability
- Automatic pod recovery
- Lower MTTR

## Elasticity
- HPA successfully scales replicas
- Throughput increases under load

## Observability
- Metrics visible in Grafana
- Prometheus successfully scraping services

## Automation
- Reproducible deployment pipeline
- Minimal manual operations

---

# Notes for the Agent

Prioritize:
- Simplicity
- Reproducibility
- Automation
- Benchmark visibility

Avoid:
- Overengineering
- Heavy enterprise frameworks
- Unnecessary abstractions

Preferred stack:
- FastAPI
- Docker
- Kubernetes
- Helm
- Prometheus
- Grafana
- k6

Do NOT use:
- Kubeflow
- KServe
- Seldon Core

unless explicitly required later.