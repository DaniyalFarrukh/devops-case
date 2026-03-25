# DevOps Case Study — MERN Stack Deployment on AWS

## Overview

This project demonstrates a production-grade deployment of a MERN (MongoDB, Express.js, React, Node.js) stack application along with a Python ETL service on AWS, using Docker, Kubernetes (K3s), GitHub Actions CI/CD, and Terraform for infrastructure as code.

---

## Architecture

```
Developer Laptop
    └── git push to GitHub
            │
            ▼
    GitHub Actions (CI/CD Pipeline)
        ├── Test Backend (Node.js)
        ├── Test Frontend (React)
        ├── Test Python ETL
        ├── Build & Push Docker Images → Docker Hub
        └── Deploy to EC2 via SSH
                    │
                    ▼
        AWS EC2 t3
.micro (3.223.246.202)
            └── K3s Kubernetes Cluster
                ├── React Frontend      → port 80   (2 replicas)
                ├── Express Backend     → port 5050  (2 replicas)
                ├── MongoDB             → internal   (persistent volume)
                └── Python ETL CronJob → runs hourly
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Cloud Provider | AWS (EC2, Elastic IP, Security Groups) |
| Infrastructure as Code | Terraform |
| Containerization | Docker |
| Container Orchestration | Kubernetes (K3s) |
| CI/CD | GitHub Actions |
| Frontend | React.js |
| Backend | Express.js / Node.js |
| Database | MongoDB |
| ETL Service | Python |
| Docker Registry | Docker Hub |

---

## Project Structure

```
devops-case/
├── frontend/               # React application
│   └── Dockerfile
├── backend/                # Express.js API
│   └── Dockerfile
├── etl/                    # Python ETL service
│   └── Dockerfile
├── k8s/                    # Kubernetes manifests
│   ├── namespace.yaml
│   ├── mongodb.yaml
│   ├── backend.yaml
│   ├── frontend.yaml
│   └── etl-cronjob.yaml
├── terraform/              # Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── .github/
│   └── workflows/
│       └── ci-cd.yml       # GitHub Actions pipeline
└── README.md
```

---

## Infrastructure Setup (Terraform)

The following AWS resources are provisioned via Terraform:

- **EC2 Instance** — `t3.micro` (free tier), Ubuntu 24.04
- **Security Group** — Allows inbound traffic on ports 22 (SSH), 80 (HTTP), 443 (HTTPS), 5050 (Backend API)
- **Elastic IP** — Static public IP `3.223.246.202` so the address persists across reboots
- **Bootstrap Script** — Automatically installs Docker and K3s on first boot

### Deploy Infrastructure

```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

---

## Containerization

Each application component has its own Dockerfile:

- **Frontend** — Multi-stage build: Node.js to build React app, Nginx to serve static files
- **Backend** — Node.js Alpine image, exposes port 5050
- **ETL** — Python 3 image, runs as a Kubernetes CronJob every hour
- **MongoDB** — Official `mongo` image with persistent volume claim

Docker images are pushed to Docker Hub under `daniyalf42003/`:
- `daniyalf42003/frontend`
- `daniyalf42003/backend`
- `daniyalf42003/etl`

---

## Kubernetes Deployment

The application runs in the `mern-app` namespace on a K3s cluster.

### Apply all manifests

```bash
kubectl apply -f k8s/
```

### Key resources

| Resource | Type | Details |
|---|---|---|
| `mongodb` | Deployment + PVC | Persistent storage via local-path provisioner |
| `backend` | Deployment + Service | 2 replicas, ClusterIP service |
| `frontend` | Deployment + Service | 2 replicas, NodePort on 80 |
| `mern-ingress` | Ingress | Traefik routes traffic to frontend/backend |
| `etl-cronjob` | CronJob | Runs Python ETL every hour |

### Check pod status

```bash
kubectl get pods -n mern-app
kubectl get services -n mern-app
```

---

## CI/CD Pipeline (GitHub Actions)

The pipeline is defined in `.github/workflows/ci-cd.yml` and runs on every push to `main`.

### Pipeline Stages

```
Push to main
    │
    ├── [Parallel] Test Backend     → npm test
    ├── [Parallel] Test Frontend    → npm test
    ├── [Parallel] Test Python ETL  → pytest
    │
    ├── Build & Push Docker Images  → pushes to Docker Hub
    │
    └── Deploy to EC2 (K3s)
            ├── SSH into EC2
            ├── kubectl apply -f k8s/
            └── kubectl rollout restart deployments
```

### GitHub Secrets Required

| Secret | Description |
|---|---|
| `EC2_PUBLIC_IP` | Public IP of the EC2 instance |
| `DOCKER_PASSWORD` | Docker Hub access token |
| `EC2_SSH_PRIVATE_KEY` | Full private key including BEGIN/END headers |

---

## Logging

Application logs are accessible via `kubectl logs`:

```bash
# View backend logs
kubectl logs -l app=backend -n mern-app --tail=100

# View frontend logs
kubectl logs -l app=frontend -n mern-app --tail=100

# View MongoDB logs
kubectl logs -l app=mongodb -n mern-app --tail=100

# View ETL job logs
kubectl logs -l app=etl -n mern-app --tail=100
```

K3s also stores node-level logs accessible via:
```bash
sudo journalctl -u k3s -f
```

---

## Alerts & Monitoring

- **GitHub Actions** sends pipeline failure notifications via the built-in GitHub notification system on any job failure.
- **UptimeRobot** is configured to monitor `http://3.223.246.202` and `http://3.223.246.202:5050/healthcheck` with email alerts if the endpoints go down.
- **Kubernetes** restarts crashed containers automatically via the default restart policy (`Always`).

---

## Accessing the Application

| Service | URL |
|---|---|
| Frontend | http://3.223.246.202 |
| Backend Healthcheck | http://3.223.246.202:5050/healthcheck |

---

## Challenges & Solutions

### 1. t3.micro Memory Constraints
**Problem:** K3s requires ~600MB RAM at minimum. The t3.micro instance only has 1GB total, leaving very little headroom for application pods. K3s would frequently crash due to OOM (Out of Memory) errors.

**Solution:** Added 2GB of swap space to the EC2 instance, giving the OS virtual memory to fall back on:
```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### 2. SSH Private Key Format in GitHub Secrets
**Problem:** The deploy job failed with `Permission denied (publickey)` because the SSH private key was pasted into GitHub Secrets without the `-----BEGIN OPENSSH PRIVATE KEY-----` and `-----END OPENSSH PRIVATE KEY-----` header/footer lines.

**Solution:** Re-added the secret with the complete key including all header and footer lines. The key must be copied exactly as output by `cat ~/.ssh/mern-deployer`.

### 3. K3s API Server TLS Timeout
**Problem:** After deploying pods, the K3s API server became unresponsive with TLS handshake timeouts due to memory pressure.

**Solution:** Clearing the OS page cache and restarting K3s freed up enough memory:
```bash
sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
sudo systemctl restart k3s
```

### 4. Kubernetes Namespace Race Condition
**Problem:** Running `kubectl apply -f k8s/` failed on first run because the namespace was being created in the same apply command that tried to use it.

**Solution:** Running `kubectl apply -f k8s/` a second time resolved it — the namespace existed on the second run.

---

## Security Considerations

- SSH access is restricted to key-based authentication only (no password login)
- MongoDB is not exposed outside the cluster (ClusterIP only)
- Docker Hub credentials and SSH keys are stored as GitHub Secrets, never in code
- Security Group restricts inbound ports to only what is necessary (22, 80, 443, 5050)
- Terraform state should be stored in an S3 backend with encryption for production use

---

## Repository

GitHub: [https://github.com/DaniyalFarrukh/devops-case](https://github.com/DaniyalFarrukh/devops-case)
