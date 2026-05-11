#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=${NAMESPACE:-yolo}
LABEL=${LABEL:-app.kubernetes.io/name=yolo-service}

echo "Deleting a pod to simulate failure"
POD=$(kubectl get pods -n "${NAMESPACE}" -l "${LABEL}" -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod -n "${NAMESPACE}" "${POD}"

echo "Pod deleted. Observe recovery time with kubectl get pods -w"
