# AWS Deployment Guide

Deploy the Tekmetric backend to Amazon EKS.

---

## Prerequisites

### Tools

- AWS CLI
- Docker
- kubectl
- Helm
- eksctl

### AWS Resources

These must exist before deploying. See [NEXT-STEPS.md](NEXT-STEPS.md) for Terraform automation.

| Resource | Purpose |
|---|---|
| EKS cluster | Kubernetes control plane + node groups |
| ECR repository | `tekmetric-backend` — stores Docker images |
| IAM OIDC provider | GitHub Actions authentication (no long-lived keys) |
| IAM role for GitHub Actions | Permissions to push to ECR |
| IAM role for IRSA | (Optional) Pod-level AWS access via ServiceAccount |
| AWS ALB Ingress Controller | Installed on the cluster — handles Ingress resources |
| ACM certificate | TLS certificate for the domain |
| Route 53 hosted zone | (Optional) DNS for the ingress hostname |

---

## Step 1: Configure AWS CLI

```bash
aws configure
# Or if using SSO:
aws sso login --profile tekmetric
```

Verify access:

```bash
aws sts get-caller-identity
aws eks list-clusters --region us-east-1
```

## Step 2: Connect kubectl to EKS

```bash
aws eks update-kubeconfig \
  --name tekmetric-cluster \
  --region us-east-1

# Verify
kubectl get nodes
```

## Step 3: Create the ECR Repository (one-time)

```bash
aws ecr create-repository \
  --repository-name tekmetric-backend \
  --region us-east-1 \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256
```

## Step 4: ECR Lifecycle Policy (one-time)

Auto-expire untagged images after 14 days to control storage costs:

```bash
aws ecr put-lifecycle-policy \
  --repository-name tekmetric-backend \
  --region us-east-1 \
  --lifecycle-policy-text '{
    "rules": [
      {
        "rulePriority": 1,
        "description": "Expire untagged images after 14 days",
        "selection": {
          "tagStatus": "untagged",
          "countType": "sinceImagePushed",
          "countUnit": "days",
          "countNumber": 14
        },
        "action": { "type": "expire" }
      }
    ]
  }'
```

## Step 5: Enable EKS Control Plane Logging (one-time)

Send API server, audit, and authenticator logs to CloudWatch for troubleshooting and security auditing:

```bash
aws eks update-cluster-config \
  --name tekmetric-cluster \
  --region us-east-1 \
  --logging '{
    "clusterLogging": [
      {
        "types": ["api", "audit", "authenticator"],
        "enabled": true
      }
    ]
  }'
```

Logs appear in CloudWatch under `/aws/eks/tekmetric-cluster/cluster`.

## Step 6: Build and Push the Docker Image

```bash
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

docker build -t tekmetric-backend:latest -f sre/Dockerfile .

docker tag tekmetric-backend:latest \
  <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/tekmetric-backend:latest

docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/tekmetric-backend:latest
```

In production, CI/CD handles this automatically — see `.github/workflows/sre-ci.yml`.

## Step 7: Deploy with Helm

### Staging

```bash
helm upgrade --install tekmetric-backend ./sre/helm/tekmetric-backend \
  -n tekmetric-staging \
  --create-namespace \
  -f sre/helm/tekmetric-backend/values.yaml \
  -f sre/helm/tekmetric-backend/values-staging.yaml \
  --set image.repository=<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/tekmetric-backend \
  --set image.tag=latest \
  --rollback-on-failure \
  --wait \
  --timeout 10m
```

### Production

```bash
helm upgrade --install tekmetric-backend ./sre/helm/tekmetric-backend \
  -n tekmetric-prod \
  --create-namespace \
  -f sre/helm/tekmetric-backend/values.yaml \
  -f sre/helm/tekmetric-backend/values-production.yaml \
  --set image.repository=<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/tekmetric-backend \
  --set image.tag=latest \
  --set ingress.annotations."alb\.ingress\.kubernetes\.io/certificate-arn"=arn:aws:acm:us-east-1:<ACCOUNT_ID>:certificate/<CERT_ID> \
  --rollback-on-failure \
  --wait \
  --timeout 10m \
  --history-max 10
```

## Step 8: Verify

```bash
kubectl get pods -n tekmetric-prod -l app.kubernetes.io/name=tekmetric-backend

helm test tekmetric-backend -n tekmetric-prod

kubectl get ingress -n tekmetric-prod

curl https://api.tekmetric.example.com/api/welcome
```

---

## Day-to-Day Operations

### Deploy a new version

CI/CD pushes a new image tag on merge to main. To deploy it:

```bash
helm upgrade --install tekmetric-backend ./sre/helm/tekmetric-backend \
  -n tekmetric-prod \
  --create-namespace \
  -f sre/helm/tekmetric-backend/values.yaml \
  -f sre/helm/tekmetric-backend/values-production.yaml \
  --set image.repository=<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/tekmetric-backend \
  --set image.tag=<NEW_SHA_TAG> \
  --rollback-on-failure --wait --timeout 10m
```

`--rollback-on-failure` automatically rolls back if pods don't become Ready.

### Rollback

```bash
# View release history
helm history tekmetric-backend -n tekmetric-prod

# Roll back to a specific revision
helm rollback tekmetric-backend <REVISION> -n tekmetric-prod
```

### View logs

```bash
kubectl logs -n tekmetric-prod -l app.kubernetes.io/name=tekmetric-backend -f
```

### Check resource usage

```bash
kubectl top pods -n tekmetric-prod -l app.kubernetes.io/name=tekmetric-backend
```

### Scale manually (overrides HPA temporarily)

```bash
kubectl scale deployment tekmetric-backend -n tekmetric-prod --replicas=5
```

---

## Disaster Recovery

### Backup

Export the current Helm release state (values, manifests, hooks):

```bash
helm get all tekmetric-backend -n tekmetric-prod > tekmetric-backend-backup.yaml
```

For full cluster backup (namespaces, PVs, CRDs), use [Velero](https://velero.io/):

```bash
velero backup create tekmetric-daily --include-namespaces tekmetric-prod
velero backup get
```

### Recovery procedures

**Bad deploy (pods failing):**
`--rollback-on-failure` auto-rolls back. If a release is stuck, roll back manually:

```bash
helm history tekmetric-backend -n tekmetric-prod
helm rollback tekmetric-backend <REVISION> -n tekmetric-prod
```

**Full redeployment (cluster rebuilt or lost):**

1. Reconnect kubectl (Step 2)
2. Redeploy with Helm (Step 7) — the image is still in ECR
3. Verify (Step 8)

### Recovery targets

| Metric | Target | How |
|---|---|---|
| RTO (time to recover) | < 15 minutes | `helm upgrade --install --rollback-on-failure --wait` from CI/CD or manual |
| RPO (data loss window) | Zero for stateless app | No persistent state — all data lives in external services |

Multi-AZ availability is enforced via `topologySpreadConstraints` in the Helm chart.

---
