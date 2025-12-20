#!/bin/bash

set -e

echo "=========================================="
echo "SPIRE Registration Entry Creation"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get the SPIRE agent SPIFFE ID
echo "Step 1: Getting SPIRE agent SPIFFE ID..."
AGENT_SPIFFE_ID=$(kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server agent list 2>/dev/null | \
  grep "SPIFFE ID" | awk '{print $4}')

if [ -z "$AGENT_SPIFFE_ID" ]; then
  echo -e "${RED}✗ Failed to get SPIRE agent SPIFFE ID${NC}"
  echo "  Make sure SPIRE agent is running and attested"
  exit 1
fi

echo -e "${GREEN}✓ Agent SPIFFE ID: $AGENT_SPIFFE_ID${NC}"
echo ""

# Function to create or update a registration entry
create_entry() {
  local spiffe_id=$1
  local selectors=$2
  local dns_name=$3
  local description=$4

  echo "Creating entry for: $description"
  echo "  SPIFFE ID: $spiffe_id"
  echo "  DNS: $dns_name"

  # Check if entry already exists
  if kubectl exec -n spire-system spire-server-0 -- \
    /opt/spire/bin/spire-server entry show -spiffeID "$spiffe_id" &>/dev/null; then
    echo -e "${YELLOW}  ⚠ Entry already exists, skipping${NC}"
    return 0
  fi

  # Create the entry
  if kubectl exec -n spire-system spire-server-0 -- \
    /opt/spire/bin/spire-server entry create \
    -spiffeID "$spiffe_id" \
    -parentID "$AGENT_SPIFFE_ID" \
    $selectors \
    -dns "$dns_name" &>/dev/null; then
    echo -e "${GREEN}  ✓ Created successfully${NC}"
  else
    echo -e "${RED}  ✗ Failed to create entry${NC}"
    return 1
  fi
}

echo "=========================================="
echo "Step 2: Registering workload identities"
echo "=========================================="
echo ""

# Register PostgreSQL
create_entry \
  "spiffe://example.org/ns/demo/sa/postgres" \
  "-selector k8s:ns:demo -selector k8s:sa:postgres" \
  "postgres.demo.svc.cluster.local" \
  "PostgreSQL Database (Pattern 2: spiffe-helper)"

echo ""

# Register Backend
create_entry \
  "spiffe://example.org/ns/demo/sa/backend" \
  "-selector k8s:ns:demo -selector k8s:sa:backend" \
  "backend.demo.svc.cluster.local" \
  "Backend Service (Pattern 1 + Pattern 2)"

echo ""

# Register Frontend
create_entry \
  "spiffe://example.org/ns/demo/sa/frontend" \
  "-selector k8s:ns:demo -selector k8s:sa:frontend" \
  "frontend.demo.svc.cluster.local" \
  "Frontend Service (Pattern 1: Envoy SDS)"

echo ""
echo "=========================================="
echo "Step 3: Verifying registration entries"
echo "=========================================="
echo ""

# Verify all entries
ENTRY_COUNT=$(kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry show -spiffeID spiffe://example.org/ns/demo/sa/frontend 2>/dev/null | grep -c "Entry ID" || echo "0")

if [ "$ENTRY_COUNT" -gt 0 ]; then
  echo -e "${GREEN}✓ All registration entries created successfully${NC}"
  echo ""
  echo "Registered SPIFFE IDs:"
  echo "  • spiffe://example.org/ns/demo/sa/postgres"
  echo "  • spiffe://example.org/ns/demo/sa/backend"
  echo "  • spiffe://example.org/ns/demo/sa/frontend"
  echo ""
  echo -e "${GREEN}Registration complete!${NC}"
else
  echo -e "${RED}✗ Failed to verify entries${NC}"
  exit 1
fi
