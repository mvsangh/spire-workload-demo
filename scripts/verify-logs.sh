#!/bin/bash

# verify-logs.sh
# Standalone script for verifying structured logging output (SC-010)
# This script helps demo presenters verify mTLS handshakes and SPIFFE ID validation

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "==========================================="
echo "SPIRE/SPIFFE Demo - Log Verification"
echo "==========================================="
echo ""

# Function to check if jq is available
check_jq() {
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}⚠ jq not found. Log parsing will be limited.${NC}"
        return 1
    fi
    return 0
}

HAS_JQ=false
if check_jq; then
    HAS_JQ=true
fi

# Verify Pattern 1 logs (Envoy SDS)
verify_pattern1_logs() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Pattern 1: Envoy SDS (Frontend ↔ Backend)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Check frontend logs
    echo -e "${CYAN}→ Frontend logs (Pattern 1):${NC}"
    FRONTEND_LOGS=$(kubectl logs -n demo -l app=frontend -c frontend --tail=50 2>/dev/null | grep '"pattern":"envoy-sds"' || echo "")

    if [ -n "$FRONTEND_LOGS" ]; then
        if [ "$HAS_JQ" = true ]; then
            echo "$FRONTEND_LOGS" | while IFS= read -r line; do
                EVENT=$(echo "$line" | jq -r '.event' 2>/dev/null || echo "")
                MSG=$(echo "$line" | jq -r '.msg' 2>/dev/null || echo "")
                SPIFFE_ID=$(echo "$line" | jq -r '.spiffe_id' 2>/dev/null || echo "")
                PEER_ID=$(echo "$line" | jq -r '.peer_spiffe_id' 2>/dev/null || echo "")

                case "$EVENT" in
                    connection_attempt)
                        echo -e "  ${YELLOW}⏳ $MSG${NC}"
                        echo -e "     SPIFFE ID: $SPIFFE_ID"
                        ;;
                    connection_success)
                        echo -e "  ${GREEN}✓ $MSG${NC}"
                        echo -e "     Self:  $SPIFFE_ID"
                        echo -e "     Peer:  $PEER_ID"
                        ;;
                    connection_failure)
                        echo -e "  ${RED}✗ $MSG${NC}"
                        ;;
                esac
            done
        else
            echo "$FRONTEND_LOGS" | head -5
        fi
        echo -e "${GREEN}✓ Found Pattern 1 logs in frontend${NC}"
    else
        echo -e "${RED}✗ No Pattern 1 logs found in frontend${NC}"
    fi

    echo ""

    # Check backend logs for Pattern 1
    echo -e "${CYAN}→ Backend logs (Pattern 1):${NC}"
    BACKEND_P1_LOGS=$(kubectl logs -n demo -l app=backend -c backend --tail=50 2>/dev/null | grep '"pattern":"envoy-sds"' || echo "")

    if [ -n "$BACKEND_P1_LOGS" ]; then
        if [ "$HAS_JQ" = true ]; then
            echo "$BACKEND_P1_LOGS" | while IFS= read -r line; do
                EVENT=$(echo "$line" | jq -r '.event' 2>/dev/null || echo "")
                MSG=$(echo "$line" | jq -r '.msg' 2>/dev/null || echo "")
                SPIFFE_ID=$(echo "$line" | jq -r '.spiffe_id' 2>/dev/null || echo "")
                PEER_ID=$(echo "$line" | jq -r '.peer_spiffe_id' 2>/dev/null || echo "")

                if [ "$EVENT" = "connection_success" ]; then
                    echo -e "  ${GREEN}✓ $MSG${NC}"
                    echo -e "     Self:  $SPIFFE_ID"
                    echo -e "     Peer:  $PEER_ID"
                fi
            done
        else
            echo "$BACKEND_P1_LOGS" | head -5
        fi
        echo -e "${GREEN}✓ Found Pattern 1 logs in backend${NC}"
    else
        echo -e "${RED}✗ No Pattern 1 logs found in backend${NC}"
    fi

    echo ""

    # Check Envoy logs for SPIFFE ID validation
    echo -e "${CYAN}→ Frontend Envoy (SDS):${NC}"
    ENVOY_ERRORS=$(kubectl logs -n demo -l app=frontend -c envoy --tail=30 2>/dev/null | grep -i "error\|warning\|not authorized" | grep -v "deprecated\|limit" || echo "")

    if [ -z "$ENVOY_ERRORS" ]; then
        echo -e "${GREEN}✓ No SDS errors in frontend Envoy${NC}"
    else
        echo -e "${YELLOW}⚠ Found warnings/errors:${NC}"
        echo "$ENVOY_ERRORS" | head -3
    fi

    echo ""
}

# Verify Pattern 2 logs (spiffe-helper)
verify_pattern2_logs() {
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}Pattern 2: spiffe-helper (Backend ↔ DB)${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Check backend logs for Pattern 2
    echo -e "${CYAN}→ Backend logs (Pattern 2):${NC}"
    BACKEND_P2_LOGS=$(kubectl logs -n demo -l app=backend -c backend --tail=50 2>/dev/null | grep '"pattern":"spiffe-helper"' || echo "")

    if [ -n "$BACKEND_P2_LOGS" ]; then
        if [ "$HAS_JQ" = true ]; then
            echo "$BACKEND_P2_LOGS" | while IFS= read -r line; do
                EVENT=$(echo "$line" | jq -r '.event' 2>/dev/null || echo "")
                MSG=$(echo "$line" | jq -r '.msg' 2>/dev/null || echo "")
                SPIFFE_ID=$(echo "$line" | jq -r '.spiffe_id' 2>/dev/null || echo "")
                PEER_ID=$(echo "$line" | jq -r '.peer_spiffe_id' 2>/dev/null || echo "")

                if [ "$EVENT" = "connection_success" ]; then
                    echo -e "  ${GREEN}✓ $MSG${NC}"
                    echo -e "     Self:  $SPIFFE_ID"
                    echo -e "     Peer:  $PEER_ID"
                fi
            done
        else
            echo "$BACKEND_P2_LOGS" | head -5
        fi
        echo -e "${GREEN}✓ Found Pattern 2 logs in backend${NC}"
    else
        echo -e "${RED}✗ No Pattern 2 logs found in backend${NC}"
    fi

    echo ""

    # Check spiffe-helper logs
    echo -e "${CYAN}→ Backend spiffe-helper:${NC}"
    SPIFFE_HELPER_LOGS=$(kubectl logs -n demo -l app=backend -c spiffe-helper --tail=20 2>/dev/null || echo "")

    if echo "$SPIFFE_HELPER_LOGS" | grep -q "SVID\|certificate" 2>/dev/null; then
        echo -e "${GREEN}✓ spiffe-helper is writing certificates${NC}"
        echo "$SPIFFE_HELPER_LOGS" | grep -i "wrote\|updated\|certificate" | tail -3 || echo "  (certificate updates detected)"
    else
        echo -e "${YELLOW}⚠ No certificate update logs found${NC}"
    fi

    echo ""

    # Check PostgreSQL SSL logs
    echo -e "${CYAN}→ PostgreSQL SSL verification:${NC}"
    PG_SSL=$(kubectl exec -n demo postgres-0 -c postgres -- psql -U demouser -d demo -t -c "SHOW ssl;" 2>/dev/null | tr -d ' ' || echo "unknown")

    if [ "$PG_SSL" = "on" ]; then
        echo -e "${GREEN}✓ PostgreSQL SSL is enabled${NC}"
    else
        echo -e "${RED}✗ PostgreSQL SSL status: $PG_SSL${NC}"
    fi

    echo ""
}

# Check for certificate rotation events
check_cert_rotation() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Certificate Rotation Events${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    echo -e "${CYAN}→ Checking for rotation events...${NC}"

    # Check for cert_rotation events
    ROTATION_EVENTS=$(kubectl logs -n demo --all-containers --tail=100 2>/dev/null | grep '"event":"cert_rotation"' || echo "")

    if [ -n "$ROTATION_EVENTS" ]; then
        echo -e "${GREEN}✓ Found certificate rotation events${NC}"
        if [ "$HAS_JQ" = true ]; then
            echo "$ROTATION_EVENTS" | head -3 | jq -r '.msg' 2>/dev/null || echo "$ROTATION_EVENTS" | head -3
        else
            echo "$ROTATION_EVENTS" | head -3
        fi
    else
        echo -e "${YELLOW}⚠ No rotation events detected yet${NC}"
        echo "  (Rotation events occur when SVIDs are refreshed)"
    fi

    echo ""
}

# Summary
print_summary() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Verification Summary${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Count log entries by checking individual containers
    P1_FRONTEND=$(kubectl logs -n demo -l app=frontend -c frontend --tail=100 2>/dev/null | grep '"pattern":"envoy-sds"' | wc -l || echo "0")
    P1_BACKEND=$(kubectl logs -n demo -l app=backend -c backend --tail=100 2>/dev/null | grep '"pattern":"envoy-sds"' | wc -l || echo "0")
    P1_COUNT=$((P1_FRONTEND + P1_BACKEND))

    P2_COUNT=$(kubectl logs -n demo -l app=backend -c backend --tail=100 2>/dev/null | grep '"pattern":"spiffe-helper"' | wc -l || echo "0")

    echo "Log entries found (last 200 lines):"
    echo "  • Pattern 1 (envoy-sds):     $P1_COUNT events"
    echo "  • Pattern 2 (spiffe-helper): $P2_COUNT events"
    echo ""

    if [ "$P1_COUNT" -gt 0 ] && [ "$P2_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ All expected log patterns found${NC}"
        echo -e "${GREEN}✓ Demo observability requirements met (SC-010)${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Some pattern logs missing${NC}"
        echo "  Try triggering the demo: curl http://localhost:8080/api/demo"
        return 1
    fi
}

# Main execution
main() {
    verify_pattern1_logs
    verify_pattern2_logs
    check_cert_rotation
    print_summary
    EXIT_CODE=$?

    echo ""
    echo "Tips for demo presentations:"
    echo "  • Pattern 1 logs show Envoy SDS mTLS validation"
    echo "  • Pattern 2 logs show client certificate authentication"
    echo "  • SPIFFE IDs in logs prove workload identity"
    echo "  • Correlation IDs help trace requests end-to-end"
    echo ""
    echo "To watch logs in real-time:"
    echo "  kubectl logs -n demo -l app=frontend -c frontend -f --tail=10"
    echo "  kubectl logs -n demo -l app=backend -c backend -f --tail=10"
    echo ""

    exit $EXIT_CODE
}

main "$@"
