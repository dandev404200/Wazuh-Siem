# Manual Wazuh Installation Guide

This guide mirrors the `user-data.sh` script for manual step-by-step execution.

## Prerequisites

- EC2 instance running Amazon Linux 2023
- SSM access to the instance
- Instance type: t3.xlarge (4 vCPU, 16 GB RAM)
- Storage: 100 GB

## Connect to EC2

```bash
aws ssm start-session --target <instance_id>
```

Once connected, switch to root:

```bash
sudo su -
```

---

## Step 1: Update System

```bash
dnf update -y
```

## Step 2: Install Required Packages

```bash
dnf install -y docker git openssl
```

## Step 3: Enable and Start Docker

```bash
systemctl enable docker
systemctl start docker
```

Verify Docker is running:

```bash
docker info
```

## Step 4: Install Docker Compose

```bash
DOCKER_COMPOSE_VERSION="2.32.4"

curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
```

Verify installation:

```bash
docker-compose --version
```

Expected output: `Docker Compose version v2.32.4`

## Step 5: Configure System for OpenSearch

```bash
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
sysctl -w vm.max_map_count=262144
```

Verify:

```bash
sysctl vm.max_map_count
```

Expected output: `vm.max_map_count = 262144`

## Step 6: Clone Wazuh Docker Repository

```bash
mkdir -p /opt/wazuh
cd /opt/wazuh

WAZUH_VERSION="4.9.0"
git clone https://github.com/wazuh/wazuh-docker.git -b v${WAZUH_VERSION}
```

Verify:

```bash
ls -la /opt/wazuh/wazuh-docker/
```

## Step 7: Generate Wazuh Certificates

```bash
cd /opt/wazuh/wazuh-docker/single-node

docker-compose -f generate-indexer-certs.yml run --rm generator
```

Verify certificates were created:

```bash
ls -la config/wazuh_indexer_ssl_certs/
```

Expected files:
- `root-ca.pem`
- `root-ca-key.pem`
- `wazuh.manager.pem`
- `wazuh.manager-key.pem`
- `wazuh.indexer.pem`
- `wazuh.indexer-key.pem`
- `wazuh.dashboard.pem`
- `wazuh.dashboard-key.pem`
- `admin.pem`
- `admin-key.pem`

## Step 8: Start Wazuh Stack

```bash
cd /opt/wazuh/wazuh-docker/single-node

docker-compose up -d
```

Watch the startup:

```bash
docker-compose logs -f
```

Press `Ctrl+C` to exit logs.

Check container status:

```bash
docker-compose ps
```

Wait until all containers show `healthy` status (may take 2-5 minutes).

## Step 9: Verify Wazuh is Running

Check each container:

```bash
# Manager
docker-compose exec wazuh.manager /var/ossec/bin/wazuh-control status

# Indexer
curl -k -u admin:SecretPassword https://localhost:9200/_cluster/health?pretty

# Dashboard (should return HTML)
curl -k -I https://localhost:443
```

---

## Step 10: Generate Shared Agent Certificate for mTLS

Create agent certs directory:

```bash
mkdir -p /opt/wazuh/agent-certs
cd /opt/wazuh/agent-certs
```

Copy root CA:

```bash
cp /opt/wazuh/wazuh-docker/single-node/config/wazuh_indexer_ssl_certs/root-ca.pem .
```

Generate agent private key:

```bash
openssl genrsa -out agent.key 2048
```

Generate agent CSR:

```bash
openssl req -new -key agent.key -out agent.csr \
    -subj "/C=US/ST=California/L=California/O=Wazuh/OU=Wazuh/CN=wazuh-agent"
```

Sign agent certificate with root CA:

```bash
openssl x509 -req -in agent.csr \
    -CA /opt/wazuh/wazuh-docker/single-node/config/wazuh_indexer_ssl_certs/root-ca.pem \
    -CAkey /opt/wazuh/wazuh-docker/single-node/config/wazuh_indexer_ssl_certs/root-ca-key.pem \
    -CAcreateserial \
    -out agent.pem \
    -days 365 \
    -sha256
```

Clean up and set permissions:

```bash
rm -f agent.csr
chmod 644 *.pem
chmod 600 agent.key
```

Verify:

```bash
ls -la /opt/wazuh/agent-certs/
```

Expected files:
- `root-ca.pem` (644)
- `agent.pem` (644)
- `agent.key` (600)

## Step 11: Configure Manager for mTLS

Check current config (should NOT contain ssl_agent_ca):

```bash
cd /opt/wazuh/wazuh-docker/single-node

docker-compose exec wazuh.manager grep -A5 "<auth>" /var/ossec/etc/ossec.conf
```

Add mTLS configuration:

```bash
docker-compose exec wazuh.manager bash -c "
    sed -i 's|<auth>|<auth>\n    <ssl_agent_ca>/var/ossec/etc/sslmanager.ca</ssl_agent_ca>\n    <ssl_verify_host>no</ssl_verify_host>\n    <ssl_auto_negotiate>yes</ssl_auto_negotiate>|' /var/ossec/etc/ossec.conf
"
```

Copy root CA into manager container:

```bash
docker cp /opt/wazuh/wazuh-docker/single-node/config/wazuh_indexer_ssl_certs/root-ca.pem \
    $(docker-compose ps -q wazuh.manager):/var/ossec/etc/sslmanager.ca
```

Verify the CA was copied:

```bash
docker-compose exec wazuh.manager ls -la /var/ossec/etc/sslmanager.ca
```

Restart manager:

```bash
docker-compose restart wazuh.manager
```

Verify mTLS config:

```bash
docker-compose exec wazuh.manager grep -A5 "<auth>" /var/ossec/etc/ossec.conf
```

Should now show:
```xml
<auth>
    <ssl_agent_ca>/var/ossec/etc/sslmanager.ca</ssl_agent_ca>
    <ssl_verify_host>no</ssl_verify_host>
    <ssl_auto_negotiate>yes</ssl_auto_negotiate>
    ...
</auth>
```

---

## Step 12: Final Verification

### Check all containers are healthy:

```bash
docker-compose ps
```

### Test Dashboard access (from your laptop):

```
https://<NLB-DNS>:443
Username: admin
Password: SecretPassword
```

### View agent certificates (copy these for your agents):

```bash
echo "=== root-ca.pem ==="
cat /opt/wazuh/agent-certs/root-ca.pem

echo "=== agent.pem ==="
cat /opt/wazuh/agent-certs/agent.pem

echo "=== agent.key ==="
cat /opt/wazuh/agent-certs/agent.key
```

---

## Troubleshooting

### View container logs:

```bash
cd /opt/wazuh/wazuh-docker/single-node

# All containers
docker-compose logs -f

# Specific container
docker-compose logs -f wazuh.manager
docker-compose logs -f wazuh.indexer
docker-compose logs -f wazuh.dashboard
```

### Restart all containers:

```bash
docker-compose restart
```

### Restart specific container:

```bash
docker-compose restart wazuh.manager
```

### Check manager status:

```bash
docker-compose exec wazuh.manager /var/ossec/bin/wazuh-control status
```

### Reset and start fresh:

```bash
cd /opt/wazuh/wazuh-docker/single-node

# Stop and remove containers
docker-compose down

# Remove volumes (WARNING: deletes all data)
docker-compose down -v

# Start fresh
docker-compose up -d
```

---

## Mark Installation Complete

Once everything is verified working:

```bash
touch /opt/wazuh/.install_complete
echo "$(date)" > /opt/wazuh/.install_complete
```

This marker file prevents the user-data script from running again if the instance reboots.
