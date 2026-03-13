# GenePay Kubernetes Manifests

This folder contains Kubernetes manifests for deploying the GenePay stack to your K3s cluster.

## Included resources

- `Namespace`: `genepay`
- `Secret`: `genepay-secrets` (sensitive values)
- `ConfigMap`: `genepay-config` (non-sensitive runtime config)
- `Deployment` + `Service`:
  - `postgres`
  - `biometric-service`
  - `blockchain-relay`
  - `payment-service`
  - `admin-dashboard`
  - `blockchain-dashboard`
- `Ingress`: `genepay-ingress`

## Before apply

1. Replace placeholder image names in all `Deployment` files:
   - `YOUR_ECR_URI/genepay-biometric-service:latest`
   - `YOUR_ECR_URI/genepay-blockchain-service:latest`
   - `YOUR_ECR_URI/genepay-payment-service:latest`
   - `YOUR_ECR_URI/genepay-admin-dashboard:latest`
   - `YOUR_ECR_URI/genepay-blockchain-dashboard:latest`
2. Edit `secret.yaml` with real secret values.
3. Edit `configmap.yaml` hostnames/URLs if needed.
4. Ensure Nginx ingress controller is installed in K3s.

## Deploy

```bash
cd infra/genepay-infra/k8s
kubectl apply -k .
```

## Verify

```bash
kubectl get all -n genepay
kubectl get ingress -n genepay
```

## Local host mapping for ingress

Add these entries in your local hosts file:

```txt
<K3S_NODE_PUBLIC_IP> app.genepay.local
<K3S_NODE_PUBLIC_IP> chain.genepay.local
<K3S_NODE_PUBLIC_IP> api.genepay.local
```
