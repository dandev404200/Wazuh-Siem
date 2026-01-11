# Findings & Decisions

## Requirements
<!-- Captured from user request -->
- Deploy Wazuh SIEM in cluster mode
- Use Terraform for infrastructure provisioning
- Use Docker for containerization
- **Cloud Provider:** AWS
- **Deployment Type:** Multi-node POC
- **Scale:** 60 agents, ~500 events/second
- **Orchestration:** Docker Compose on EC2
- **Agent Connectivity:** NLB for external (laptops), Private IP for internal (servers)
- **Certificate Trust:** Private Root CA for unified agent trust
- **Instance Access:** AWS SSM Session Manager (no SSH)

## Research Findings

### Wazuh Architecture Components
1. **Wazuh Manager** - Central component for agent management, rule processing, threat detection
   - Master node: Handles agent registration, rule synchronization
   - Worker nodes: Process events, execute active responses
   
2. **Wazuh Indexer** - OpenSearch-based data store
   - Stores alerts, events, and compliance data
   - Requires cluster of 3+ nodes for HA
   
3. **Wazuh Dashboard** - Web interface (OpenSearch Dashboards fork)
   - Visualization and management interface
   - Can run multiple instances behind load balancer

4. **Filebeat** - Log shipper from Manager to Indexer

### Minimum Requirements (Production Cluster)
| Component | CPU | RAM | Storage |
|-----------|-----|-----|---------|
| Manager (master) | 4 cores | 8 GB | 50 GB |
| Manager (worker) | 4 cores | 8 GB | 50 GB |
| Indexer node | 4 cores | 8 GB | 100 GB |
| Dashboard | 2 cores | 4 GB | 20 GB |

### Networking Requirements
- Port 1514 (TCP/UDP): Agent communication
- Port 1515 (TCP): Agent registration
- Port 1516 (TCP): Cluster communication
- Port 55000 (TCP): API
- Port 9200 (TCP): Indexer REST API
- Port 9300-9400 (TCP): Indexer cluster
- Port 443 (TCP): Dashboard HTTPS

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Docker Compose on EC2 | Simple, cost-effective (~$150/mo), easy to manage |
| Single t3.xlarge EC2 | 4 vCPU, 16 GB RAM sufficient for POC |
| Wazuh 4.9.x | Latest stable with improved performance |
| Terraform modules | Reusable, maintainable infrastructure code |
| NLB for external agents | Layer 4 LB, preserves client IP, handles TCP/UDP |
| AWS SSM | No SSH keys, audit logging, IAM-based access |
| Private Root CA | Unified trust model for all agents (laptops + servers) |

## Docker Compose Architecture

### EC2 Instance
- **Type:** t3.xlarge (4 vCPU, 16 GB RAM)
- **Storage:** 100 GB gp3
- **Subnet:** Private (accessed via SSM)
- **Docker Compose:** Orchestrates all Wazuh containers

### Containers
1. **wazuh-manager** - Single node (master mode)
2. **wazuh-indexer** - Single node OpenSearch
3. **wazuh-dashboard** - Web UI
4. **Volumes:** Local Docker volumes for persistence

## Issues Encountered
| Issue | Resolution |
|-------|------------|
|       |            |

## Resources
- Wazuh Documentation: https://documentation.wazuh.com
- Wazuh Docker Images: https://hub.docker.com/u/wazuh
- Wazuh GitHub: https://github.com/wazuh/wazuh-docker
- Terraform AWS Provider: https://registry.terraform.io/providers/hashicorp/aws

## Visual/Browser Findings
<!-- CRITICAL: Update after every 2 view/browser operations -->
<!-- Multimodal content must be captured as text immediately -->
- (none yet)

---
*Update this file after every 2 view/browser/search operations*
*This prevents visual information from being lost*
