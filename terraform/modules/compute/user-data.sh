#!/bin/bash

# Log everything to /var/log/user-data.log
exec > >(tee /var/log/user-data.log) 2>&1

# Exit on error, but with proper error handling
trap 'echo "ERROR: Script failed at line $LINENO. Check /var/log/user-data.log"; exit 1' ERR

echo "=== Starting Wazuh installation ==="
echo "Wazuh Version: ${wazuh_version}"
echo "Started at: $(date)"

# Marker file to track completion
INSTALL_MARKER="/opt/wazuh/.install_complete"

# Check if already installed
if [ -f "$INSTALL_MARKER" ]; then
    echo "Wazuh already installed. Skipping."
    exit 0
fi

# ===========================================
# System Setup
# ===========================================
echo "=== Updating system ==="
dnf update -y

# Install required packages
dnf install -y docker git openssl

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Wait for Docker to be ready
echo "Waiting for Docker..."
timeout 60 bash -c 'until docker info &>/dev/null; do sleep 2; done'

# ===========================================
# Install Docker Compose
# ===========================================
echo "=== Installing Docker Compose ==="
DOCKER_COMPOSE_VERSION="2.32.4"

if [ ! -f /usr/local/bin/docker-compose ]; then
    curl -L "https://github.com/docker/compose/releases/download/v$${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

docker-compose --version

# ===========================================
# Configure System for OpenSearch
# ===========================================
echo "=== Configuring system for OpenSearch ==="
if ! grep -q "vm.max_map_count=262144" /etc/sysctl.conf; then
    echo "vm.max_map_count=262144" >> /etc/sysctl.conf
fi
sysctl -w vm.max_map_count=262144

# ===========================================
# Clone Wazuh Docker Repository
# ===========================================
echo "=== Setting up Wazuh ==="
WAZUH_DIR="/opt/wazuh"
mkdir -p $WAZUH_DIR
cd $WAZUH_DIR

if [ ! -d "wazuh-docker" ]; then
    git clone https://github.com/wazuh/wazuh-docker.git -b v${wazuh_version}
else
    echo "wazuh-docker already cloned"
fi

cd wazuh-docker/single-node

# ===========================================
# Generate Wazuh Certificates
# ===========================================
CERTS_DIR="$WAZUH_DIR/wazuh-docker/single-node/config/wazuh_indexer_ssl_certs"

if [ ! -f "$CERTS_DIR/root-ca.pem" ]; then
    echo "=== Generating Wazuh certificates ==="
    docker-compose -f generate-indexer-certs.yml run --rm generator
else
    echo "Certificates already exist"
fi

# ===========================================
# Start Wazuh Stack
# ===========================================
echo "=== Starting Wazuh stack ==="
docker-compose up -d

# Wait for containers to be healthy
echo "Waiting for Wazuh containers to be ready..."
MAX_WAIT=300
WAIT_COUNT=0
until docker-compose ps | grep -q "healthy" || [ $WAIT_COUNT -ge $MAX_WAIT ]; do
    echo "Waiting... ($WAIT_COUNT/$MAX_WAIT seconds)"
    sleep 10
    WAIT_COUNT=$((WAIT_COUNT + 10))
done

# Additional wait for services to stabilize
sleep 30

# Verify containers are running
echo "=== Container Status ==="
docker-compose ps

# ===========================================
# Generate Shared Agent Certificate for mTLS
# ===========================================
echo "=== Generating shared agent certificate for mTLS ==="

AGENT_CERTS_DIR="/opt/wazuh/agent-certs"
mkdir -p $AGENT_CERTS_DIR

if [ ! -f "$AGENT_CERTS_DIR/agent.pem" ]; then
    # Copy root CA for agent distribution
    cp $CERTS_DIR/root-ca.pem $AGENT_CERTS_DIR/root-ca.pem

    cd $AGENT_CERTS_DIR

    # Generate agent private key
    openssl genrsa -out agent.key 2048

    # Generate agent CSR
    openssl req -new -key agent.key -out agent.csr \
        -subj "/C=US/ST=California/L=California/O=Wazuh/OU=Wazuh/CN=wazuh-agent"

    # Sign agent certificate with root CA (valid for 365 days)
    openssl x509 -req -in agent.csr \
        -CA $CERTS_DIR/root-ca.pem \
        -CAkey $CERTS_DIR/root-ca.key \
        -CAcreateserial \
        -out agent.pem \
        -days 365 \
        -sha256

    # Clean up CSR
    rm -f agent.csr

    # Set permissions
    chmod 644 $AGENT_CERTS_DIR/*.pem
    chmod 600 $AGENT_CERTS_DIR/agent.key

    echo "Agent certificates generated"
else
    echo "Agent certificates already exist"
fi

echo "=== Agent certificate files ==="
ls -la $AGENT_CERTS_DIR

# ===========================================
# Configure Manager for mTLS
# ===========================================
echo "=== Configuring Manager for mTLS ==="

cd $WAZUH_DIR/wazuh-docker/single-node

# Check if already configured
MTLS_CONFIGURED=$(docker-compose exec -T wazuh.manager grep -c "ssl_agent_ca" /var/ossec/etc/ossec.conf 2>/dev/null || echo "0")

if [ "$MTLS_CONFIGURED" = "0" ]; then
    # Enable SSL for agent communication
    docker-compose exec -T wazuh.manager bash -c "
        sed -i 's|<auth>|<auth>\n    <ssl_agent_ca>/var/ossec/etc/sslmanager.ca</ssl_agent_ca>\n    <ssl_verify_host>no</ssl_verify_host>\n    <ssl_auto_negotiate>yes</ssl_auto_negotiate>|' /var/ossec/etc/ossec.conf
    "

    # Copy root CA into manager container for verification
    docker cp $CERTS_DIR/root-ca.pem $(docker-compose ps -q wazuh.manager):/var/ossec/etc/sslmanager.ca

    # Restart manager to apply changes
    docker-compose restart wazuh.manager

    echo "mTLS configured and manager restarted"
else
    echo "mTLS already configured"
fi

# ===========================================
# Mark Installation Complete
# ===========================================
touch $INSTALL_MARKER
echo "$(date)" > $INSTALL_MARKER

echo ""
echo "=========================================="
echo "=== Wazuh installation complete ==="
echo "=========================================="
echo ""
echo "Dashboard: https://<NLB-DNS>:443"
echo "Default credentials: admin / SecretPassword"
echo ""
echo "=== mTLS Agent Certificates ==="
echo "Retrieve agent certs via SSM:"
echo "  cat /opt/wazuh/agent-certs/root-ca.pem"
echo "  cat /opt/wazuh/agent-certs/agent.pem"
echo "  cat /opt/wazuh/agent-certs/agent.key"
echo ""
echo "To change default password, run:"
echo "  cd /opt/wazuh/wazuh-docker/single-node"
echo "  docker-compose exec wazuh.manager /var/ossec/bin/wazuh-passwords-tool -a"
echo ""
echo "Completed at: $(date)"
