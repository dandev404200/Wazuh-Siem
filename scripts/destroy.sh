#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}=== Wazuh SIEM POC Teardown ===${NC}"
echo ""
echo -e "${YELLOW}WARNING: This will destroy all infrastructure including:${NC}"
echo "  - EC2 instance and all data"
echo "  - NLB and target groups"
echo "  - VPC, subnets, NAT Gateway"
echo "  - Security groups and IAM roles"
echo ""

read -p "Are you sure you want to destroy everything? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Teardown cancelled."
    exit 0
fi

# Navigate to terraform directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../terraform"

# Destroy
echo -e "${YELLOW}Destroying infrastructure...${NC}"
tofu destroy -auto-approve

echo ""
echo -e "${GREEN}=== Teardown Complete ===${NC}"
echo "All resources have been destroyed."
