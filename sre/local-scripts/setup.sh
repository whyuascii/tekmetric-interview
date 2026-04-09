#!/usr/bin/env bash
set -euo pipefail

# Creates a local k3d cluster with a local registry for testing the full
# Docker build + Helm deploy flow without any cloud dependencies.

CLUSTER_NAME="tekmetric"
REGISTRY_NAME="tekmetric-registry"
REGISTRY_PORT="5111"

echo "==> Checking prerequisites..."
for cmd in docker k3d helm kubectl; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: $cmd is not installed."
    echo ""
    echo "Install with:"
    echo "  brew install docker"
    echo "  brew install k3d"
    echo "  brew install helm"
    echo "  brew install kubectl"
    exit 1
  fi
done

# Check if Docker is running
if ! docker info &>/dev/null; then
  echo "ERROR: Docker daemon is not running. Start Docker Desktop first."
  exit 1
fi

echo "==> Creating local registry (localhost:${REGISTRY_PORT})..."
if k3d registry list 2>/dev/null | grep -q "$REGISTRY_NAME"; then
  echo "    Registry already exists, skipping."
else
  k3d registry create "$REGISTRY_NAME" --port "$REGISTRY_PORT"
fi

echo "==> Creating k3d cluster..."
if k3d cluster list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
  echo "    Cluster already exists, skipping."
else
  k3d cluster create "$CLUSTER_NAME" \
    --registry-use "k3d-${REGISTRY_NAME}:${REGISTRY_PORT}" \
    --port "8080:80@loadbalancer" \
    --agents 2 \
    --wait
fi

echo "==> Verifying cluster..."
kubectl cluster-info
kubectl get nodes

echo ""
echo "Local cluster is ready."
echo "  Registry: localhost:${REGISTRY_PORT}"
echo "  Cluster:  ${CLUSTER_NAME}"
echo ""
echo "Next: run ./sre/local-scripts/deploy.sh"
