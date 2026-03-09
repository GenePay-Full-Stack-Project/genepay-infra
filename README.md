# genepay-infra

Terraform infrastructure for the GenePay university demo.
Provisions a single **K3s** node on AWS EC2 and **ECR** repositories for every service image.

## Architecture

```
AWS
├── ECR (5 repositories)
│   ├── genepay-payment-service       (Spring Boot)
│   ├── genepay-biometric-service     (FastAPI + face-recognition)
│   ├── genepay-blockchain-service    (Node.js)
│   ├── genepay-admin-dashboard       (React/Vite static)
│   └── genepay-blockchain-dashboard  (React/TS/Vite static)
│
└── EC2  t3.large  (2 vCPU / 8 GB)
    ├── K3s single-node Kubernetes cluster
    ├── Nginx Ingress Controller
    └── All services deployed as K8s Deployments + Services
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6
- AWS CLI configured (`aws configure`)
- An existing EC2 key pair in the target region

## Quick Start

```bash
cd infra/genepay-infra

# 1. Initialise providers
terraform init

# 2. Review the plan (supply your key pair name)
terraform plan -var="key_pair_name=my-key"

# 3. Apply
terraform apply -var="key_pair_name=my-key"
```

After ~3–5 minutes the instance finishes bootstrapping.

## Fetch the kubeconfig

Terraform prints a ready-to-run command:

```bash
terraform output -raw kubeconfig_fetch_command | bash
export KUBECONFIG=~/.kube/genepay-k3s.yaml
kubectl get nodes    # should show Ready
```

## Push an image to ECR

```bash
# Get the ECR URL for a service
ECR_URL=$(terraform output -json ecr_repository_urls | jq -r '.["genepay-payment-service"]')

# Authenticate Docker
aws ecr get-login-password --region ap-southeast-1 | \
  docker login --username AWS --password-stdin "$ECR_URL"

# Tag & push
docker tag genepay-payment-service:latest "$ECR_URL:latest"
docker push "$ECR_URL:latest"
```

## Variables

| Name | Default | Description |
|---|---|---|
| `aws_region` | `ap-southeast-1` | AWS region |
| `instance_type` | `t3.large` | EC2 instance size |
| `key_pair_name` | *(required)* | Existing EC2 key pair name |
| `allowed_ssh_cidrs` | `0.0.0.0/0` | Restrict to your IP in production |
| `root_volume_size_gb` | `30` | Root EBS size (GB) |

## Teardown

```bash
terraform destroy -var="key_pair_name=my-key"
```
