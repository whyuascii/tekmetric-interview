# Next Steps

Improvements to build on top of the current setup, ordered by impact.

---

## 1. Infrastructure as Code (Terraform)

The AWS resources listed in REAL-DEPLOYMENT.md

### Modules to create

| Module | Resources |
|---|---|
| `vpc` | VPC, subnets (public/private across 3 AZs), NAT gateway, route tables |
| `eks` | EKS cluster, managed node groups, OIDC provider, aws-auth ConfigMap |
| `ecr` | ECR repository, lifecycle policy (expire untagged images after 14 days) |
| `iam` | GitHub Actions OIDC role, IRSA roles for pods, node group instance role |
| `alb` | AWS Load Balancer Controller via Helm provider, IAM policy |
| `dns` | Route 53 hosted zone, A-record alias to ALB |
| `acm` | ACM certificate with DNS validation |

### Suggested layout

```
terraform/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   └── terraform.tfvars
│   ├── staging/
│   └── production/
└── modules/
    ├── vpc/
    ├── eks/
    ├── ecr/
    ├── iam/
    ├── alb/
    ├── dns/
    └── acm/
```

---

## 2. Application Observability (Spring Boot Actuator)

The current setup uses infrastructure-level metrics only (CPU, memory, pod status). Adding Spring Boot Actuator unlocks application-level observability.

### Changes required

**`backend/pom.xml`** — add two dependencies:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

---

## 3. Structured Logging

Currently logs are plaintext. Structured JSON logs make them searchable and parseable by log aggregation tools.

### Changes required

Add to `backend/pom.xml`:

```xml
<dependency>
    <groupId>net.logstash.logback</groupId>
    <artifactId>logstash-logback-encoder</artifactId>
    <version>7.4</version>
</dependency>
```

---

## 4. Additional CI/CD Workflows

### Continuous Deployment

Add a workflow that deploys to EKS after a successful build:

```yaml
# .github/workflows/sre-deploy.yml
# Triggered after sre-ci.yml completes on main
# Steps:
#   1. Configure AWS credentials
#   2. Update kubeconfig
#   3. helm upgrade --install --rollback-on-failure --wait
```

This closes the gap between "image pushed to ECR" and "running on the cluster."

---
