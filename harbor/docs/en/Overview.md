# Harbor on VMs: Architecture Decision and Implementation Guide

## Executive Summary

This document provides the rationale and implementation guide for running Harbor, an enterprise-grade container registry, on dedicated virtual machines using Podman instead of Kubernetes.

**Key Decision:** Harbor is deployed on VMs because it is **critical infrastructure**, not a transient workload.

## Why VMs Instead of Kubernetes?

### The Core Problem

Harbor serves as the central container registry for all images. It must:
- Be available even when Kubernetes clusters fail
- Avoid the bootstrapping problem (how do you start K8s if the registry is inside K8s?)
- Provide maximum stability with minimal operational complexity

### Comparison

| Criterion | VM + Podman | Kubernetes |
|-----------|-------------|------------|
| **Operational Reliability** | Very High | Medium |
| **Auditability** | Very High | Medium |
| **Troubleshooting** | Simple | Complex |
| **Personnel Requirements** | Low | High |
| **Vendor Lock-in** | Low | Medium |
| **Operational Cost (3 years)** | ~78,000 € | ~141,000 € |

**Result:** VM + Podman is **80% cheaper** over 3 years while providing **higher availability**.

## Architecture Overview

### Active/Active Setup

```
┌─────────────────────────────────────────────────────┐
│                  Load Balancer                       │
│              (HAProxy / nginx)                       │
└──────────────┬─────────────────────┬─────────────────┘
               │                     │
       ┌───────▼────────┐    ┌──────▼─────────┐
       │  Harbor Node 1 │    │  Harbor Node 2 │
       │   (Podman)     │    │   (Podman)     │
       └───────┬────────┘    └──────┬─────────┘
               │                     │
               └──────────┬──────────┘
                          │
          ┌───────────────▼───────────────┐
          │    Shared State Services      │
          ├───────────────────────────────┤
          │  PostgreSQL (HA Cluster)      │
          │  MinIO / S3 (Object Storage)  │
          │  Redis (Session/Cache)        │
          └───────────────────────────────┘
```

### Components

**Harbor Nodes:**
- Operating System: Rocky Linux 9 (minimal)
- Container Runtime: Podman 4.x
- Harbor Version: 2.x (latest stable)
- Configuration: Identical on all nodes
- Deployment: Via Ansible

**Shared State Services:**
- **PostgreSQL:** Harbor metadata (projects, users, tags)
- **MinIO/S3:** Container images (blobs)
- **Redis:** Session management and job queue

### Network Architecture

```
Management Network (VLAN 10)
  - SSH access (from jumphost only)
  - Ansible automation
  - Monitoring (Prometheus)

Service Network (VLAN 20)
  - Harbor UI/API (HTTPS)
  - Image pull/push operations
  - Access from K8s clusters and developer workstations

Backend Network (VLAN 30)
  - PostgreSQL connections (Harbor nodes only)
  - MinIO/S3 connections (Harbor nodes only)
  - Redis connections (Harbor nodes only)
```

## Automated Deployment with Ansible

### Repository Structure

```
harbor-ansible/
├── inventory/
│   └── harbor.yml
├── group_vars/
│   ├── all.yml
│   └── harbor_nodes.yml
├── roles/
│   ├── common/           # OS hardening, base packages
│   ├── podman/           # Podman installation
│   ├── harbor/           # Harbor deployment
│   └── monitoring/       # Prometheus exporters
├── playbooks/
│   ├── site.yml          # Main playbook
│   ├── deploy-harbor.yml # Harbor-specific
│   └── update-harbor.yml # Update procedure
└── ansible.cfg
```

### Key Features

**Infrastructure as Code:**
- All configuration in Git repository
- Reproducible deployments
- Version controlled

**Security:**
- Secrets encrypted with Ansible Vault
- TLS for all connections (external and internal)
- SELinux enforcing mode
- Firewalld with whitelist approach

**Automation:**
- One-command deployment
- Rolling updates
- Automatic backup scheduling

### Example Deployment

```bash
# 1. Encrypt secrets
ansible-vault encrypt_string 'secure_password' --name 'harbor_admin_password'

# 2. Deploy infrastructure
ansible-playbook -i inventory/harbor.yml playbooks/site.yml --ask-vault-pass

# 3. Verify installation
ansible harbor_nodes -i inventory/harbor.yml -m shell -a "podman ps"
```

## Security and Compliance

### ISO/IEC 27001 & BSI IT-Grundschutz Compliance

**System Hardening:**
- Minimal OS installation (Rocky Linux 9)
- SELinux enforcing mode
- Firewalld with default-deny policy
- No root SSH login

**Access Control:**
- Centralized authentication (LDAP/OIDC)
- Role-based access control (RBAC)
- Separate credentials for PostgreSQL and MinIO
- Least privilege principle

**Network Security:**
- Network segmentation (Management, Service, Backend)
- TLS 1.2+ for all connections
- Strong cipher suites
- Certificate-based authentication

**Logging & Monitoring:**
- Centralized log collection
- Security event monitoring
- Prometheus metrics
- Automated alerting

**Vulnerability Management:**
- Automated image scanning (Trivy)
- Daily scans of all images
- Deployment gates for HIGH/CRITICAL vulnerabilities
- Regular security patching

**Backup & Recovery:**
- Daily PostgreSQL backups (encrypted)
- S3 versioning for images
- Monthly restore tests
- RTO < 4 hours, RPO < 24 hours

### Audit Checklist

- [x] Asset inventory complete
- [x] Access control documented and implemented
- [x] Network segmentation implemented
- [x] TLS for all connections
- [x] Centralized authentication (LDAP/OIDC)
- [x] Logging enabled and centrally collected
- [x] Backup strategy documented and tested
- [x] Patch management process established
- [x] Vulnerability scanning active
- [x] Incident response plan documented

## Operational Costs (3-Year TCO)

| Cost Category | VM + Podman | Kubernetes | Difference |
|---------------|-------------|------------|------------|
| Initial Implementation | 4,800 € | 11,200 € | +6,400 € |
| Ongoing Operations (3y) | 16,800 € | 43,200 € | +26,400 € |
| Infrastructure (3y) | 52,800 € | 63,600 € | +10,800 € |
| Failure Costs (3y) | 3,000 € | 18,000 € | +15,000 € |
| Training (3y) | 800 € | 4,800 € | +4,000 € |
| **TOTAL (3 years)** | **78,200 €** | **140,800 €** | **+62,600 € (+80%)** |

**Key Findings:**
- Kubernetes requires 2-3× more operational effort
- Higher complexity leads to more incidents
- Requires specialized K8s knowledge
- No functional benefit for Harbor as infrastructure component

## Operations

### Daily Tasks (Automated)
- Log rotation
- PostgreSQL backups
- Vulnerability scans

### Weekly Tasks
- Review monitoring dashboards
- Check disk usage
- Process user/project requests

### Monthly Tasks
- Apply security patches
- Test backup restore
- Review performance metrics

### Update Process

Rolling updates with zero downtime:
1. Stop Harbor on Node 1
2. Update Harbor software
3. Start Harbor on Node 1
4. Verify health
5. Repeat for Node 2

## When to Choose Kubernetes Instead?

Kubernetes makes sense for Harbor if:
- K8s cluster already in use for many other workloads
- Dedicated K8s team available (3+ people)
- Strong requirement for declarative configuration
- **AND:** Willingness to accept higher costs

**For most scenarios:** VM + Podman is the better choice.

## Disaster Recovery

### Scenario 1: Single Node Failure

**Detection:** Load balancer marks node unhealthy

**Recovery:** Automatic failover to remaining node

**Manual:** Redeploy failed node with Ansible

**RTO:** < 30 minutes

### Scenario 2: Complete Failure

**Recovery:**
1. Restore infrastructure (VMs)
2. Restore PostgreSQL from backup
3. Redeploy Harbor with Ansible
4. Verify functionality

**RTO:** < 4 hours

## Conclusion

For Harbor as critical infrastructure, **VM + Podman is the technically and economically superior solution**.

**Benefits:**
- 80% lower operational costs
- Higher availability
- Simpler troubleshooting
- Lower personnel requirements
- Better auditability
- ISO/BSI compliance

**Result:** A production-ready, audit-compliant, cost-effective Harbor deployment.

## Quick Start

```bash
# Clone repository
git clone https://github.com/yourorg/harbor-ansible.git
cd harbor-ansible

# Configure inventory
vim inventory/harbor.yml

# Encrypt secrets
ansible-vault create group_vars/all/vault.yml

# Deploy
ansible-playbook -i inventory/harbor.yml playbooks/site.yml --ask-vault-pass

# Verify
curl -k https://harbor.example.com/api/v2.0/health
```

## Further Documentation

**German Documentation:**
- [Architektur](../de/Architektur.md) - Detailed architecture description
- [Betrieb](../de/Betrieb.md) - Operations and Ansible implementation
- [Sicherheit_ISO_BSI](../de/Sicherheit_ISO_BSI.md) - Security and compliance
- [Kosten](../de/Kosten.md) - Detailed cost analysis

## Support and Contact

For questions, issues, or contributions, please contact your DevOps team or refer to the internal documentation portal.
