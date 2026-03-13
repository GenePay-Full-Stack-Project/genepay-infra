#!/bin/bash
# push-to-dockerhub.sh
# Script to build and push GenePay images to Docker Hub

set -e

if [ -z "$1" ]; then
  echo "Error: Docker Hub username required."
  echo "Usage: ./push-to-dockerhub.sh <dockerhub_username> [tag]"
  exit 1
fi

DOCKER_USERNAME=$1
TAG=${2:-latest}

echo "=========================================================="
echo "GenePay Docker Hub Push Script"
echo "Pushing to namespace: $DOCKER_USERNAME with tag: $TAG"
echo "=========================================================="
echo "Ensure you are logged in first by running: docker login"
echo "=========================================================="

# Define the services to build (Name and relative path from script directory)
declare -A SERVICES=(
    ["genepay-biometric-service"]="../../../modules/genepay-biometric-service"
    ["genepay-blockchain-service"]="../../../modules/genepay-blockchain-service/relay"
    ["genepay-payment-service"]="../../../modules/genepay-payment-service"
    ["genepay-admin-dashboard"]="../../../web/genepay-admin-dashboard"
    ["genepay-blockchain-dashboard"]="../../../web/genepay-blockchain-dashboard"
)

# Ensure script is run from its own directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

for SERVICE_NAME in "${!SERVICES[@]}"; do
    SERVICE_PATH="${SERVICES[$SERVICE_NAME]}"
    IMAGE_NAME="$DOCKER_USERNAME/$SERVICE_NAME:$TAG"
    
    echo -e "\n\033[1;36m>>> Building $IMAGE_NAME from $SERVICE_PATH...\033[0m"
    cd "$SERVICE_PATH"
    
    docker build -t "$IMAGE_NAME" .
    
    echo -e "\033[1;36m>>> Pushing $IMAGE_NAME...\033[0m"
    docker push "$IMAGE_NAME"
    
    cd "$SCRIPT_DIR"
done

echo -e "\n\033[1;32m==========================================================\033[0m"
echo -e "\033[1;32mAll builds and pushes completed successfully!\033[0m"
echo -e "\033[1;32m==========================================================\033[0m"
echo "Don't forget to update your Kubernetes deployment files to use:"
echo "$DOCKER_USERNAME/<image_name>:$TAG"
echo "instead of 'YOUR_ECR_URI/...'"
