# Wazuh SIEM POC

Wazuh SIEM cluster deployment on AWS using OpenTofu (Terraform) and Docker Compose.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS VPC (10.0.0.0/16)                    │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Public Subnet (10.0.1.0/24)                │   │
│  │    ┌─────────────┐    ┌─────────────┐                   │   │
│  │    │     NLB     │    │ NAT Gateway │                   │   │
│  │    │ :443,:1514, │    │             │                   │   │
│  │    │    :1515    │    │             │                   │   │
│  │    └──────┬──────┘    └──────┬──────┘                   │   │
│  └───────────┼──────────────────┼──────────────────────────┘   │
│              │                  │                               │
│  ┌───────────┼──────────────────┼──────────────────────────┐   │
│  │           ▼                  ▼  Private Subnet          │   │
│  │    ┌─────────────────────────────────────────────┐      │   │
│  │    │         EC2: t3.xlarge (wazuh-server)       │      │   │
│  │    │                                             │      │   │
│  │    │  ┌─────────────┐ ┌─────────────┐ ┌───────┐  │      │   │
│  │    │  │   Manager   │ │   Indexer   │ │ Dash  │  │      │   │
│  │    │  │  :1514/1515 │ │    :9200    │ │ :443  │  │      │   │
│  │    │  └─────────────┘ └─────────────┘ └───────┘  │      │   │
│  │    │            Docker Compose Stack             │      │   │
│  │    └─────────────────────────────────────────────┘      │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

External Agents (Laptops) ──► NLB ──► EC2
Internal Agents (Servers) ──► Private IP ──► EC2
Admin Access ──► AWS SSM Session Manager
```

## Features

- **Cost-effective**: ~$184/month for POC
- **Dual-path agent connectivity**: NLB for external, private IP for internal
- **Secure access**: AWS SSM (no SSH keys)
- **Single-node deployment**: All Wazuh components on one EC2

## Prerequisites

- [OpenTofu](https://opentofu.org/docs/intro/install/) >= 1.6
- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials
- AWS account with permissions for VPC, EC2, NLB, IAM

## Quick Start

```bash
# Clone the repository
git clone <repo-url>
cd Wazuh-Siem

# Configure variables
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your settings

# Deploy
./scripts/deploy.sh
```

## Configuration

Edit `terraform/terraform.tfvars`:

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | us-east-1 | AWS region |
| `environment` | poc | Environment name |
| `instance_type` | t3.xlarge | EC2 instance type |
| `volume_size` | 100 | EBS volume size (GB) |
| `wazuh_version` | 4.9.0 | Wazuh version |

## Outputs

After deployment:

| Output | Description |
|--------|-------------|
| `nlb_dns_name` | NLB DNS for external access |
| `ec2_private_ip` | Private IP for internal agents |
| `dashboard_url` | Wazuh Dashboard URL |
| `ssm_connect_command` | Command to connect via SSM |

## Accessing Wazuh

### Dashboard
```
URL: https://<nlb_dns_name>
Username: admin
Password: SecretPassword
```

### Connect to EC2 via SSM
```bash
aws ssm start-session --target <instance_id>
```

### Check Container Status
```bash
sudo docker ps
sudo docker-compose -f /opt/wazuh/wazuh-docker/single-node/docker-compose.yml logs -f
```

## Agent Registration (mTLS)

This deployment uses mTLS - agents must have certificates to register.

### Step 1: Retrieve Agent Certificates

Connect via SSM and copy the certificates:

```bash
# Connect to EC2
aws ssm start-session --target <instance_id>

# View certificates (copy these to your agent machines)
cat /opt/wazuh/agent-certs/root-ca.pem
cat /opt/wazuh/agent-certs/agent.pem
cat /opt/wazuh/agent-certs/agent.key
```

### Step 2: Install Agent with Certificates

On each agent machine, place the certificates and install:

```bash
# Create cert directory
sudo mkdir -p /var/ossec/etc/certs

# Copy certificates (paste content from Step 1)
sudo nano /var/ossec/etc/certs/root-ca.pem
sudo nano /var/ossec/etc/certs/agent.pem
sudo nano /var/ossec/etc/certs/agent.key

# Set permissions
sudo chmod 644 /var/ossec/etc/certs/*.pem
sudo chmod 600 /var/ossec/etc/certs/agent.key

# Install agent (Linux)
curl -so wazuh-agent.deb https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.9.0-1_amd64.deb
sudo WAZUH_MANAGER='<nlb_dns_name>' dpkg -i ./wazuh-agent.deb
```

### Step 3: Configure Agent for mTLS

Edit `/var/ossec/etc/ossec.conf` on the agent:

```xml
<client>
  <server>
    <address><nlb_dns_name></address>
    <port>1514</port>
    <protocol>tcp</protocol>
  </server>
  <enrollment>
    <enabled>yes</enabled>
    <manager_address><nlb_dns_name></manager_address>
    <agent_certificate_path>/var/ossec/etc/certs/agent.pem</agent_certificate_path>
    <agent_key_path>/var/ossec/etc/certs/agent.key</agent_key_path>
    <server_ca_path>/var/ossec/etc/certs/root-ca.pem</server_ca_path>
  </enrollment>
</client>
```

### Step 4: Start Agent

```bash
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent

# Check status
sudo systemctl status wazuh-agent
```

### Internal Agents (VPC Servers)

Same process, but use private IP instead of NLB:

```xml
<address>10.0.2.x</address>
<manager_address>10.0.2.x</manager_address>
```

## Estimated Monthly Cost

| Resource | Cost |
|----------|------|
| EC2 t3.xlarge | ~$120 |
| EBS 100GB gp3 | ~$8 |
| NLB | ~$16 |
| NAT Gateway | ~$35 |
| Data Transfer | ~$5 |
| **Total** | **~$184** |

## Teardown

```bash
./scripts/destroy.sh
```

## Project Structure

```
wazuh-siem/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── modules/
│       ├── vpc/
│       ├── security/
│       ├── iam/
│       ├── compute/
│       └── nlb/
├── docker/
│   └── docker-compose.yml    # Reference only (not used in deployment)
├── scripts/
│   ├── deploy.sh
│   └── destroy.sh
├── architecture.md
├── task_plan.md
├── findings.md
└── progress.md
```

## Scaling Beyond POC

For production, consider:
- Larger EC2 instance or multi-node cluster
- ECS/EKS for container orchestration
- Multi-AZ deployment
- Dedicated OpenSearch cluster

## License

MIT
