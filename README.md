# Platform Engineering Notes

Professionelle Referenz-Sammlung für Platform Engineering, Infrastructure-as-Code und High Availability Deployments.

## Übersicht

Dieses Repository dient als persönliche Wissensdatenbank und Referenz-Implementation für Platform Engineering Best Practices. Alle Projekte folgen produktionsreifem Code-Standard und sind praxiserprobt.

## Projekte

### 🐳 Harbor - Container Registry

Vollständige Enterprise-Grade Container Registry Implementation mit Harbor auf virtuellen Maschinen.

**Technologie-Stack:**
- Rocky Linux 9
- Podman (Container Runtime)
- Harbor 2.x (Container Registry)
- PostgreSQL 14+ (Datenbank)
- MinIO/S3 (Object Storage)
- Redis 7.x (Cache/Queue)
- Prometheus + Grafana (Monitoring)

**Infrastruktur:**
- Terraform: Automatisierte VM-Provisionierung auf Proxmox
- Ansible: Vollautomatische Harbor-Installation und -Konfiguration
- Active/Active Architektur für High Availability

**Dokumentation:**
- [Harbor README](harbor/README.md) - Hauptdokumentation
- [Architektur](harbor/docs/de/Architektur.md) - Architekturentscheidungen, VMs vs. Kubernetes, Netzwerk
- [Betrieb](harbor/docs/de/Betrieb.md) - Installation, Wartung, Updates, Troubleshooting, Disaster Recovery
- [Sicherheit (ISO/BSI)](harbor/docs/de/Sicherheit_ISO_BSI.md) - ISO 27001, BSI IT-Grundschutz Compliance
- [Kosten](harbor/docs/de/Kosten.md) - TCO-Analyse, VM vs. Kubernetes Kostenvergleich

**Key Features:**
- VM-basierte Architektur (80% günstiger als Kubernetes über 3 Jahre)
- ISO/IEC 27001 und BSI IT-Grundschutz konform
- Vollständig automatisiertes Deployment
- Umfassende deutsche Dokumentation

**Verzeichnisstruktur:**
```
harbor/
├── terraform-proxmox-harbor/  # IaC für VM-Provisionierung
├── ansible/                   # Automatisierte Harbor-Installation
└── docs/                      # Ausführliche Dokumentation
```

**Verwende dies für:** Container Registry Deployments, Image Scanning, Artifact Management

---

### 🦊 GitLab - DevOps Platform

Infrastructure-as-Code für hochverfügbare GitLab-Deployments auf Proxmox.

**Technologie-Stack:**
- Terraform (IaC)
- Proxmox VE 7.x/8.x
- Rocky Linux 9 (Cloud-Init)
- GitLab Omnibus

**Deployment-Strategien:**
1. **Single-Node** - Entwicklung/kleine Teams (<20 User)
2. **Multi-Node** - Produktion (20-500 User)
3. **High Availability** - Enterprise (>500 User, 99.9%+ Uptime)

**Dokumentation:**
- [GitLab Terraform README](gitlab/terraform-proxmox-gitlab/README.md) - Vollständige Implementierungsanleitung

**Key Features:**
- Deklarative VM-Konfiguration als Code
- Skalierbare Architektur (einfaches Hinzufügen weiterer Nodes)
- Detaillierter Sizing-Guide (CPU/RAM pro Benutzer)
- Produktionsreife Deployment-Strategien
- Umfassende Post-Deployment Checkliste

**Beispiel-Konfiguration:**
```hcl
gitlab_vms = {
  gitlab-app-01 = { cores = 8, memory = 16384, disk = 100 }
  gitlab-app-02 = { cores = 8, memory = 16384, disk = 100 }
  gitlab-data   = { cores = 8, memory = 32768, disk = 500 }
}
```

**Verwende dies für:** Self-hosted GitLab, CI/CD Pipelines, Source Code Management

---

### 🔄 Keepalived - High Availability

Keepalived VRRP-Konfigurationen für hochverfügbare Load Balancing und Failover.

**Technologie-Stack:**
- Keepalived (VRRP)
- Ansible (Automatisierung)
- HAProxy/Nginx (Load Balancer)

**Dokumentation:**
- [Keepalived README](keepalived/README.md) - Vollständige VRRP-Anleitung

**Abgedeckte Konzepte:**
- Virtual IP (VIP) Management
- VRRP (Virtual Router Redundancy Protocol)
- Master/Backup Konfigurationen
- Health Checks (Prozesse, Files, Custom Scripts)
- Unicast vs. Multicast Modus
- Split-Brain Vermeidung

**Key Features:**
- Produktionsreife Ansible-Rolle
- Ausführliche Troubleshooting-Sektion
- Best Practices für Cloud-Umgebungen
- Beispiele für Kubernetes API Server und Ingress HA

**Beispiel Use Cases:**
- Kubernetes Control Plane HA (API Server VIP)
- Ingress Controller Failover
- Database HA (PostgreSQL, MySQL)
- Reverse Proxy HA (HAProxy, Nginx)

**Verwende dies für:** Load Balancer Failover, VIP-Management, aktive HA-Konfigurationen

---

### ⚙️ GitHub Actions

*(Platzhalter für zukünftige GitHub Actions Workflows und CI/CD Templates)*

---

## Technologie-Übersicht

| Kategorie | Technologien |
|-----------|-------------|
| **IaC** | Terraform, Ansible |
| **Virtualisierung** | Proxmox VE, QEMU/KVM |
| **Container** | Podman, Docker, Harbor |
| **Betriebssysteme** | Rocky Linux 9, Debian, Ubuntu |
| **Datenbanken** | PostgreSQL, Redis |
| **Storage** | MinIO, NFS, Ceph, GlusterFS |
| **Load Balancing** | Keepalived, HAProxy, Nginx |
| **Monitoring** | Prometheus, Grafana, Node Exporter |
| **Security** | SELinux, Firewalld, fail2ban, Let's Encrypt |
| **CI/CD** | GitLab CI, GitHub Actions |

---

## Verwendungszweck

Dieses Repository dient als:

1. **Referenz-Implementation** - Produktionsreifer Code für gängige Platform Engineering Aufgaben
2. **Wissensdatenbank** - Dokumentation von Architekturentscheidungen und Best Practices
3. **Schnellstart-Templates** - Kopierbare Terraform/Ansible-Konfigurationen
4. **Troubleshooting-Guide** - Gelöste Probleme und deren Lösungen

---

## Best Practices

Alle Projekte in diesem Repository folgen:

- **Infrastructure-as-Code**: Deklarative, versionskontrollierte Infrastruktur
- **Idempotenz**: Wiederholbare Deployments ohne Seiteneffekte
- **Dokumentation**: Ausführliche README-Dateien mit Architekturentscheidungen
- **Security**: Secrets-Management, Least Privilege, Security Hardening
- **Compliance**: ISO 27001, BSI IT-Grundschutz, DSGVO-konforme Implementierungen
- **Monitoring**: Prometheus/Grafana-Integration für alle Services
- **Backup**: Disaster Recovery Strategien und Restore-Prozeduren

---

## Repository-Struktur

```
platform-engineering-notes/
├── README.md                    # Diese Datei
├── harbor/                      # Container Registry (Harbor)
│   ├── terraform-proxmox-harbor/
│   ├── ansible/
│   └── docs/
├── gitlab/                      # DevOps Platform (GitLab)
│   └── terraform-proxmox-gitlab/
├── keepalived/                  # High Availability (VRRP)
│   ├── ansible/
│   └── README.md
└── github_actions/              # CI/CD Workflows
```

---

## Schnellstart

### Harbor Container Registry deployen

```bash
cd harbor/terraform-proxmox-harbor
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # API-Token und SSH-Key konfigurieren
terraform init && terraform apply

cd ../ansible
ansible-playbook -i inventory/harbor.yml playbooks/site.yml
```

### GitLab auf Proxmox deployen

```bash
cd gitlab/terraform-proxmox-gitlab
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
terraform init && terraform apply
# Siehe README für GitLab-Installation
```

### Keepalived für HA einrichten

```bash
cd keepalived/ansible
vim inventory/hosts.yml  # Server konfigurieren
ansible-playbook -i inventory/hosts.yml playbooks/keepalived.yml
```

---

## Lizenz

Dieses Repository ist für persönliche Referenz und Weiterbildung gedacht. Einzelne Projekte können unterschiedliche Lizenzen haben (siehe jeweilige README-Dateien).

---

## Wartung

**Letztes Update**: Januar 2025
**Getestete Umgebungen**: Proxmox VE 8.x, Rocky Linux 9, Terraform 1.6+, Ansible 2.15+

---

**Hinweis**: Alle Konfigurationen sind produktionserprobt und folgen Enterprise Best Practices. Secrets und sensitive Daten sind über `.gitignore` ausgeschlossen.
