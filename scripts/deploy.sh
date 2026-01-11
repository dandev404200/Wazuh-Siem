#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Wazuh SIEM POC Deployment ===${NC}"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v tofu &> /dev/null; then
    echo -e "${RED}Error: OpenTofu is not installed${NC}"
    echo "Install it from: https://opentofu.org/docs/intro/install/"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi

echo -e "${GREEN}Prerequisites OK${NC}"

# Navigate to terraform directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../terraform"

# Check for terraform.tfvars
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}terraform.tfvars not found. Creating from example...${NC}"
    cp terraform.tfvars.example terraform.tfvars
    echo -e "${YELLOW}Please edit terraform.tfvars with your settings, then run this script again.${NC}"
    exit 0
fi

# Initialize OpenTofu
echo -e "${YELLOW}Initializing OpenTofu...${NC}"
tofu init

# Plan
echo -e "${YELLOW}Planning infrastructure...${NC}"
tofu plan -out=tfplan

# Confirm deployment
echo ""
read -p "Do you want to apply this plan? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
fi

# Apply
echo -e "${YELLOW}Applying infrastructure...${NC}"
tofu apply tfplan

# Get outputs
echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo -e "${YELLOW}Outputs:${NC}"
tofu output

echo ""
echo -e "${GREEN}=== Next Steps ===${NC}"
echo "1. Wait 5-10 minutes for Wazuh to fully initialize"
echo "2. Connect via SSM:"
echo "   $(tofu output -raw ssm_connect_command)"
echo ""
echo "3. Check container status:"
echo "   sudo docker ps"
echo "   sudo docker-compose -f /opt/wazuh/wazuh-docker/single-node/docker-compose.yml logs -f"
echo ""
echo "4. Access Dashboard:"
echo "   $(tofu output -raw dashboard_url)"
echo "   Default credentials: admin / SecretPassword"
echo ""
echo "5. Register agents using:"
echo "   External: $(tofu output -raw agent_registration_address)"
echo "   Internal: $(tofu output -raw internal_agent_address)"
