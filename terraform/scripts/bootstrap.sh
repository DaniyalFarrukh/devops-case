#!/bin/bash
set -e

# ─── System Update ────────────────────────────────────────────────
apt-get update -y
apt-get upgrade -y
apt-get install -y curl wget git

# ─── Install Docker ───────────────────────────────────────────────
curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker

# ─── Install K3s (lightweight Kubernetes) ─────────────────────────
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -
systemctl enable k3s
systemctl start k3s

# Wait for K3s to be ready
sleep 30

# Make kubectl available to ubuntu user
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config
echo "export KUBECONFIG=/home/ubuntu/.kube/config" >> /home/ubuntu/.bashrc

# ─── Log completion ───────────────────────────────────────────────
echo "Bootstrap complete — Docker and K3s installed" >> /var/log/bootstrap.log
