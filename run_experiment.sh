#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "============================================================"
echo "🚀 Starting ML-Scaler Case Study Setup..."
echo "============================================================"

# 1. Start Minikube (if not already running)
echo "------------------------------------------------------------"
echo "📦 1. Starting Minikube..."
minikube status >/dev/null 2>&1 || minikube start --cpus=4 --memory=8192

# 1.5. Enable metrics-server (REQUIRED for HPA to work!)
echo "------------------------------------------------------------"
echo "📏 1.5. Enabling metrics-server addon (required for HPA)..."
minikube addons enable metrics-server
echo "⏳ Waiting for metrics-server to be ready..."
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=120s || echo "⚠️ metrics-server still starting..."

# 2. Build and Load Docker Image
echo "------------------------------------------------------------"
echo "🐳 2. Building Docker Image and loading into Minikube..."
docker build -t ml-scaler:latest .
minikube image load ml-scaler:latest

# 3. Setup Python Virtual Environment for Load Testing
echo "------------------------------------------------------------"
echo "🐍 3. Setting up Python Virtual Environment for Locust..."
python3 -m venv venv
source venv/bin/activate
pip install locust

# 4. Install Prometheus & Grafana via Helm
echo "------------------------------------------------------------"
echo "📊 4. Setting up Prometheus & Grafana Monitoring Stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update

# Create monitoring namespace if it doesn't exist
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Install or upgrade the kube-prometheus-stack
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=password

echo "⏳ Waiting for monitoring pods to be ready (this may take a few minutes)..."
kubectl wait -n monitoring --for=condition=ready pod --all --timeout=300s || echo "⚠️ Some monitoring pods are still starting, continuing anyway..."

# 5. Deploy the ML Application to Kubernetes
echo "------------------------------------------------------------"
echo "⚙️ 5. Deploying ML-Scaler Application to Kubernetes..."
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/servicemonitor.yaml

echo "⏳ Waiting for ML-Scaler pod to be ready..."
kubectl wait --for=condition=ready pod -l app=ml-scaler --timeout=300s

# 6. Configure Grafana Dashboard
echo "------------------------------------------------------------"
echo "📈 6. Configuring Grafana Dashboard..."

# Port-forward Grafana in the background briefly to import the dashboard
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3001:80 > /dev/null 2>&1 &
PF_PID=$!
sleep 5 # wait for port-forward to establish

# Import the dashboard using the API
curl -s -X POST http://localhost:3001/api/dashboards/db \
  -H "Content-Type: application/json" \
  -u "admin:password" \
  --data-binary @monitoring/grafana-dashboard.json > /dev/null

# Kill the temporary port-forward
kill $PF_PID

echo "============================================================"
echo "✅ Setup Complete!"
echo "============================================================"
echo ""
echo "🔥 HOW TO RUN THE LOAD TESTS 🔥"
echo "------------------------------------------------------------"
echo ""
echo "Option A — Automated (recommended):"
echo "  source venv/bin/activate"
echo "  chmod +x run_all_tests.sh"
echo "  ./run_all_tests.sh k8s       # K8s tests only"
echo "  ./run_all_tests.sh baseline   # Baseline tests only"
echo "  ./run_all_tests.sh all        # Both baseline + K8s"
echo "  ./run_all_tests.sh report     # Generate report from existing CSVs"
echo ""
echo "Option B — Manual:"
echo "  Terminal 1: kubectl get hpa -w"
echo "  Terminal 2:"
echo "    source venv/bin/activate"
echo "    K8S_URL=\$(minikube service ml-scaler-service --url)"
echo "    locust -f load-test/locustfile.py --host=\$K8S_URL --users 200 --spawn-rate 20 --run-time 2m --headless --csv=load-test/results_k8s_200"
echo ""
echo "📈 Grafana Dashboard:"
echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3001:80"
echo "  Open: http://localhost:3001 (Login: admin / password)"
echo "============================================================"
