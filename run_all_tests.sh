#!/bin/bash

# =============================================================================
# ML-Scaler: Complete Load Test Runner
# =============================================================================
# This script runs all load tests for both Baseline (Docker) and Kubernetes
# deployments, then generates a comparison report.
#
# Usage:
#   ./run_all_tests.sh baseline   # Run baseline tests only
#   ./run_all_tests.sh k8s        # Run K8s tests only
#   ./run_all_tests.sh all        # Run both (default)
# =============================================================================

set -e

# Configuration
USERS_LOW=50
USERS_MED=200
USERS_HIGH=500
SPAWN_RATE_LOW=10
SPAWN_RATE_MED=20
SPAWN_RATE_HIGH=50
RUN_TIME="2m"
RESULTS_DIR="load-test"
LOCUST_FILE="load-test/locustfile.py"

MODE="${1:-all}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_step()  { echo -e "${BLUE}[STEP]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# Helper: Run a single locust test
# =============================================================================
run_locust_test() {
    local host=$1
    local users=$2
    local spawn_rate=$3
    local csv_prefix=$4

    log_step "Running load test: ${users} users, spawn-rate ${spawn_rate}, runtime ${RUN_TIME}"
    log_info "  Host: ${host}"
    log_info "  CSV prefix: ${csv_prefix}"

    locust -f "${LOCUST_FILE}" \
        --host="${host}" \
        --users "${users}" \
        --spawn-rate "${spawn_rate}" \
        --run-time "${RUN_TIME}" \
        --headless \
        --csv="${csv_prefix}"

    log_info "  ✅ Test complete. Results saved."
    echo ""
}

# =============================================================================
# BASELINE TESTS (Docker Compose — single container, no autoscaling)
# =============================================================================
run_baseline_tests() {
    echo ""
    echo "============================================================"
    echo "  🐳 BASELINE TESTS (Docker Compose — single container)"
    echo "============================================================"
    echo ""

    # Check if baseline is already running
    if docker ps --format '{{.Names}}' | grep -q "ml-api"; then
        log_info "Baseline stack already running."
    else
        # Pre-check: kill stale port-forwards that could block port 9090
        if lsof -ti:9092 >/dev/null 2>&1; then
            log_warn "Port 9092 in use — killing stale processes..."
            kill $(lsof -ti:9092) 2>/dev/null || true
            sleep 1
        fi
        if lsof -ti:8000 >/dev/null 2>&1; then
            log_warn "Port 8000 in use — checking if ml-api is already running..."
        fi

        log_step "Starting baseline stack..."
        docker compose -f docker-compose.baseline.yml up -d
        log_info "Waiting 20s for services to start..."
        sleep 20
    fi

    # Verify baseline is healthy
    log_step "Verifying baseline health..."
    if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
        log_info "✅ Baseline API is healthy at http://localhost:8000"
        log_info "   Baseline Prometheus: http://localhost:9092"
        log_info "   Baseline Grafana:    http://localhost:3002 (admin/admin)"
    else
        log_error "❌ Baseline API not responding at http://localhost:8000/health"
        log_error "   Run: docker compose -f docker-compose.baseline.yml up -d"
        exit 1
    fi

    # Run 3 stages of load tests
    log_step "Stage 1/3: ${USERS_LOW} users"
    run_locust_test "http://localhost:8000" ${USERS_LOW} ${SPAWN_RATE_LOW} "${RESULTS_DIR}/results_baseline_${USERS_LOW}"

    log_step "Stage 2/3: ${USERS_MED} users"
    run_locust_test "http://localhost:8000" ${USERS_MED} ${SPAWN_RATE_MED} "${RESULTS_DIR}/results_baseline_${USERS_MED}"

    log_step "Stage 3/3: ${USERS_HIGH} users"
    run_locust_test "http://localhost:8000" ${USERS_HIGH} ${SPAWN_RATE_HIGH} "${RESULTS_DIR}/results_baseline_${USERS_HIGH}"

    echo ""
    log_info "🐳 All baseline tests complete!"
    echo ""
}

# =============================================================================
# KUBERNETES TESTS (K8s + HPA — autoscaling enabled)
# =============================================================================
run_k8s_tests() {
    echo ""
    echo "============================================================"
    echo "  ☸️  KUBERNETES TESTS (K8s + HPA — autoscaling enabled)"
    echo "============================================================"
    echo ""

    # Get K8s service URL
    log_step "Getting Kubernetes service URL..."
    K8S_URL=$(minikube service ml-scaler-service --url 2>/dev/null)
    if [ -z "$K8S_URL" ]; then
        log_error "❌ Cannot get K8s service URL. Is minikube running?"
        log_error "   Run: minikube start && kubectl apply -f k8s/"
        exit 1
    fi
    log_info "K8s URL: ${K8S_URL}"

    # Verify K8s API is healthy
    log_step "Verifying K8s deployment health..."
    if curl -sf "${K8S_URL}/health" > /dev/null 2>&1; then
        log_info "✅ K8s API is healthy."
    else
        log_error "❌ K8s API not responding at ${K8S_URL}/health"
        exit 1
    fi

    # Check HPA is working
    log_step "Checking HPA status..."
    kubectl get hpa ml-scaler-hpa
    echo ""

    # Reset HPA by scaling deployment down and back up
    log_step "Resetting deployment to 1 replica before tests..."
    kubectl scale deployment ml-scaler --replicas=1
    sleep 10
    kubectl wait --for=condition=ready pod -l app=ml-scaler --timeout=120s

    # Run 3 stages of load tests
    log_step "Stage 1/3: ${USERS_LOW} users"
    run_locust_test "${K8S_URL}" ${USERS_LOW} ${SPAWN_RATE_LOW} "${RESULTS_DIR}/results_k8s_${USERS_LOW}"

    # Wait for scale-down between tests
    log_info "Waiting 30s for HPA scale-down..."
    sleep 30

    log_step "Stage 2/3: ${USERS_MED} users"
    run_locust_test "${K8S_URL}" ${USERS_MED} ${SPAWN_RATE_MED} "${RESULTS_DIR}/results_k8s_${USERS_MED}"

    # Wait for scale-down between tests
    log_info "Waiting 30s for HPA scale-down..."
    sleep 30

    log_step "Stage 3/3: ${USERS_HIGH} users"
    run_locust_test "${K8S_URL}" ${USERS_HIGH} ${SPAWN_RATE_HIGH} "${RESULTS_DIR}/results_k8s_${USERS_HIGH}"

    echo ""
    log_info "☸️  All K8s tests complete!"
    echo ""
}

# =============================================================================
# GENERATE RESULTS COMPARISON
# =============================================================================
generate_report() {
    echo ""
    echo "============================================================"
    echo "  📊 GENERATING RESULTS COMPARISON"
    echo "============================================================"
    echo ""

    python3 - << 'PYTHON_SCRIPT'
import csv
import os

RESULTS_DIR = "load-test"

def parse_stats(csv_path):
    """Parse a locust stats CSV and return aggregated metrics."""
    if not os.path.exists(csv_path):
        return None
    with open(csv_path, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row['Name'] == 'Aggregated':
                return {
                    'requests': int(row['Request Count']),
                    'failures': int(row['Failure Count']),
                    'avg_latency': float(row['Average Response Time']),
                    'p50': float(row['50%']),
                    'p95': float(row['95%']),
                    'p99': float(row['99%']),
                    'rps': float(row['Requests/s']),
                    'error_rate': float(row['Failure Count']) / max(int(row['Request Count']), 1) * 100
                }
    return None

def fmt(val, unit=""):
    if val is None:
        return "N/A"
    if isinstance(val, float):
        return f"{val:.1f}{unit}"
    return f"{val}{unit}"

print("# ML-Scaler: Performance Comparison Results\n")

for users in [50, 200, 500]:
    baseline = parse_stats(f"{RESULTS_DIR}/results_baseline_{users}_stats.csv")
    k8s = parse_stats(f"{RESULTS_DIR}/results_k8s_{users}_stats.csv")

    if not baseline and not k8s:
        continue

    print(f"## {users} Concurrent Users")
    print(f"| Metric | Baseline | Kubernetes |")
    print(f"|---|---|---|")

    b = baseline or {}
    k = k8s or {}

    print(f"| Avg Latency (ms) | {fmt(b.get('avg_latency'), 'ms')} | {fmt(k.get('avg_latency'), 'ms')} |")
    print(f"| P95 Latency (ms) | {fmt(b.get('p95'), 'ms')} | {fmt(k.get('p95'), 'ms')} |")
    print(f"| P99 Latency (ms) | {fmt(b.get('p99'), 'ms')} | {fmt(k.get('p99'), 'ms')} |")
    print(f"| Throughput (req/s) | {fmt(b.get('rps'), ' rps')} | {fmt(k.get('rps'), ' rps')} |")
    print(f"| Total Requests | {fmt(b.get('requests'))} | {fmt(k.get('requests'))} |")
    print(f"| Failures | {fmt(b.get('failures'))} | {fmt(k.get('failures'))} |")
    print(f"| Error Rate | {fmt(b.get('error_rate'), '%')} | {fmt(k.get('error_rate'), '%')} |")
    print()

PYTHON_SCRIPT
}

# =============================================================================
# MAIN
# =============================================================================
echo ""
echo "============================================================"
echo "  🚀 ML-Scaler Load Test Runner"
echo "  Mode: ${MODE}"
echo "============================================================"

case "$MODE" in
    baseline)
        run_baseline_tests
        generate_report
        ;;
    k8s)
        run_k8s_tests
        generate_report
        ;;
    all)
        run_baseline_tests
        echo ""
        log_info "Stopping baseline stack before K8s tests..."
        docker compose -f docker-compose.baseline.yml down 2>/dev/null || true
        sleep 3
        echo ""
        run_k8s_tests
        generate_report
        ;;
    report)
        generate_report
        ;;
    *)
        echo "Usage: $0 {baseline|k8s|all|report}"
        exit 1
        ;;
esac

echo ""
log_info "📊 CSV results are in: ${RESULTS_DIR}/"
log_info "📈 K8s Grafana:      kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3001:80 → http://localhost:3001 (admin/password)"
log_info "📈 Baseline Grafana: http://localhost:3002 (admin/admin)"
echo ""
