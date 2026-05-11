#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=${NAMESPACE:-yolo-devops}
LABEL=${LABEL:-app.kubernetes.io/name=yolo-service}
TARGET_URL=${TARGET_URL:-http://192.168.49.2:30189/predict}
SCENARIOS=${SCENARIOS:-baseline autoscale stress_500}

READY_TIMEOUT=${READY_TIMEOUT:-300}

get_ready_count() {
  local tries=0
  local out
  while [ $tries -lt 5 ]; do
    out=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL" \
      -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null || true)
    if [ -n "$out" ]; then
      printf "%s\n" "$out" | awk '$1=="true"{c++} END{print c+0}'
      return 0
    fi
    tries=$((tries+1))
    sleep 1
  done
  return 1
}

run_k6() {
  local scenario=$1
  local summary=$2
  local log=$3
  k6 run -e TARGET_URL="$TARGET_URL" -e SCENARIO="$scenario" load-testing/k6.js \
    --summary-export "$summary" > "$log" 2>&1
}

mkdir -p /tmp/bench

for scenario in $SCENARIOS; do
  run_k6 "$scenario" "/tmp/bench/k6-${scenario}.json" "/tmp/bench/k6-${scenario}.log"
done

echo "autoscale" > /tmp/bench/active_scenario

SUMMARY=/tmp/bench/k6-autoscale.json
LOG=/tmp/bench/k6-autoscale.log
HPA_BEFORE=/tmp/bench/hpa_before.json
HPA_DURING=/tmp/bench/hpa_during.json
HPA_AFTER=/tmp/bench/hpa_after.json
TOP_BEFORE=/tmp/bench/top_before.txt
TOP_AFTER=/tmp/bench/top_after.txt
MTTR=/tmp/bench/mttr.txt

kubectl get hpa -n "$NAMESPACE" -o json > "$HPA_BEFORE" || true
kubectl top pods -n "$NAMESPACE" > "$TOP_BEFORE" || true

# Run autoscale workload in background
k6 run -e TARGET_URL="$TARGET_URL" -e SCENARIO=autoscale load-testing/k6.js \
  --summary-export "$SUMMARY" > "$LOG" 2>&1 &
K6_PID=$!

sleep 20
kubectl get hpa -n "$NAMESPACE" -o json > "$HPA_DURING" || true

PRE_READY=$(get_ready_count || echo "")
if [ -z "$PRE_READY" ]; then
  PRE_READY=0
fi

POD=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "$POD" ]; then
  DEL_START=$(date +%s)
  kubectl delete pod -n "$NAMESPACE" "$POD" >/dev/null 2>&1 || true

  deadline=$((DEL_START + READY_TIMEOUT))
  while true; do
    READY=$(get_ready_count || echo "")
    if [ -n "$READY" ] && [ "$READY" -ge "$PRE_READY" ]; then
      break
    fi
    if [ "$(date +%s)" -ge "$deadline" ]; then
      break
    fi
    sleep 2
  done
  DEL_END=$(date +%s)
  echo $((DEL_END-DEL_START)) > "$MTTR"
fi

wait $K6_PID

kubectl get hpa -n "$NAMESPACE" -o json > "$HPA_AFTER" || true
kubectl top pods -n "$NAMESPACE" > "$TOP_AFTER" || true

echo "benchmarks complete"
