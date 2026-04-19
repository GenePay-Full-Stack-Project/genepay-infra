#!/bin/bash

# Exit on any error
set -e

AWS_ACCOUNT_ID=${1:-"357343207025"}
REGION=${2:-"ap-southeast-1"}

REGISTRY_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "Logging into ECR $REGISTRY_URL..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY_URL"

# Paths relative to infra/genepay-infra/scripts
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Array of services map format: "image-name:relative/path"
SERVICES=(
    "genepay-admin-dashboard:web/genepay-admin-dashboard"
    "genepay-biometric-service:modules/genepay-biometric-service"
    "genepay-blockchain-dashboard:web/genepay-blockchain-dashboard"
    "genepay-blockchain-service:modules/genepay-blockchain-service/relay"
    "genepay-payment-service:modules/genepay-payment-service"
)

for item in "${SERVICES[@]}"; do
    SERVICE_NAME="${item%%:*}"
    SERVICE_PATH="${item##*:}"
    
    FULL_IMAGE_NAME="${REGISTRY_URL}/${SERVICE_NAME}:latest"
    FULL_PATH="$ROOT_DIR/$SERVICE_PATH"
    
    echo "----------------------------------------"
    echo -e "\e[32mBuilding ${SERVICE_NAME}...\e[0m"
    docker build -t "$FULL_IMAGE_NAME" "$FULL_PATH"
    
    echo -e "\e[32mPushing ${SERVICE_NAME} to ECR...\e[0m"
    docker push "$FULL_IMAGE_NAME"
done

echo "----------------------------------------"
echo -e "\e[32mAll images built and pushed to ECR successfully!\e[0m"
