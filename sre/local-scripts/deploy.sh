#!/usr/bin/env bash
set -euo pipefail

# Builds the Docker image, pushes to the local k3d registry,
# and deploys to the local cluster using Helm.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

HOST_REGISTRY="localhost:5111"
CLUSTER_REGISTRY="k3d-tekmetric-registry:5111"
IMAGE_NAME="tekmetric-backend"
IMAGE_TAG="${1:-local}"
NAMESPACE="tekmetric-dev"
CHART_PATH="${REPO_ROOT}/sre/helm/tekmetric-backend"

echo "==> Building Docker image..."
docker build \
  -t "${HOST_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}" \
  -f "${REPO_ROOT}/sre/Dockerfile" \
  "${REPO_ROOT}"

echo "==> Pushing to local registry..."
docker push "${HOST_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "==> Deploying with Helm..."
helm upgrade --install tekmetric-backend "${CHART_PATH}" \
  -n "${NAMESPACE}" \
  --create-namespace \
  -f "${CHART_PATH}/values.yaml" \
  -f "${CHART_PATH}/values-dev.yaml" \
  --set image.repository="${CLUSTER_REGISTRY}/${IMAGE_NAME}" \
  --set image.tag="${IMAGE_TAG}" \
  --set environment.name=local \
  --rollback-on-failure \
  --wait \
  --timeout 5m

echo "==> Verifying deployment..."
kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=tekmetric-backend
echo ""

echo "==> Running Helm test..."
helm test tekmetric-backend -n "${NAMESPACE}" || true

echo ""
echo "Deployment complete."
echo "  Namespace: ${NAMESPACE}"
echo ""
echo "Access the app:"
echo "  kubectl port-forward svc/tekmetric-backend 8080:80 -n ${NAMESPACE}"
echo "  curl http://localhost:8080/api/welcome"
