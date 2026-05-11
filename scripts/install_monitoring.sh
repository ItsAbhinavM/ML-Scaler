#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=${NAMESPACE:-monitoring}

echo "Adding prometheus-community repo"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "Creating namespace ${NAMESPACE}"
kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}"

echo "Installing kube-prometheus-stack"
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace "${NAMESPACE}"

echo "Monitoring stack installed"
