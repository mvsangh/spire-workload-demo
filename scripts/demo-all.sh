#!/bin/bash

set -e

# demo-all.sh
# One-command setup for complete SPIRE/SPIFFE demo
# This script orchestrates the full deployment from scratch

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "==========================================="
echo "SPIRE/SPIFFE Production Demo - Full Setup"
echo "==========================================="
echo ""
echo "This script will:"
echo "  1. Create kind cluster"
echo "  2. Deploy SPIRE server"
echo "  3. Deploy SPIRE agent"
echo "  4. Deploy demo applications"
echo "  5. Register SPIRE entries"
echo "  6. Run end-to-end verification"
echo ""
echo -e "${YELLOW}Prerequisites:${NC}"
echo "  • Docker (or Podman with Docker CLI)"
echo "  • kubectl"
echo "  • kind"
echo "  • Go 1.21+"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}→ Checking prerequisites...${NC}"

    local missing=()

    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    fi

    if ! command -v kubectl &> /dev/null; then
        missing+=("kubectl")
    fi

    if ! command -v kind &> /dev/null; then
        missing+=("kind")
    fi

    if ! command -v go &> /dev/null; then
        missing+=("go")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}✗ Missing prerequisites: ${missing[*]}${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ All prerequisites found${NC}"
    echo ""
}

# Execute step with error handling
run_step() {
    local step_num=$1
    local step_name=$2
    local script=$3

    echo "==========================================="
    echo -e "${BLUE}Step $step_num: $step_name${NC}"
    echo "==========================================="
    echo ""

    if [ -f "$SCRIPT_DIR/$script" ]; then
        if bash "$SCRIPT_DIR/$script"; then
            echo ""
            echo -e "${GREEN}✓ Step $step_num complete${NC}"
            echo ""
        else
            echo ""
            echo -e "${RED}✗ Step $step_num failed${NC}"
            echo "Script: $script"
            exit 1
        fi
    else
        echo -e "${RED}✗ Script not found: $script${NC}"
        exit 1
    fi
}

# Main execution
main() {
    check_prerequisites

    # Record start time
    START_TIME=$(date +%s)

    # Step 1: Create kind cluster
    run_step "1" "Create kind cluster" "01-create-cluster.sh"

    # Step 2: Deploy SPIRE server
    run_step "2" "Deploy SPIRE server" "02-deploy-spire-server.sh"

    # Step 3: Deploy SPIRE agent
    run_step "3" "Deploy SPIRE agent" "03-deploy-spire-agent.sh"

    # Step 4: Deploy applications
    run_step "4" "Deploy demo applications" "04-deploy-apps.sh"

    # Step 5: Register SPIRE entries
    run_step "5" "Register SPIRE entries" "05-register-entries.sh"

    # Wait a moment for pods to restart with new SPIRE entries
    echo "==========================================="
    echo -e "${BLUE}Waiting for pods to sync with SPIRE...${NC}"
    echo "==========================================="
    echo ""
    sleep 10

    # Restart pods to ensure they get SVIDs
    echo "→ Restarting backend to fetch SVID..."
    kubectl rollout restart deployment backend -n demo &> /dev/null
    kubectl rollout status deployment backend -n demo --timeout=120s &> /dev/null
    echo -e "${GREEN}✓ Backend restarted${NC}"

    echo "→ Restarting frontend to fetch SVID..."
    kubectl rollout restart deployment frontend -n demo &> /dev/null
    kubectl rollout status deployment frontend -n demo --timeout=120s &> /dev/null
    echo -e "${GREEN}✓ Frontend restarted${NC}"

    echo ""
    sleep 5

    # Step 6: End-to-end verification
    echo "==========================================="
    echo -e "${BLUE}Step 6: End-to-end verification${NC}"
    echo "==========================================="
    echo ""

    # Test health endpoint
    echo "→ Testing frontend health..."
    if curl -s -f http://localhost:8080/health &> /dev/null; then
        echo -e "${GREEN}✓ Frontend health check passed${NC}"
    else
        echo -e "${RED}✗ Frontend health check failed${NC}"
        exit 1
    fi

    # Test demo endpoint
    echo "→ Testing full demo flow..."
    DEMO_RESULT=$(curl -s http://localhost:8080/api/demo)

    # Parse results
    PATTERN1_SUCCESS=$(echo "$DEMO_RESULT" | jq -r '.frontend_to_backend.success' 2>/dev/null || echo "false")
    PATTERN2_SUCCESS=$(echo "$DEMO_RESULT" | jq -r '.backend_to_database.success' 2>/dev/null || echo "false")
    ORDER_COUNT=$(echo "$DEMO_RESULT" | jq -r '.orders | length' 2>/dev/null || echo "0")

    echo ""
    echo "Results:"
    if [ "$PATTERN1_SUCCESS" = "true" ]; then
        echo -e "  ${GREEN}✓ Pattern 1 (Envoy SDS): Frontend → Backend${NC}"
    else
        echo -e "  ${RED}✗ Pattern 1 (Envoy SDS): FAILED${NC}"
    fi

    if [ "$PATTERN2_SUCCESS" = "true" ]; then
        echo -e "  ${GREEN}✓ Pattern 2 (spiffe-helper): Backend → PostgreSQL${NC}"
    else
        echo -e "  ${RED}✗ Pattern 2 (spiffe-helper): FAILED${NC}"
    fi

    if [ "$ORDER_COUNT" -gt 0 ]; then
        echo -e "  ${GREEN}✓ Retrieved $ORDER_COUNT orders from database${NC}"
    else
        echo -e "  ${RED}✗ No orders retrieved${NC}"
    fi

    echo ""

    # Check if all tests passed
    if [ "$PATTERN1_SUCCESS" = "true" ] && [ "$PATTERN2_SUCCESS" = "true" ] && [ "$ORDER_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ End-to-end verification passed${NC}"
    else
        echo -e "${RED}✗ End-to-end verification failed${NC}"
        echo ""
        echo "Debug information:"
        echo "Full response:"
        echo "$DEMO_RESULT" | jq . || echo "$DEMO_RESULT"
        exit 1
    fi

    # Calculate elapsed time
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    MINUTES=$((ELAPSED / 60))
    SECONDS=$((ELAPSED % 60))

    # Print success summary
    echo ""
    echo "==========================================="
    echo -e "${GREEN}✓ Demo Setup Complete!${NC}"
    echo "==========================================="
    echo ""
    echo "Time elapsed: ${MINUTES}m ${SECONDS}s"
    echo ""
    echo "Components deployed:"
    echo "  ✓ SPIRE Server & Agent"
    echo "  ✓ PostgreSQL (Pattern 2: spiffe-helper)"
    echo "  ✓ Backend (Pattern 1 + Pattern 2)"
    echo "  ✓ Frontend (Pattern 1: Envoy SDS)"
    echo ""
    echo "SPIFFE Integration Patterns:"
    echo "  ✓ Pattern 1: Envoy SDS (service-to-service)"
    echo "  ✓ Pattern 2: spiffe-helper (app-to-database)"
    echo ""
    echo -e "${GREEN}🌐 Demo UI: http://localhost:8080${NC}"
    echo ""
    echo "Quick commands:"
    echo "  • View pods:    kubectl get pods -n demo"
    echo "  • Check logs:   kubectl logs -n demo -l app=frontend -c frontend"
    echo "  • Test API:     curl http://localhost:8080/api/demo | jq ."
    echo "  • Cleanup:      ./scripts/cleanup.sh"
    echo ""
    echo "Next steps:"
    echo "  1. Open http://localhost:8080 in your browser"
    echo "  2. Click 'Run Demo' to see both patterns in action"
    echo "  3. Check structured logs for pattern identifiers"
    echo ""
}

main "$@"
