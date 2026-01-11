# Wazuh SIEM Cluster Architecture

## Overview

POC deployment using Docker Compose on a single EC2 instance. Features:
- **Simple & cost-effective**: ~$150/month
- **Dual-path agent connectivity**: NLB for external agents (laptops), private IP for internal servers
- **Unified PKI**: Private Root CA for all agent certificates
- **Secure access**: AWS SSM Session Manager (no SSH)

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                        AWS VPC (10.0.0.0/16)                                     │
│                                                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                            Public Subnet (10.0.1.0/24)                                     │  │
│  │                                                                                            │  │
│  │    ┌─────────────────────────────────────┐                                                 │  │
│  │    │    Network Load Balancer (NLB)      │◄───────────────┐                                │  │
│  │    │    (wazuh-nlb)                      │                │                                │  │
│  │    │                                     │    ┌───────────┴────────────┐                   │  │
│  │    │    :1514 → EC2:1514 (events)        │    │  Employee Laptops      │                   │  │
│  │    │    :1515 → EC2:1515 (registration)  │    │  (External Agents)     │                   │  │
│  │    │    :443  → EC2:443 (dashboard)      │    │  + Admin Dashboard     │                   │  │
│  │    └──────────────────┬──────────────────┘    └────────────────────────┘                   │  │
│  │                       │                                                                    │  │
│  │    ┌──────────────────┴──────────────────┐                                                 │  │
│  │    │         NAT Gateway                 │◄── EC2 outbound (docker pull, SSM, etc)        │  │
│  │    └─────────────────────────────────────┘                                                 │  │
│  │                                                                                            │  │
│  └────────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                          │                                                       │
│  ┌───────────────────────────────────────┼────────────────────────────────────────────────────┐  │
│  │                                       ▼       Private Subnet (10.0.2.0/24)                 │  │
│  │                                                                                            │  │
│  │    ┌─────────────────────────────────────────────────────────────────────────────────┐    │  │
│  │    │                 EC2: t3.xlarge (wazuh-server) - 10.0.2.10                        │    │  │
│  │    │                 4 vCPU | 16 GB RAM | 100 GB gp3                                  │    │  │
│  │    │                 IAM Role: SSM access                                             │    │  │
│  │    │                                                                                  │    │  │
│  │    │    ┌────────────────────────────────────────────────────────────────────────┐   │    │  │
│  │    │    │                     Docker Compose Stack                               │   │    │  │
│  │    │    │                                                                        │   │    │  │
│  │    │    │  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐       │   │    │  │
│  │    │    │  │  wazuh-manager   │ │  wazuh-indexer   │ │  wazuh-dashboard │       │   │    │  │
│  │    │    │  │                  │ │                  │ │                  │       │   │    │  │
│  │    │    │  │  :1514 (events)  │ │  :9200 (REST)    │ │  :443 (HTTPS)    │       │   │    │  │
│  │    │    │  │  :1515 (register)│ │  :9300 (cluster) │ │                  │       │   │    │  │
│  │    │    │  │  :55000 (API)    │ │                  │ │                  │       │   │    │  │
│  │    │    │  │  :1516 (cluster) │ │                  │ │                  │       │   │    │  │
│  │    │    │  └────────┬─────────┘ └────────┬─────────┘ └────────┬─────────┘       │   │    │  │
│  │    │    │           │                    │                    │                 │   │    │  │
│  │    │    │           └────────────────────┼────────────────────┘                 │   │    │  │
│  │    │    │                                ▼                                      │   │    │  │
│  │    │    │                    Docker Volumes (persistent)                        │   │    │  │
│  │    │    │                    - wazuh_api_configuration                          │   │    │  │
│  │    │    │                    - wazuh_etc                                        │   │    │  │
│  │    │    │                    - wazuh_logs                                       │   │    │  │
│  │    │    │                    - wazuh_queue                                      │   │    │  │
│  │    │    │                    - wazuh-indexer-data                               │   │    │  │
│  │    │    │                    - filebeat_etc, filebeat_var                       │   │    │  │
│  │    │    └────────────────────────────────────────────────────────────────────────┘   │    │  │
│  │    │                                                                                  │    │  │
│  │    └─────────────────────────────────────────────────────────────────────────────────┘    │  │
│  │                                       ▲                                                   │  │
│  │                                       │ Direct via Private IP (10.0.2.10)                │  │
│  │                                       │                                                   │  │
│  │    ┌──────────────────────────────────┴───────────────────────────────────────────────┐   │  │
│  │    │                        Internal Servers (VPC Agents)                             │   │  │
│  │    │                        Connect via: 10.0.2.10:1514, :1515                        │   │  │
│  │    │                        (Same VPC or peered VPCs)                                 │   │  │
│  │    └──────────────────────────────────────────────────────────────────────────────────┘   │  │
│  │                                                                                            │  │
│  └────────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘

SSM Access: Admin Laptop → Internet → AWS SSM Service → NAT Gateway → EC2 (SSM Agent)

                    ┌─────────────────────────────────────────────┐
                    │            Private Root CA                  │
                    │     (Unified trust for all agents)          │
                    └─────────────────────────────────────────────┘
```

## Agent Connectivity Paths

| Agent Type | Connection Path | Target | Ports |
|------------|-----------------|--------|-------|
| **Employee Laptops** | Internet → NLB → EC2 | NLB DNS name | 1514, 1515 |
| **Internal Servers** | VPC → Private IP | 10.0.2.10 | 1514, 1515 |
| **Admin (Dashboard)** | Internet → NLB → EC2 | NLB DNS name | 443 |
| **Admin (CLI)** | SSM Session Manager | EC2 instance | N/A |

## Infrastructure Specifications

### EC2 Instance
| Attribute | Value |
|-----------|-------|
| Instance Type | t3.xlarge |
| vCPU | 4 |
| RAM | 16 GB |
| Storage | 100 GB gp3 |
| AMI | Amazon Linux 2023 |
| Subnet | Private (10.0.2.0/24) |
| Public IP | None (accessed via SSM) |
| IAM Role | SSM managed instance |

### Docker Containers
| Container | Image | Ports | Resources |
|-----------|-------|-------|-----------|
| wazuh-manager | wazuh/wazuh-manager:4.9.0 | 1514, 1515, 1516, 55000 | ~2 GB RAM |
| wazuh-indexer | wazuh/wazuh-indexer:4.9.0 | 9200, 9300 | ~4 GB RAM |
| wazuh-dashboard | wazuh/wazuh-dashboard:4.9.0 | 443 | ~1 GB RAM |

## Network Design

### VPC Configuration
| Component | CIDR/Value |
|-----------|------------|
| VPC | 10.0.0.0/16 |
| Public Subnet | 10.0.1.0/24 |
| Private Subnet | 10.0.2.0/24 |
| NAT Gateway | In public subnet |

### Security Groups

#### SG: `wazuh-nlb-sg` (NLB - public facing)
| Direction | Port | Protocol | Source | Description |
|-----------|------|----------|--------|-------------|
| Inbound | 443 | TCP | 0.0.0.0/0 | Dashboard HTTPS |
| Inbound | 1514 | TCP | 0.0.0.0/0 | Agent events |
| Inbound | 1515 | TCP | 0.0.0.0/0 | Agent registration |

#### SG: `wazuh-ec2-sg` (EC2 - private)
| Direction | Port | Protocol | Source | Description |
|-----------|------|----------|--------|-------------|
| Inbound | 443 | TCP | 0.0.0.0/0 | Dashboard (NLB passthrough) |
| Inbound | 1514 | TCP | 0.0.0.0/0 | Events (NLB passthrough) |
| Inbound | 1515 | TCP | 0.0.0.0/0 | Registration (NLB passthrough) |
| Inbound | 1514 | TCP | 10.0.0.0/16 | Events from VPC agents |
| Inbound | 1515 | TCP | 10.0.0.0/16 | Registration from VPC agents |
| Inbound | 55000 | TCP | 10.0.0.0/16 | API from VPC |
| Outbound | All | All | 0.0.0.0/0 | All traffic (incl. SSM via NAT) |

## Project Structure

```
wazuh-siem/
├── terraform/
│   ├── main.tf                    # Root module
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Output values
│   ├── providers.tf               # AWS provider config
│   ├── terraform.tfvars.example   # Example variable values
│   └── modules/
│       ├── vpc/                   # VPC, subnets, IGW, NAT Gateway
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── security/              # Security groups (NLB, EC2)
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── iam/                   # IAM role for SSM
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── compute/               # EC2 instance
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   └── user-data.sh       # Bootstrap: install Docker, deploy stack
│       └── nlb/                   # Network Load Balancer
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
│
├── docker/
│   ├── docker-compose.yml         # Wazuh stack definition
│   └── config/
│       ├── wazuh_indexer/
│       │   └── wazuh.indexer.yml
│       ├── wazuh_manager/
│       │   └── ossec.conf
│       └── wazuh_dashboard/
│           └── opensearch_dashboards.yml
│
├── certs/
│   └── generate-certs.sh          # Certificate generation script
│
├── scripts/
│   ├── deploy.sh                  # Full deployment script
│   └── destroy.sh                 # Teardown script
│
├── task_plan.md
├── findings.md
├── progress.md
├── architecture.md
└── README.md
```

## Deployment Flow

```
1. Terraform Apply
   └── Creates in order:
       ├── VPC, Subnets, IGW, NAT Gateway
       ├── Security Groups
       ├── IAM Role (SSM)
       ├── NLB + Target Groups
       └── EC2 Instance
           └── user-data.sh runs:
               ├── Install Docker & Docker Compose
               ├── Clone/copy docker-compose.yml
               ├── Generate certificates
               └── docker-compose up -d

2. Verify Deployment
   └── SSM connect to EC2
       └── docker ps (check containers)
       └── Access Dashboard at https://<NLB-DNS>

3. Agent Enrollment
   └── External: agents connect to NLB DNS
   └── Internal: agents connect to 10.0.2.10
```

## Estimated Monthly Cost

| Resource | Specification | Monthly Cost |
|----------|---------------|--------------|
| EC2 t3.xlarge | On-demand | ~$120 |
| EBS 100 GB gp3 | Storage | ~$8 |
| NLB | Network Load Balancer | ~$16 |
| NAT Gateway | Hourly + data | ~$35 |
| Data Transfer | ~50 GB/month | ~$5 |
| **Total** | | **~$184/month** |

## Scaling Considerations

This POC architecture can handle:
- **60 agents** - Comfortable capacity
- **500 EPS** - Well within limits
- **Data retention** - ~7 days with default settings

For production scaling beyond this POC:
- Upgrade to larger EC2 instance
- Add EBS volume for more storage
- Consider multi-node deployment
- Migrate to ECS or EKS for HA
