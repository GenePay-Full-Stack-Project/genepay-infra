#!/bin/bash

# =============================================================================
# GenePay Payment Service - API Endpoint Test Suite
# Base: http://api.genepay.local/api/v1
# =============================================================================

set -euo pipefail

BASE_URL="http://api.genepay.local/api/v1"
ADMIN_EMAIL="sysadmin@genepay.com"
ADMIN_PASSWORD="admin123"

# ---------------------------------------------------------------------------
# Counters & result tracking
# ---------------------------------------------------------------------------
PASS=0
FAIL=0
SKIP=0
RESULTS=()

# ---------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log_section() {
  echo ""
  echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${RESET}"
  echo -e "${CYAN}${BOLD}  $1${RESET}"
  echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${RESET}"
}

# test_endpoint <label> <expected_http_code> <method> <path> [extra_curl_args...]
test_endpoint() {
  local LABEL="$1"
  local EXPECTED="$2"
  local METHOD="$3"
  local ENDPOINT_PATH="$4"
  shift 4
  local EXTRA=("$@")

  local URL="${BASE_URL}${ENDPOINT_PATH}"
  local RESPONSE
  local HTTP_CODE

  HTTP_CODE=$(curl -s -o /tmp/genepay_resp.json -w "%{http_code}" \
    -X "$METHOD" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    "${EXTRA[@]}" \
    "$URL" 2>/dev/null || echo "000")

  local BODY
  BODY=$(cat /tmp/genepay_resp.json 2>/dev/null || echo "")

  # A test passes if:
  #   - HTTP code matches expected, OR
  #   - HTTP code is 200/201 when any 2xx is acceptable, OR
  #   - We accept a range (e.g. auth endpoints returning 400/401 for bad creds is still "reachable")
  local STATUS
  if [[ "$HTTP_CODE" == "000" ]]; then
    STATUS="UNREACHABLE"
    FAIL=$((FAIL + 1))
  elif [[ "$HTTP_CODE" == "$EXPECTED" ]]; then
    STATUS="PASS"
    PASS=$((PASS + 1))
  else
    # Accept any 2xx if expected was 200/201
    if [[ "$HTTP_CODE" =~ ^2 ]] && [[ "$EXPECTED" =~ ^2 ]]; then
      STATUS="PASS"
      PASS=$((PASS + 1))
    # Accept 401/403 on auth-required endpoints (service is reachable and rejecting unauth)
    elif [[ "$HTTP_CODE" == "401" || "$HTTP_CODE" == "403" ]] && [[ "$EXPECTED" == "AUTH" ]]; then
      STATUS="PASS(unauth)"
      PASS=$((PASS + 1))
    else
      STATUS="FAIL(got ${HTTP_CODE})"
      FAIL=$((FAIL + 1))
    fi
  fi

  # Pad label
  printf "  %-55s" "$LABEL"

  case "$STATUS" in
    PASS*)         echo -e "  ${GREEN}[${STATUS}]${RESET}" ;;
    FAIL*|UNREACHABLE) echo -e "  ${RED}[${STATUS}]${RESET}" ;;
    *)             echo -e "  ${YELLOW}[${STATUS}]${RESET}" ;;
  esac

  RESULTS+=("${STATUS}|${METHOD}|${PATH}|${HTTP_CODE}|${LABEL}")
}

# Shorthand: authenticated GET
auth_get() {
  test_endpoint "$1" "200" "GET" "$2" -H "Authorization: Bearer ${ADMIN_TOKEN}"
}

# Shorthand: authenticated POST with body
auth_post() {
  test_endpoint "$1" "$2" "POST" "$3" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -d "$4"
}

# =============================================================================
# STEP 0 — Basic connectivity check
# =============================================================================
log_section "0) Connectivity Check"

echo -e "  Target: ${BASE_URL}"
if ! curl -s --max-time 5 -o /dev/null "${BASE_URL}/health" 2>/dev/null; then
  echo -e "  ${RED}ERROR: Cannot reach ${BASE_URL} — is the cluster up? Aborting.${RESET}"
  exit 1
fi
echo -e "  ${GREEN}Cluster reachable.${RESET}"

# =============================================================================
# STEP 1 — Unauthenticated / Public endpoints
# =============================================================================
log_section "1) Health & Actuator (no auth)"

test_endpoint "GET /health"                   "200" "GET"  "/health"
test_endpoint "GET /actuator"                 "200" "GET"  "/actuator"
test_endpoint "GET /actuator/health"          "200" "GET"  "/actuator/health"
test_endpoint "GET /actuator/info"            "200" "GET"  "/actuator/info"
test_endpoint "GET /actuator/metrics"         "200" "GET"  "/actuator/metrics"

# =============================================================================
# STEP 2 — Admin login (obtain JWT)
# =============================================================================
log_section "2) Admin Authentication"

echo -e "  Attempting login as ${ADMIN_EMAIL}..."

LOGIN_RESPONSE=$(curl -s -X POST "${BASE_URL}/admin/login" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}" 2>/dev/null || echo "{}")

HTTP_LOGIN=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/admin/login" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}" 2>/dev/null || echo "000")

ADMIN_TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | head -1 | cut -d'"' -f4 || true)

if [[ -z "$ADMIN_TOKEN" || "$HTTP_LOGIN" != "200" ]]; then
  echo -e "  ${RED}FAIL — Admin login returned HTTP ${HTTP_LOGIN}. Token not obtained.${RESET}"
  echo -e "  Response: ${LOGIN_RESPONSE}"
  echo -e "  ${YELLOW}All authenticated tests will be skipped.${RESET}"
  ADMIN_TOKEN="INVALID_TOKEN_PLACEHOLDER"
  FAIL=$((FAIL + 1))
else
  echo -e "  ${GREEN}PASS — Token obtained: ${ADMIN_TOKEN:0:40}...${RESET}"
  PASS=$((PASS + 1))
fi
RESULTS+=("LOGIN|POST|/admin/login|${HTTP_LOGIN}|Admin login")

# =============================================================================
# STEP 3 — Admin endpoints (authenticated)
# =============================================================================
log_section "3) Admin Endpoints"

auth_get  "GET /admin/dashboard"                  "/admin/dashboard"
auth_get  "GET /admin/users"                      "/admin/users"
auth_get  "GET /admin/merchants"                  "/admin/merchants"
auth_get  "GET /admin/transactions"               "/admin/transactions"
auth_get  "GET /admin/:adminId (id=1)"            "/admin/1"

# =============================================================================
# STEP 4 — Merchant auth flows (public — expect 400/401 for dummy data, not 500)
# =============================================================================
log_section "4) Merchant Auth Flows"

test_endpoint "POST /merchants/send-verification-code" "200" "POST" \
  "/merchants/send-verification-code" \
  -d '{"email":"test@example.com"}'

test_endpoint "POST /merchants/verify-email (bad code)" "400" "POST" \
  "/merchants/verify-email" \
  -d '{"email":"test@example.com","verificationCode":"000000"}'

test_endpoint "POST /merchants/login (bad creds)" "401" "POST" \
  "/merchants/login" \
  -d '{"email":"nobody@example.com","password":"wrongpassword"}'

test_endpoint "POST /merchants/google-signin (bad token)" "400" "POST" \
  "/merchants/google-signin" \
  -d '{"idToken":"invalid_token"}'

test_endpoint "POST /merchants/refresh-token (bad token)" "401" "POST" \
  "/merchants/refresh-token" \
  -d '{"refreshToken":"invalid_refresh_token"}'

test_endpoint "POST /merchants/verify-token (bad token)"  "400" "POST" \
  "/merchants/verify-token" \
  -d '{"token":"invalid_token"}'

# Merchant read/update — expect 404 for non-existent ID, not 500
test_endpoint "GET /merchants/:merchantId (id=999999)"  "404" "GET" \
  "/merchants/999999" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"

test_endpoint "PUT /merchants/:merchantId (id=999999)"  "404" "PUT" \
  "/merchants/999999" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -d '{"businessName":"Test Corp"}'

# =============================================================================
# STEP 5 — User auth flows
# =============================================================================
log_section "5) User Auth Flows"

test_endpoint "POST /users/send-verification-code"      "200" "POST" \
  "/users/send-verification-code" \
  -d '{"email":"testuser@example.com"}'

test_endpoint "POST /users/verify-email (bad code)"     "400" "POST" \
  "/users/verify-email" \
  -d '{"email":"testuser@example.com","verificationCode":"000000"}'

test_endpoint "POST /users/login (bad creds)"           "401" "POST" \
  "/users/login" \
  -d '{"nicNumber":"000000000V","password":"wrongpassword"}'

test_endpoint "POST /users/google-signin (bad token)"   "400" "POST" \
  "/users/google-signin" \
  -d '{"idToken":"invalid_token"}'

# =============================================================================
# STEP 6 — Card endpoints (authenticated)
# =============================================================================
log_section "6) Card Endpoints"

auth_get "GET /cards/user/:userId (id=1)"               "/cards/user/1"
auth_get "GET /cards/user/:userId/default (id=1)"       "/cards/user/1/default"

test_endpoint "POST /cards/user/:userId (bad card)"     "400" "POST" \
  "/cards/user/1" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -d '{"cardNumber":"0000000000000000","cvv":"000","expiry":"01/00","setAsDefault":false}'

test_endpoint "PUT /cards/user/:userId/:cardId/set-default" "404" "PUT" \
  "/cards/user/1/999999/set-default" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"

test_endpoint "DELETE /cards/user/:userId/:cardId (id=1/999999)" "404" "DELETE" \
  "/cards/user/1/999999" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"

auth_get "GET /cards/merchant/:merchantId (id=1)"           "/cards/merchant/1"
auth_get "GET /cards/merchant/:merchantId/default (id=1)"   "/cards/merchant/1/default"

test_endpoint "PUT /cards/merchant/:merchantId/:cardId/set-default" "404" "PUT" \
  "/cards/merchant/1/999999/set-default" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"

test_endpoint "DELETE /cards/merchant/:merchantId/:cardId (id=1/999999)" "404" "DELETE" \
  "/cards/merchant/1/999999" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"

# =============================================================================
# STEP 7 — Payment endpoints
# =============================================================================
log_section "7) Payment Endpoints"

# Initiate — expect 400 for invalid merchant/amount
test_endpoint "POST /payments/initiate (bad merchant)"   "400" "POST" \
  "/payments/initiate" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -d '{"amount":100.00,"merchantId":999999,"currency":"LKR","description":"test"}'

# Verify — expect 400/401 for invalid transaction
test_endpoint "POST /payments/verify (bad txn)"          "400" "POST" \
  "/payments/verify" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -d '{"faceData":"invalid","transactionId":"non-existent-txn-id"}'

# Identify user — expect 400/404 for no face data
test_endpoint "POST /payments/identify-user (bad data)"  "400" "POST" \
  "/payments/identify-user" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -d '{"key_0":"invalid_face_data"}'

# Get transaction — expect 404 for non-existent ID
test_endpoint "GET /payments/:transactionId (fake id)"   "404" "GET" \
  "/payments/non-existent-transaction-id-000" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"

# Refund — expect 404 for non-existent transaction
test_endpoint "POST /payments/:transactionId/refund"     "404" "POST" \
  "/payments/non-existent-transaction-id-000/refund?reason=test" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"

# User transactions
auth_get "GET /payments/user/:userId (id=1)"             "/payments/user/1?page=0&size=5"
auth_get "GET /payments/user/:userId/total-spends (id=1)" "/payments/user/1/total-spends"

# Merchant transactions
auth_get "GET /payments/merchant/:merchantId (id=1)"     "/payments/merchant/1?page=0&size=5"

# Blockchain sub-routes
auth_get "GET /payments/blockchain/health"               "/payments/blockchain/health"
auth_get "GET /payments/blockchain/stats"                "/payments/blockchain/stats"

# =============================================================================
# STEP 8 — Platform endpoints
# =============================================================================
log_section "8) Platform Endpoints"

auth_get "GET /platform/balance"                         "/platform/balance"
auth_get "GET /platform/fees/summary"                    "/platform/fees/summary"
auth_get "GET /platform/transactions/statistics"         "/platform/transactions/statistics?period=all"

# =============================================================================
# STEP 9 — Summary Report
# =============================================================================
log_section "9) Test Summary"

TOTAL=$((PASS + FAIL + SKIP))

echo ""
echo -e "  Total tests  : ${BOLD}${TOTAL}${RESET}"
echo -e "  ${GREEN}Passed       : ${PASS}${RESET}"
echo -e "  ${RED}Failed       : ${FAIL}${RESET}"
if [[ $SKIP -gt 0 ]]; then
  echo -e "  ${YELLOW}Skipped      : ${SKIP}${RESET}"
fi
echo ""

# Print failed tests only
if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}${BOLD}  Failed / Unreachable endpoints:${RESET}"
  for RESULT in "${RESULTS[@]}"; do
    STATUS=$(echo "$RESULT" | cut -d'|' -f1)
    METHOD=$(echo "$RESULT" | cut -d'|' -f2)
    PATH_=$(echo "$RESULT" | cut -d'|' -f3)
    CODE=$(echo  "$RESULT" | cut -d'|' -f4)
    LABEL=$(echo "$RESULT" | cut -d'|' -f5)
    if [[ "$STATUS" == FAIL* || "$STATUS" == "UNREACHABLE" ]]; then
      echo -e "  ${RED}  ✗ [${CODE}] ${METHOD} ${PATH_} — ${LABEL}${RESET}"
    fi
  done
  echo ""
fi

# Exit code reflects overall result
if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}${BOLD}  ✗ Some tests failed.${RESET}"
  exit 1
else
  echo -e "${GREEN}${BOLD}  ✓ All tests passed.${RESET}"
  exit 0
fi
