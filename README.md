# KubeWatch — CareerLens on Kubernetes

> Self-healing, auto-scaling full-stack app on AWS EKS with Terraform IaC, GitHub Actions CI/CD, and Prometheus/Grafana observability.

[![CI](https://github.com/gaus13/careerlens/actions/workflows/ci.yml/badge.svg)](https://github.com/gaus13/careerlens/actions)

---

## Architecture

```mermaid
graph TB
    Dev[👨‍💻 Developer] -->|git push| GH[GitHub]
    GH -->|trigger| CI[CI — Build & Push to ECR]
    CI -->|SHA-tagged image| ECR[AWS ECR]
    ECR -->|pull| CD[CD — Deploy to EKS]
    
    CD --> EKS

    subgraph EKS [AWS EKS Cluster — ap-south-1]
        ALB[Application Load Balancer]
        ALB -->|/| FE[React Frontend\n2 pods]
        ALB -->|/api| BE[FastAPI Backend\n2-5 pods]
        BE --> DB[(PostgreSQL\nStatefulSet + EBS)]
        HPA[HPA] -->|scale on CPU > 50%| BE
        PROM[Prometheus] -->|scrape metrics| BE
        PROM --> GRAF[Grafana Dashboard]
    end

    Internet[🌍 Internet] --> ALB
```

---

## Tech Stack

| Category | Technology |
|----------|-----------|
| App | React + FastAPI + PostgreSQL |
| Registry | AWS ECR |
| Orchestration | Kubernetes on AWS EKS v1.31 |
| IaC | Terraform |
| CI/CD | GitHub Actions |
| Monitoring | Prometheus + Grafana + Alertmanager |
| Networking | AWS VPC + ALB + NAT Gateway |
| Storage | AWS EBS via CSI Driver |

---

## CI/CD Pipeline

```mermaid
flowchart LR
    A[git push] --> B[GitHub Actions CI]
    B --> C[Build Images]
    C --> D[Tag with Git SHA]
    D --> E[Push to ECR]
    E -->|CI passes| F[GitHub Actions CD]
    F --> G[Connect to EKS]
    G --> H[kubectl set image]
    H --> I[Rolling Update]
    I --> J[Verify Pod Health]
    J --> K[✅ Live]
```

---

## Self-Healing Flow

```mermaid
sequenceDiagram
    participant Pod as Backend Pod
    participant RS as ReplicaSet
    participant K8s as Kubernetes

    Pod->>Pod: crashes / deleted
    K8s->>RS: pod count dropped below desired
    RS->>K8s: schedule new pod
    K8s->>Pod: new pod created
    Note over Pod,K8s: Recovery in ~18 seconds
    Note over Pod,K8s: Zero traffic impact
```

---

## AWS Infrastructure

```mermaid
graph TB
    subgraph VPC [AWS VPC — 10.0.0.0/16]
        subgraph PUB [Public Subnets]
            IGW[Internet Gateway]
            ALB[Application Load Balancer]
            NAT[NAT Gateway]
        end
        subgraph PRIV [Private Subnets]
            NODE1[EKS Node 1\nt3.small]
            NODE2[EKS Node 2\nt3.small]
        end
    end

    Internet --> IGW --> ALB --> NODE1
    ALB --> NODE2
    NODE1 --> NAT --> Internet
    NODE2 --> NAT
```

---

## Results

### Chaos Engineering
| Experiment | Recovery | Impact |
|------------|----------|--------|
| Kill 1 backend pod | ~18 sec | Zero |
| Kill ALL pods | ~25 sec | Auto-recovery |
| OOM Kill (10Mi limit) | ~10 sec | Auto restart |
| Bad liveness probe | CrashLoopBackOff | Backoff |
| HPA load test | ~60 sec | 2→5 pods |

### HPA Load Test
| Phase | CPU | Pods |
|-------|-----|------|
| Idle | 3% | 2 |
| Load start | 73% | 3 |
| Peak | 152% | 5 (max) |
| After load | 3% | 2 |

Scale up: ~60s · Scale down: ~5min (stabilization window)

---

## Monitoring Dashboard

![Grafana Dashboard](screenshots/grafana-dashboard.png)

**5 Custom Panels:** Pod Restarts · CPU Usage · Memory (MB) · Pod Count · Node CPU %

---

## Quick Start

```bash
# 1. Create infrastructure
cd terraform && terraform apply

# 2. Connect kubectl
aws eks update-kubeconfig --name careerlens --region ap-south-1

# 3. Deploy app
kubectl apply -f k8s/

# 4. Install monitoring
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --values monitoring/prometheus-values.yaml

# 5. Access Grafana
kubectl port-forward -n monitoring service/monitoring-grafana 3000:80
# http://localhost:3000 → admin / careerlens123

# 6. Destroy when done (saves ~$4.58/day)
cd terraform && terraform destroy
```

---

## Repository Structure

```
careerlens-k8s/
├── k8s/                    # Kubernetes manifests
├── terraform/              # AWS infrastructure (IaC)
├── monitoring/             # Prometheus + Grafana config
├── .github/workflows/      # CI/CD pipelines
├── screenshots/            # Dashboard + evidence
└── RUNBOOK.md              # Incident response guide
```

---

## Cost Estimate

| Resource | Cost/Day |
|----------|---------|
| EKS Control Plane | $2.40 |
| 2× t3.small nodes | $1.10 |
| NAT Gateway | $1.08 |
| **Total** | **~$4.58** |

> Always run `terraform destroy` when done!

---

**Built by [Danish](https://github.com/gaus13) · B.Tech CSE**
