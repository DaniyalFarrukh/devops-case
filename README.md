# DevOps Case Study — MERN Stack + Python ETL Deployment

**Author:** Daniyal Farrukh  
**Stack:** Docker · Kubernetes (K3s) · Terraform · GitHub Actions · AWS EC2  
**Docker Hub:** [daniyalf42003](https://hub.docker.com/u/daniyalf42003)

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Repository Structure](#repository-structure)
3. [Prerequisites](#prerequisites)
4. [Local Development (Docker Compose)](#local-development-docker-compose)
5. [Cloud Deployment (AWS EC2 + K3s)](#cloud-deployment-aws-ec2--k3s)
   - [Step 1 — Provision Infrastructure (Terraform)](#step-1--provision-infrastructure-terraform)
   - [Step 2 — Configure GitHub Secrets](#step-2--configure-github-secrets)
   - [Step 3 — Push to Main (Triggers CI/CD)](#step-3--push-to-main-triggers-cicd)
   - [Step 4 — Verify Deployment](#step-4--verify-deployment)
6. [CI/CD Pipeline](#cicd-pipeline)
7. [Kubernetes Manifests](#kubernetes-manifests)
8. [Logging & Alerts](#logging--alerts)
9. [Python ETL Project](#python-etl-project)
10. [Acceptance Criteria Checklist](#acceptance-criteria-checklist)
11. [Challenges & Solutions](#challenges--solutions)
12. [Security Considerations](#security-considerations)

---

## Architecture Overview

```
                         GitHub Push (main)
                               │
                    ┌──────────▼──────────┐
                    │   GitHub Actions    │
                    │  CI/CD Pipeline     │
                    │  ① Test all code    │
                    │  ② Build images     │
                    │  ③ Push → DockerHub │
                    │  ④ SSH → EC2 deploy │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │   AWS EC2 t2.micro  │  ← Provisioned by Terraform
                    │   (Free Tier)       │
                    │                     │
                    │  ┌───────────────┐  │
                    │  │  K3s Cluster  │  │  ← Lightweight Kubernetes
                    │  │               │  │
                    │  │  [Frontend]   │  │  React (nginx) — Port 80
                    │  │  [Backend]    │  │  Express.js    — Port 5050
                    │  │  [MongoDB]    │  │  Internal only — Port 27017
                    │  │  [ETL Cron]   │  │  Runs every 1 hour
                    │  └───────────────┘  │
                    └─────────────────────┘
                               │
                    Public IP (Elastic IP)
                    http://<EC2-IP>        → Frontend
                    http://<EC2-IP>:5050   → Backend API
```

---

## Repository Structure

```
devops-case/
├── mern-project/
│   ├── client/                   # React frontend
│   │   ├── Dockerfile            # Multi-stage: Node build → nginx serve
│   │   ├── nginx.conf            # nginx config with API proxy
│   │   └── src/
│   └── server/                   # Express.js backend
│       ├── Dockerfile            # Multi-stage Node.js build
│       ├── server.mjs            # Entry point (port 5050)
│       ├── db/conn.mjs           # MongoDB connection
│       └── routes/               # /record and /healthcheck
├── python-project/
│   ├── ETL.py                    # Fetches GitHub API data
│   ├── Dockerfile
│   └── requirements.txt
├── k8s/
│   ├── mern/
│   │   ├── namespace.yaml        # mern-app namespace
│   │   ├── mongodb.yaml          # MongoDB + PVC + Service
│   │   ├── backend.yaml          # Backend Deployment + Service
│   │   └── frontend.yaml         # Frontend Deployment + Service + Ingress
│   └── python/
│       └── etl-cronjob.yaml      # CronJob — runs ETL every hour
├── terraform/
│   ├── main.tf                   # EC2 + Security Group + EIP
│   ├── variables.tf
│   ├── outputs.tf
│   └── scripts/
│       └── bootstrap.sh          # Installs Docker + K3s on EC2
├── monitoring/
│   └── alert-rules.yaml          # Prometheus alert rules
├── docker-compose.yml            # Local development
└── .github/
    └── workflows/
        └── ci-cd.yml             # Full CI/CD pipeline
```

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Docker Desktop | Latest | https://docs.docker.com/get-docker/ |
| Terraform | >= 1.5.0 | https://developer.hashicorp.com/terraform/install |
| AWS CLI | >= 2.x | https://aws.amazon.com/cli/ |
| kubectl | Latest | https://kubernetes.io/docs/tasks/tools/ |
| Git | Any | https://git-scm.com/ |

You also need:
- An **AWS account** (free tier is sufficient)
- A **Docker Hub account** (free)
- A **GitHub account** with this repo forked/cloned

---

## Local Development (Docker Compose)

The fastest way to run the full stack locally:

```bash
# 1. Clone the repo
git clone https://github.com/DaniyalFarrukh/devops-case.git
cd devops-case

# 2. Start all services
docker compose up --build

# 3. Access the app
# Frontend:  http://localhost
# Backend:   http://localhost:5050
# Healthcheck: http://localhost:5050/healthcheck
```

To stop:
```bash
docker compose down -v
```

---

## Cloud Deployment (AWS EC2 + K3s)

### Step 1 — Provision Infrastructure (Terraform)

```bash
# Configure AWS credentials
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-east-1), output (json)

# Go to terraform directory
cd terraform

# Generate SSH key pair (if you don't have one)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/mern-deployer -N ""

# Initialize Terraform
terraform init

# Preview what will be created
terraform plan -var="ssh_public_key=$(cat ~/.ssh/mern-deployer.pub)"

# Apply — creates EC2, Security Group, Elastic IP
terraform apply -var="ssh_public_key=$(cat ~/.ssh/mern-deployer.pub)"

# Note the outputs — you'll need the public IP
# Example output:
#   server_public_ip = "54.123.45.67"
#   ssh_command      = "ssh -i ~/.ssh/mern-deployer ubuntu@54.123.45.67"
#   app_url          = "http://54.123.45.67"
```

Wait ~3 minutes for the EC2 bootstrap script to finish installing Docker and K3s.

Verify K3s is running:
```bash
ssh -i ~/.ssh/mern-deployer ubuntu@<EC2-IP>
kubectl get nodes
# Should show: STATUS = Ready
```

---

### Step 2 — Configure GitHub Secrets

In your GitHub repo → **Settings → Secrets and variables → Actions → New repository secret**

| Secret Name | Value |
|-------------|-------|
| `DOCKER_PASSWORD` | Your Docker Hub password or access token |
| `EC2_PUBLIC_IP` | The IP from `terraform output server_public_ip` |
| `EC2_SSH_PRIVATE_KEY` | Contents of `~/.ssh/mern-deployer` (private key) |

To get private key content:
```bash
cat ~/.ssh/mern-deployer
# Copy everything including -----BEGIN RSA PRIVATE KEY----- lines
```

---

### Step 3 — Push to Main (Triggers CI/CD)

```bash
git add .
git commit -m "Initial deployment"
git push origin main
```

GitHub Actions will automatically:
1. ✅ Run backend tests
2. ✅ Run frontend tests
3. ✅ Run Python ETL smoke test
4. 🐳 Build and push all 3 Docker images to Docker Hub
5. 🚀 SSH into EC2 and apply all Kubernetes manifests
6. ⏳ Wait for rolling deployment to complete

Monitor the pipeline at: `https://github.com/DaniyalFarrukh/devops-case/actions`

---

### Step 4 — Verify Deployment

```bash
# SSH into EC2
ssh -i ~/.ssh/mern-deployer ubuntu@<EC2-IP>

# Check all pods are running
kubectl get pods -n mern-app

# Expected output:
# NAME                        READY   STATUS    RESTARTS
# mongodb-xxxx                1/1     Running   0
# backend-xxxx                1/1     Running   0
# backend-yyyy                1/1     Running   0
# frontend-xxxx               1/1     Running   0
# frontend-yyyy               1/1     Running   0

# Check services
kubectl get services -n mern-app

# Check ingress
kubectl get ingress -n mern-app

# Test healthcheck endpoint
curl http://localhost:5050/healthcheck
# Expected: {"uptime":...,"message":"OK","timestamp":...}
```

Access in browser:
- **Frontend:** `http://<EC2-IP>`
- **Backend API:** `http://<EC2-IP>:5050/healthcheck`
- **Records API:** `http://<EC2-IP>:5050/record`

---

## CI/CD Pipeline

The pipeline defined in `.github/workflows/ci-cd.yml` has **5 jobs**:

```
test-backend ──┐
               ├──► build-and-push ──► deploy
test-frontend ─┤
               │
test-python ───┘
```

| Job | Trigger | What it does |
|-----|---------|-------------|
| `test-backend` | Every push/PR | `npm ci` + `npm test` |
| `test-frontend` | Every push/PR | `npm ci` + React tests |
| `test-python` | Every push/PR | Runs `ETL.py` as smoke test |
| `build-and-push` | Push to main only | Builds 3 Docker images, pushes to Docker Hub with `latest` + commit SHA tags |
| `deploy` | Push to main only | SSHs into EC2, applies K8s manifests, triggers rolling restart |

---

## Kubernetes Manifests

| File | Resources Created |
|------|-----------------|
| `namespace.yaml` | `mern-app` namespace |
| `mongodb.yaml` | Deployment, PVC (5Gi), ClusterIP Service |
| `backend.yaml` | Deployment (2 replicas), ClusterIP Service |
| `frontend.yaml` | Deployment (2 replicas), NodePort Service, Ingress |
| `etl-cronjob.yaml` | CronJob (schedule: `0 * * * *`) |

Key design decisions:
- **MongoDB** is `ClusterIP` only — never exposed to the internet
- **Backend** has 2 replicas for high availability
- **Frontend** is served by nginx with React Router support
- **ETL** runs as a K8s CronJob every hour as required by the README

---

## Logging & Alerts

### Viewing Logs

```bash
# Backend logs
kubectl logs -l app=backend -n mern-app --tail=100 -f

# Frontend logs
kubectl logs -l app=frontend -n mern-app --tail=50

# MongoDB logs
kubectl logs -l app=mongodb -n mern-app

# ETL job logs
kubectl logs -l app=etl-job -n mern-app
```

### Alert Rules

Defined in `monitoring/alert-rules.yaml`. Alerts fire for:

| Alert | Condition | Severity |
|-------|-----------|----------|
| `BackendDown` | 0 backend replicas available | Critical |
| `FrontendDown` | 0 frontend replicas available | Critical |
| `MongoDBDown` | MongoDB pod not ready for 2m | Critical |
| `ETLJobFailed` | Any CronJob failure | Warning |
| `HighCPUUsage` | Container CPU > 80% for 5m | Warning |
| `HighMemoryUsage` | Container memory > 85% limit | Warning |

Apply monitoring rules:
```bash
kubectl apply -f monitoring/alert-rules.yaml
```

---

## Python ETL Project

The `ETL.py` script fetches data from the GitHub API and prints the response. It is containerized and runs as a **Kubernetes CronJob every hour**.

```bash
# Run manually to test
cd python-project
pip install -r requirements.txt
python ETL.py

# Or via Docker
docker build -t python-etl .
docker run python-etl

# Check CronJob status on cluster
kubectl get cronjobs -n mern-app
kubectl get jobs -n mern-app
```

---

## Acceptance Criteria Checklist

### MERN Project
- [x] MongoDB connected (via `mongodb-service:27017` in K8s)
- [x] All endpoints working (`/record` GET, POST, PATCH, DELETE + `/healthcheck`)
- [x] All pages working (React Router: `/`, `/records`, `/create`, `/edit/:id`)

### Python Project
- [x] `ETL.py` runs successfully
- [x] Runs every 1 hour (K8s CronJob: `schedule: "0 * * * *"`)

### DevOps Requirements
- [x] Dockerfiles for all components
- [x] Kubernetes manifests (K3s on EC2)
- [x] CI/CD pipeline (GitHub Actions)
- [x] Infrastructure as Code (Terraform)
- [x] Logging & Alerts (kubectl logs + Prometheus rules)
- [x] Documentation (this README)

---

## Challenges & Solutions

| Challenge | Solution |
|-----------|----------|
| EKS costs money on free tier | Used **K3s** on EC2 t2.micro — still real Kubernetes, zero cluster management fee |
| MongoDB needs persistent storage in K8s | Used **PersistentVolumeClaim** so data survives pod restarts |
| React app needs backend URL at build time | Passed `REACT_APP_API_URL` as Docker **build argument** in CI/CD |
| nginx needs to support React Router | Configured `try_files $uri /index.html` to handle client-side routing |
| EC2 needs Docker + K3s installed | **user_data bootstrap script** runs automatically on first boot |
| Images need to update on deploy | `kubectl rollout restart` forces pods to pull `:latest` image |

---

## Security Considerations

- Backend and MongoDB communicate **inside the cluster only** (ClusterIP)
- MongoDB is **never exposed** on a public port
- Docker containers run as **non-root users**
- SSH key authentication used (no passwords)
- Sensitive values stored as **GitHub Secrets** — never hardcoded
- Security group restricts inbound to only necessary ports (22, 80, 443, 5050)

---

## Teardown

To avoid any AWS charges after submission:

```bash
cd terraform
terraform destroy -var="ssh_public_key=$(cat ~/.ssh/mern-deployer.pub)"
```

This removes the EC2 instance, Security Group, and Elastic IP.
