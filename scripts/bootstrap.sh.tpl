#!/bin/bash
# Bootstrap script for GenePay K3s single-node cluster
# Runs as root via EC2 user-data on Amazon Linux 2023
# Terraform template variables: ${ aws_region } ${ project_name }

set -euo pipefail
exec > >(tee /var/log/genepay-bootstrap.log) 2>&1

echo "=== [1/5] System update ==="
dnf update -y
dnf install -y docker aws-cli jq

# ---------------------------------------------------------------------------
# Docker (needed so K3s can pull from ECR without a Kubernetes secret)
# ---------------------------------------------------------------------------
echo "=== [2/5] Configure Docker + ECR credential helper ==="
systemctl enable --now docker
usermod -aG docker ec2-user

# Install ECR credential helper so Docker can auth to ECR transparently
dnf install -y amazon-ecr-credential-helper
mkdir -p /root/.docker /home/ec2-user/.docker

cat > /root/.docker/config.json <<'DOCKERCFG'
{
  "credHelpers": {
    "${aws_region}.amazonaws.com": "ecr-login"
  }
}
DOCKERCFG

cp /root/.docker/config.json /home/ec2-user/.docker/config.json
chown -R ec2-user:ec2-user /home/ec2-user/.docker

# ---------------------------------------------------------------------------
# K3s — lightweight single-node Kubernetes
# ---------------------------------------------------------------------------
echo "=== [3/5] Install K3s ==="
export INSTALL_K3S_EXEC="server \
  --disable traefik \
  --write-kubeconfig-mode 644 \
  --tls-san $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"

curl -sfL https://get.k3s.io | sh -

# Wait until the API server is ready
echo "Waiting for K3s API to become ready..."
for i in $(seq 1 30); do
  kubectl get nodes --kubeconfig /etc/rancher/k3s/k3s.yaml &>/dev/null && break
  sleep 5
done

# Copy kubeconfig for ec2-user
mkdir -p /home/ec2-user/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config
chown ec2-user:ec2-user /home/ec2-user/.kube/config
chmod 600 /home/ec2-user/.kube/config

# ---------------------------------------------------------------------------
# Nginx Ingress Controller (replaces Traefik — more familiar config)
# ---------------------------------------------------------------------------
echo "=== [4/5] Install Nginx Ingress Controller ==="
kubectl apply \
  --kubeconfig /etc/rancher/k3s/k3s.yaml \
  -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/cloud/deploy.yaml

# ---------------------------------------------------------------------------
# ECR image pull secret helper script — run once per namespace if needed
# ---------------------------------------------------------------------------
echo "=== [5/5] Write ECR login helper ==="
cat > /usr/local/bin/ecr-k3s-login <<LOGINSCRIPT
#!/bin/bash
# Refreshes the ECR Docker credentials used by K3s containerd
# Run manually or add to cron: */6 * * * * /usr/local/bin/ecr-k3s-login

REGION="${aws_region}"
ACCOUNT_ID=\$(aws sts get-caller-identity --query Account --output text)
ECR_PASSWD=\$(aws ecr get-login-password --region \$REGION)
REGISTRY="\$ACCOUNT_ID.dkr.ecr.\$REGION.amazonaws.com"

# Create/update the imagePullSecret in the default namespace
kubectl create secret docker-registry ecr-pull-secret \
  --docker-server="\$REGISTRY" \
  --docker-username=AWS \
  --docker-password="\$ECR_PASSWD" \
  --namespace default \
  --dry-run=client -o yaml | kubectl apply -f -

echo "ECR pull secret refreshed for \$REGISTRY"
LOGINSCRIPT

chmod +x /usr/local/bin/ecr-k3s-login
/usr/local/bin/ecr-k3s-login || true   # best-effort on first boot

echo "=== Bootstrap complete for ${project_name} ==="
