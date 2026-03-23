#!/usr/bin/env bash
###############################################################################
# Zero Trust Policy Validation
#
# Tests that Cilium network policies are correctly enforcing micro-segmentation.
# Runs from within the cluster using temporary curl pods to simulate traffic
# from each service's identity.
#
# Expected results:
#   - Allowed paths return HTTP 200
#   - Denied paths are dropped by Cilium (connection timeout/refused)
#
# Usage: ./scripts/test-policies.sh
###############################################################################
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

test_connection() {
  local description="$1"
  local namespace="$2"
  local sa="$3"
  local url="$4"
  local method="${5:-GET}"
  local expect="${6:-allow}"

  echo -n "  Testing: ${description}... "

  local result
  if [ "${method}" = "POST" ]; then
    result=$(kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
      --namespace="${namespace}" \
      --overrides="{\"spec\":{\"serviceAccountName\":\"${sa}\"}}" \
      --timeout=15s \
      -- curl -s -o /dev/null -w "%{http_code}" -X POST \
         -H "Content-Type: application/json" \
         -d '{}' \
         --connect-timeout 5 --max-time 10 \
         "${url}" 2>/dev/null) || result="000"
  else
    result=$(kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
      --namespace="${namespace}" \
      --overrides="{\"spec\":{\"serviceAccountName\":\"${sa}\"}}" \
      --timeout=15s \
      -- curl -s -o /dev/null -w "%{http_code}" \
         --connect-timeout 5 --max-time 10 \
         "${url}" 2>/dev/null) || result="000"
  fi

  if [ "${expect}" = "allow" ] && [ "${result}" != "000" ]; then
    echo -e "${GREEN}PASS${NC} (HTTP ${result})"
    ((PASS++))
  elif [ "${expect}" = "deny" ] && [ "${result}" = "000" ]; then
    echo -e "${GREEN}PASS${NC} (blocked)"
    ((PASS++))
  else
    echo -e "${RED}FAIL${NC} (expected ${expect}, got HTTP ${result})"
    ((FAIL++))
  fi
}

echo "============================================================"
echo "  Zero Trust Policy Validation Suite"
echo "============================================================"
echo ""

# --- Allowed traffic ---
echo -e "${YELLOW}Allowed traffic (should succeed):${NC}"

test_connection "frontend → api-gateway GET /api/orders" \
  "frontend" "frontend" \
  "http://api-gateway.backend.svc.cluster.local:3000/api/orders" \
  "GET" "allow"

test_connection "api-gateway → orders GET /orders" \
  "backend" "api-gateway" \
  "http://orders.backend.svc.cluster.local:3000/orders" \
  "GET" "allow"

test_connection "api-gateway → auth GET /verify" \
  "backend" "api-gateway" \
  "http://auth.backend.svc.cluster.local:3000/verify" \
  "GET" "allow"

test_connection "orders → database GET /query?table=orders" \
  "backend" "orders" \
  "http://database.data.svc.cluster.local:3000/query?table=orders" \
  "GET" "allow"

test_connection "auth → database GET /query?table=users" \
  "backend" "auth" \
  "http://database.data.svc.cluster.local:3000/query?table=users" \
  "GET" "allow"

echo ""

# --- Denied traffic (lateral movement attempts) ---
echo -e "${YELLOW}Denied traffic (should be blocked):${NC}"

test_connection "frontend → database DIRECT (bypass api-gateway)" \
  "frontend" "frontend" \
  "http://database.data.svc.cluster.local:3000/query?table=orders" \
  "GET" "deny"

test_connection "frontend → orders DIRECT (bypass api-gateway)" \
  "frontend" "frontend" \
  "http://orders.backend.svc.cluster.local:3000/orders" \
  "GET" "deny"

test_connection "auth → orders (lateral movement)" \
  "backend" "auth" \
  "http://orders.backend.svc.cluster.local:3000/orders" \
  "GET" "deny"

test_connection "orders → auth (lateral movement)" \
  "backend" "orders" \
  "http://auth.backend.svc.cluster.local:3000/verify" \
  "GET" "deny"

test_connection "auth → database POST /mutate (read-only service writing)" \
  "backend" "auth" \
  "http://database.data.svc.cluster.local:3000/mutate" \
  "POST" "deny"

test_connection "orders → database GET /query?table=users (wrong table)" \
  "backend" "orders" \
  "http://database.data.svc.cluster.local:3000/query?table=users" \
  "GET" "deny"

echo ""
echo "============================================================"
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "============================================================"

if [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
