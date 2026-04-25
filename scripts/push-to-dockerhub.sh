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

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

build_and_push() {
  local SERVICE_NAME=$1
  local SERVICE_PATH=$2
  local IMAGE_NAME="$DOCKER_USERNAME/$SERVICE_NAME:$TAG"

  echo -e "\n\033[1;36m>>> Building $IMAGE_NAME from $SERVICE_PATH...\033[0m"
  cd "$SCRIPT_DIR/$SERVICE_PATH"
  docker build -t "$IMAGE_NAME" .
  echo -e "\033[1;36m>>> Pushing $IMAGE_NAME...\033[0m"
  docker push "$IMAGE_NAME"
  cd "$SCRIPT_DIR"
}

build_and_push "genepay-biometric-service"   "../../../modules/genepay-biometric-service"
build_and_push "genepay-payment-service"     "../../../modules/genepay-payment-service"
build_and_push "genepay-blockchain-service"  "../../../modules/genepay-blockchain-service/relay"
build_and_push "genepay-admin-dashboard"     "../../../web/genepay-admin-dashboard"
build_and_push "genepay-blockchain-dashboard" "../../../web/genepay-blockchain-dashboard"
build_and_push "genepay-banking-system"      "../../../modules/genepay-banking-system"

echo -e "\n\033[1;32m==========================================================\033[0m"
echo -e "\033[1;32mAll builds and pushes completed successfully!\033[0m"
echo -e "\033[1;32m==========================================================\033[0m"
