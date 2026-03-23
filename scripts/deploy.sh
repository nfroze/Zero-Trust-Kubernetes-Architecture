#!/usr/bin/env bash
###############################################################################
# Deploy the zero trust demo application to the EKS cluster
#
# Prerequisites:
#   - kubectl configured for the target cluster
#   - Cilium installed and healthy
#   - Container images pushed to ECR (run build-and-push.sh first)
#
# Usage: ./scripts/deploy.sh
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

echo "=== Deploying Zero Trust Demo Application ==="
echo ""

# Step 1: Create namespaces
echo "Creating namespaces..."
kubectl apply -f "${PROJECT_DIR}/k8s/namespaces/"

# Step 2: Deploy services
echo "Deploying services..."
kubectl apply -f "${PROJECT_DIR}/k8s/deployments/"

# Step 3: Wait for rollouts
echo ""
echo "Waiting for deployments to be ready..."
kubectl rollout status deployment/frontend -n frontend --timeout=120s
kubectl rollout status deployment/api-gateway -n backend --timeout=120s
kubectl rollout status deployment/orders -n backend --timeout=120s
kubectl rollout status deployment/auth -n backend --timeout=120s
kubectl rollout status deployment/database -n data --timeout=120s

# Step 4: Apply network policies (if they exist)
if [ -d "${PROJECT_DIR}/k8s/policies" ]; then
  echo ""
  echo "Applying Cilium network policies..."
  kubectl apply -f "${PROJECT_DIR}/k8s/policies/"
fi

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Verify with:"
echo "  kubectl get pods -A -l app.kubernetes.io/part-of=zero-trust-demo"
echo "  cilium status"
echo "  hubble observe --namespace backend"
