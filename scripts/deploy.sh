#!/usr/bin/env bash
set -euo pipefail

RELEASE_NAME=${RELEASE_NAME:-yolo}
NAMESPACE=${NAMESPACE:-yolo}
IMAGE_NAME=${IMAGE_NAME:-yolo-service:latest}

echo "Creating namespace ${NAMESPACE}"
kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}"

echo "Building image ${IMAGE_NAME}"
docker build -t "${IMAGE_NAME}" -f app/Dockerfile .

echo "Loading image into minikube"
minikube image load "${IMAGE_NAME}"

echo "Deploying Helm chart"
helm upgrade --install "${RELEASE_NAME}" helm/yolo-service \
  --namespace "${NAMESPACE}" \
  --set image.repository="${IMAGE_NAME%%:*}" \
  --set image.tag="${IMAGE_NAME##*:}"

echo "Deployment complete"
