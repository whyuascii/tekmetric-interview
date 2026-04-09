# Local Deployment Guide

## Prerequisites

Install the following (all available via Homebrew):

```bash
brew install docker    # Or Docker Desktop Or Orbstack
brew install k3d       # k3s-in-Docker
brew install helm
brew install kubectl
```

Make sure Docker is running.

## Quick Start

From the repo root:

```bash
# 1. Create local cluster + registry
./sre/local-scripts/setup.sh

# 2. Build, push, and deploy
./sre/local-scripts/deploy.sh

# 3. Access the app
kubectl port-forward svc/tekmetric-backend 8080:80 -n tekmetric-dev
curl http://localhost:8080/api/welcome
```

## What Each Script Does

### `setup.sh`

1. Checks that `docker`, `k3d`, `helm`, and `kubectl` are installed
2. Creates a local Docker registry at `localhost:5111`
3. Creates a k3d cluster named `tekmetric` with 2 agent nodes
4. Connects the cluster to the local registry so images can be pulled without ECR

### `deploy.sh`

1. Builds the Docker image from `sre/Dockerfile`
2. Tags and pushes it to the local registry (`localhost:5111/tekmetric-backend:local`)
3. Runs `helm upgrade --install` with `values.yaml` + `values-dev.yaml`
4. Waits for pods to become Ready (`--rollback-on-failure --wait`)
5. Runs `helm test` to verify the service is reachable
6. Prints access instructions

You can pass a custom tag: `./sre/local-scripts/deploy.sh v1.2.3`

### `teardown.sh`

Deletes the k3d cluster and local registry.

## Manual Steps

### Build the Docker image

```bash
docker build -t localhost:5111/tekmetric-backend:local -f sre/Dockerfile .
docker push localhost:5111/tekmetric-backend:local
```

### Deploy with Helm

```bash
helm upgrade --install tekmetric-backend sre/helm/tekmetric-backend \
  -n tekmetric-dev \
  --create-namespace \
  -f sre/helm/tekmetric-backend/values.yaml \
  -f sre/helm/tekmetric-backend/values-dev.yaml \
  --set image.repository=k3d-tekmetric-registry:5111/tekmetric-backend \
  --set image.tag=local \
  --set environment.name=local \
  --rollback-on-failure --wait --timeout 5m
```

### Verify

```bash
# Check pods
kubectl get pods -n tekmetric-dev

# Run Helm test
helm test tekmetric-backend -n tekmetric-dev

# Port-forward and hit the API
kubectl port-forward svc/tekmetric-backend 8080:80 -n tekmetric-dev
curl http://localhost:8080/api/welcome
```

### View logs

```bash
kubectl logs -n tekmetric-dev -l app.kubernetes.io/name=tekmetric-backend -f
```

### Upgrade after code changes

```bash
# Rebuild and redeploy
./sre/local-scripts/deploy.sh
```

### Rollback

```bash
helm history tekmetric-backend -n tekmetric-dev
helm rollback tekmetric-backend <REVISION> -n tekmetric-dev
```

### Teardown

```bash
./sre/local-scripts/teardown.sh
```

## Troubleshooting

**Pod stuck in `CrashLoopBackOff`:**
```bash
kubectl describe pod -n tekmetric-dev -l app.kubernetes.io/name=tekmetric-backend
kubectl logs -n tekmetric-dev -l app.kubernetes.io/name=tekmetric-backend --previous
```

**Pod stuck in `Pending`:**
```bash
# Usually a resource issue — check node capacity
kubectl describe pod -n tekmetric-dev -l app.kubernetes.io/name=tekmetric-backend
kubectl top nodes
```

**Image pull errors:**
```bash
# Verify the image exists in the local registry
docker image ls | grep tekmetric-backend
# Verify the registry is accessible from the cluster
kubectl run test --image=localhost:5111/tekmetric-backend:local --rm -it -- echo ok
```

**Helm deploy timed out:**
```bash
# Check what failed
kubectl get events -n tekmetric-dev --sort-by='.lastTimestamp'
```

**Reset everything:**
```bash
./sre/local-scripts/teardown.sh
./sre/local-scripts/setup.sh
./sre/local-scripts/deploy.sh
```

## Observability

Without Spring Boot Actuator, observability is infrastructure-level only. These commands work out of the box with the local cluster.

### Pod resource usage

```bash
kubectl top pods -n tekmetric-dev
```

### Pod status and health

```bash
kubectl get pods -n tekmetric-dev -o wide
```

### Logs

```bash
kubectl logs -n tekmetric-dev -l app.kubernetes.io/name=tekmetric-backend -f
```

### Pod events and probe status

```bash
kubectl describe pod -n tekmetric-dev -l app.kubernetes.io/name=tekmetric-backend
```

### Node capacity

```bash
kubectl top nodes
```
