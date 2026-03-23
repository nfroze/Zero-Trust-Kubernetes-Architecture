#!/usr/bin/env bash
###############################################################################
# Build and push all microservice images to ECR
#
# Usage: ./scripts/build-and-push.sh <aws-account-id> <region>
# Example: ./scripts/build-and-push.sh 123456789012 eu-west-2
###############################################################################
set -euo pipefail

ACCOUNT_ID="${1:?Usage: $0 <aws-account-id> <region>}"
REGION="${2:-eu-west-2}"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
PROJECT="zero-trust-k8s"

SERVICES=("frontend" "api-gateway" "orders" "auth" "database")

echo "Authenticating with ECR..."
aws ecr get-login-password --region "${REGION}" | \
  docker login --username AWS --password-stdin "${REGISTRY}"

for SERVICE in "${SERVICES[@]}"; do
  REPO="${PROJECT}/${SERVICE}"
  IMAGE="${REGISTRY}/${REPO}:latest"

  echo ""
  echo "=== Building ${SERVICE} ==="

  # Create ECR repository if it doesn't exist
  aws ecr describe-repositories --repository-names "${REPO}" --region "${REGION}" 2>/dev/null || \
    aws ecr create-repository \
      --repository-name "${REPO}" \
      --region "${REGION}" \
      --image-scanning-configuration scanOnPush=true \
      --encryption-configuration encryptionType=AES256

  docker build -t "${IMAGE}" "./app/${SERVICE}"
  docker push "${IMAGE}"

  echo "Pushed ${IMAGE}"
done

echo ""
echo "All images built and pushed."
echo ""
echo "Update k8s manifests with:"
echo "  sed -i 's|image: ${SERVICE}:latest|image: ${REGISTRY}/${PROJECT}/${SERVICE}:latest|g' k8s/deployments/*.yaml"
