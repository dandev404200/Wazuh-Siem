# Task Plan: Wazuh SIEM Cluster Deployment with Terraform & Docker Compose

## Goal
Deploy a POC Wazuh SIEM cluster on AWS using Terraform for infrastructure and Docker Compose for container orchestration.

## Current Phase
Phase 2

## Phases

### Phase 1: Requirements & Discovery
- [x] Research Wazuh cluster architecture (manager, indexer, dashboard)
- [x] Identify infrastructure requirements (compute, storage, networking)
- [x] Define deployment topology (single EC2 with Docker Compose)
- [x] Document Wazuh version and component dependencies
- **Status:** complete

### Phase 2: Architecture Design
- [x] Design Terraform module structure
- [x] Design Docker Compose configuration
- [x] Define networking (VPC, subnets, NLB, security groups)
- [x] Plan dual-path agent connectivity (NLB + private IP)
- [x] Plan storage strategy (Docker volumes)
- **Status:** complete

### Phase 3: Terraform Implementation
- [ ] Create provider configuration
- [ ] Implement VPC module
- [ ] Implement security groups module
- [ ] Implement IAM module (SSM role)
- [ ] Implement NLB module
- [ ] Implement EC2 compute module with user-data
- [ ] Create variables and outputs
- **Status:** pending

### Phase 4: Docker Compose Implementation
- [ ] Create docker-compose.yml for Wazuh stack
- [ ] Configure Wazuh Manager container
- [ ] Configure Wazuh Indexer container
- [ ] Configure Wazuh Dashboard container
- [ ] Set up Docker volumes for persistence
- [ ] Configure SSL/TLS certificates
- **Status:** pending

### Phase 5: Integration & Configuration
- [ ] Create EC2 user-data bootstrap script
- [ ] Set up certificate generation
- [ ] Configure health checks
- [ ] Create deployment orchestration script
- **Status:** pending

### Phase 6: Testing & Verification
- [ ] Validate Terraform plan
- [ ] Test EC2 provisioning
- [ ] Verify Docker Compose deployment
- [ ] Test agent enrollment (external + internal)
- [ ] Verify dashboard accessibility
- **Status:** pending

### Phase 7: Documentation & Delivery
- [ ] Create deployment guide
- [ ] Document configuration options
- [ ] Create troubleshooting guide
- **Status:** pending

## Key Questions (Answered)
1. Cloud provider: **AWS**
2. Expected scale: **60 agents, 500 EPS**
3. Deployment type: **Single EC2 POC**
4. Orchestration: **Docker Compose**
5. Agent connectivity: **NLB (external) + Private IP (internal)**
6. Access method: **AWS SSM (no SSH)**

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| AWS | User requirement |
| Docker Compose on EC2 | Simple, cost-effective (~$184/mo) |
| t3.xlarge | 4 vCPU, 16 GB RAM sufficient for POC |
| NLB | Layer 4 LB for agent traffic + dashboard |
| AWS SSM | No SSH keys, audit logging, IAM-based |
| Wazuh 4.9.x | Latest stable with improved performance |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
|       |         |            |

## Notes
- Wazuh consists of: Manager (OSSEC), Indexer (OpenSearch), Dashboard (Kibana fork)
- Cluster mode requires minimum 2 manager nodes (master + worker)
- Indexer cluster requires minimum 3 nodes for HA
- Update phase status as you progress: pending -> in_progress -> complete
- Re-read this plan before major decisions
