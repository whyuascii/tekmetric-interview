#!/usr/bin/env bash
set -euo pipefail

# Removes the local k3d cluster and registry.

CLUSTER_NAME="tekmetric"
REGISTRY_NAME="tekmetric-registry"

echo "==> Deleting k3d cluster..."
k3d cluster delete "$CLUSTER_NAME" 2>/dev/null || echo "    Cluster not found."

echo "==> Deleting local registry..."
k3d registry delete "k3d-${REGISTRY_NAME}" 2>/dev/null || echo "    Registry not found."

echo ""
echo "Cleanup complete."
