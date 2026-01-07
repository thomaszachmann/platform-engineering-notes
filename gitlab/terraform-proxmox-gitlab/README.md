# GitLab - Proxmox Deployment mit Terraform

Infrastructure-as-Code (IaC) Lösung für die automatisierte Bereitstellung einer hochverfügbaren GitLab-Instanz auf Proxmox Virtual Environment.

## 📋 Projektübersicht

Dieses Projekt implementiert eine professionelle, skalierbare GitLab-Infrastruktur mittels deklarativer Terraform-Konfiguration. Die Lösung folgt Infrastructure-as-Code Best Practices und ermöglicht reproduzierbare, versionskontrollierte Deployments.

## 🏗️ GitLab Produktions-Deployment-Strategien

### 1. Single-Node Deployment (Entwicklung/kleine Teams)

**Empfohlen für**: Entwicklungs-Umgebungen, kleine Teams (<20 Benutzer), Proof-of-Concept

```
┌─────────────────────────────────┐
│      GitLab All-in-One VM       │
│                                 │
│  • GitLab (Puma/Workhorse)      │
│  • PostgreSQL                   │
│  • Redis                        │
│  • Gitaly                       │
│  • Sidekiq                      │
│                                 │
│  Ressourcen:                    │
│  • 8 vCPUs                      │
│  • 16 GB RAM                    │
│  • 200 GB SSD                   │
└─────────────────────────────────┘
```

**Vorteile:**
- Einfache Installation und Wartung
- Geringer Ressourcenbedarf
- Schnelles Setup

**Nachteile:**
- Single Point of Failure
- Keine Hochverfügbarkeit
- Begrenzte Skalierbarkeit
- Schwierige Performance-Optimierung einzelner Komponenten

### 2. Multi-Node Deployment (Empfohlen für Produktion)

**Empfohlen für**: Produktions-Umgebungen, mittlere bis große Teams (20-500 Benutzer)

```
┌──────────────────────────────────────────────────────────────┐
│                     Load Balancer VM                          │
│              (HAProxy/Nginx - Optional extern)                │
└────────────────────────┬─────────────────────────────────────┘
                         │
          ┌──────────────┼──────────────┐
          │              │              │
┌─────────▼────────┐ ┌───▼────────────┐ ┌──────────────────┐
│   GitLab-App-01  │ │ GitLab-App-02  │ │  GitLab-Data-VM  │
│                  │ │                │ │                  │
│ • Puma/Rails     │ │ • Puma/Rails   │ │ • PostgreSQL     │
│ • Workhorse      │ │ • Workhorse    │ │ • Redis          │
│ • Gitaly         │ │ • Gitaly       │ │ • Shared Storage │
│ • Sidekiq        │ │ • Sidekiq      │ │                  │
│                  │ │                │ │  Ressourcen:     │
│  Ressourcen:     │ │  Ressourcen:   │ │  • 8 vCPUs       │
│  • 8 vCPUs       │ │  • 8 vCPUs     │ │  • 32 GB RAM     │
│  • 16 GB RAM     │ │  • 16 GB RAM   │ │  • 500 GB SSD    │
│  • 100 GB SSD    │ │  • 100 GB SSD  │ │                  │
└──────────────────┘ └────────────────┘ └──────────────────┘
```

**Vorteile:**
- Bessere Performance durch Aufgabentrennung
- Horizontale Skalierung der Application-Layer möglich
- Einfachere Wartung (DB-Updates ohne Downtime)
- Bessere Ressourcen-Isolation

**Nachteile:**
- Höherer Verwaltungsaufwand
- Mehr Ressourcen benötigt
- Komplexere Netzwerk-Konfiguration

**Terraform-Konfiguration** (terraform.tfvars):
```hcl
gitlab_vms = {
  gitlab-app-01 = {
    cores  = 8
    memory = 16384
    disk   = 100
  }
  gitlab-app-02 = {
    cores  = 8
    memory = 16384
    disk   = 100
  }
  gitlab-data = {
    cores  = 8
    memory = 32768
    disk   = 500
  }
}
```

### 3. High Availability (HA) Deployment (Enterprise)

**Empfohlen für**: Business-kritische Umgebungen, große Teams (>500 Benutzer), 99.9%+ Uptime

```
┌────────────────────────────────────────────────────────────────┐
│              Load Balancer Cluster (HA)                        │
│         HAProxy/Nginx (Active-Active + Keepalived)             │
└─────────────────────────┬──────────────────────────────────────┘
                          │
            ┌─────────────┼─────────────┬─────────────┐
            │             │             │             │
   ┌────────▼───────┐ ┌───▼────────┐ ┌──▼──────────┐ │
   │  GitLab-Web-01 │ │ GitLab-02  │ │ GitLab-03   │ │
   │                │ │            │ │             │ │
   │ • Puma/Rails   │ │ • Puma     │ │ • Puma      │ │
   │ • Workhorse    │ │ • Workhorse│ │ • Workhorse │ │
   └────────────────┘ └────────────┘ └─────────────┘ │
                                                       │
   ┌─────────────────────────────────────────────────▼┘
   │
   ├──► ┌────────────────┐ ┌─────────────────┐ ┌────────────────┐
   │    │ PostgreSQL-01  │ │ PostgreSQL-02   │ │ PostgreSQL-03  │
   │    │ (Primary)      │ │ (Replica)       │ │ (Replica)      │
   │    │ + Patroni      │ │ + Patroni       │ │ + Patroni      │
   │    └────────────────┘ └─────────────────┘ └────────────────┘
   │
   ├──► ┌────────────────┐ ┌─────────────────┐ ┌────────────────┐
   │    │  Redis-01      │ │  Redis-02       │ │  Redis-03      │
   │    │  (Master)      │ │  (Replica)      │ │  (Replica)     │
   │    │  + Sentinel    │ │  + Sentinel     │ │  + Sentinel    │
   │    └────────────────┘ └─────────────────┘ └────────────────┘
   │
   ├──► ┌────────────────┐ ┌─────────────────┐
   │    │  Gitaly-01     │ │  Gitaly-02      │
   │    │  (Praefect)    │ │  (Praefect)     │
   │    └────────────────┘ └─────────────────┘
   │
   └──► ┌──────────────────────────────────────┐
        │  NFS/GlusterFS/Ceph Storage Cluster  │
        │  (Shared Storage für Git Repos)      │
        └──────────────────────────────────────┘
```

**Vorteile:**
- Echte Hochverfügbarkeit (99.9%+ Uptime)
- Keine Single Points of Failure
- Automatisches Failover
- Horizontale Skalierung aller Komponenten
- Performance-Optimierung pro Service

**Nachteile:**
- Hohe Komplexität
- Signifikanter Ressourcenbedarf (10+ VMs)
- Erfordert dediziertes Ops-Team
- Höhere Kosten

**Mindest-Ressourcen für HA-Setup:**
- 3x GitLab Application: je 8 vCPU, 16 GB RAM, 100 GB
- 3x PostgreSQL + Patroni: je 4 vCPU, 8 GB RAM, 200 GB
- 3x Redis Sentinel: je 2 vCPU, 4 GB RAM, 20 GB
- 3x Gitaly: je 8 vCPU, 16 GB RAM, 500 GB
- 2x Load Balancer: je 2 vCPU, 4 GB RAM, 20 GB
- 3x Storage Nodes: je 4 vCPU, 8 GB RAM, 1+ TB

**Gesamtbedarf**: ~70 vCPUs, ~180 GB RAM, ~3+ TB Storage

## 🎯 Empfehlung für verschiedene Szenarien

| Szenario | Deployment-Typ | Geschätzte Kosten | Verfügbarkeit |
|----------|---------------|-------------------|---------------|
| Entwicklung/Testing | Single-Node | Niedrig | 95% |
| Kleines Team (<50) | Multi-Node (2+1) | Mittel | 98% |
| Produktions-Team (50-500) | Multi-Node (3+1) | Mittel-Hoch | 99% |
| Enterprise (>500) | HA-Cluster | Hoch | 99.9%+ |

## 💡 Wichtige Architektur-Entscheidungen

### Storage-Strategie

**Option 1: Lokale Disks** (aktuelle Implementierung)
- Einfach, aber kein Shared Storage zwischen Nodes
- Nur für Single-Node oder mit NFS-Nachinstallation

**Option 2: NFS-Server**
- Zentrale VM mit NFS-Export für Git Repositories
- Einfach zu implementieren, aber Performance-Bottleneck

**Option 3: Object Storage (S3/MinIO)**
- GitLab kann Artifacts, LFS, Uploads in S3 speichern
- Empfohlen für Produktion
- Skaliert besser als NFS

**Option 4: Gitaly Cluster (Praefect)**
- GitLab-eigene Lösung für Git-Storage-HA
- Komplex, aber Production-grade
- Nur für Enterprise-Deployments

### Datenbank-Strategie

**Single PostgreSQL** (aktuelle Implementierung)
- Einfach, aber Single Point of Failure
- Regelmäßige Backups ZWINGEND erforderlich

**PostgreSQL mit Streaming Replication**
- Primary + Replica(s)
- Manuelle Failover-Prozedur
- Guter Kompromiss für mittlere Deployments

**PostgreSQL mit Patroni + etcd**
- Automatisches Failover
- Erfordert mindestens 3 Nodes
- Production-grade für HA

### Redis-Strategie

**Single Redis** (aktuelle Implementierung)
- Ausreichend für kleine Deployments
- Nur Session-Cache, kein kritischer Datenverlust

**Redis Sentinel**
- 3+ Redis Instances mit Sentinel
- Automatisches Failover
- Empfohlen ab 100+ Benutzern

**Redis Cluster**
- Horizontale Skalierung
- Nur für sehr große Deployments nötig

## 📊 Sizing-Guide

### CPU-Anforderungen pro Benutzer

- **Light-User** (wenig CI/CD): ~0.05 vCPU
- **Medium-User** (moderate CI/CD): ~0.1 vCPU
- **Heavy-User** (intensive CI/CD): ~0.2 vCPU

**Beispiele:**
- 50 Medium-User: ~5 vCPUs (GitLab-App) + 2 vCPUs (DB) = 7 vCPUs
- 200 Medium-User: ~20 vCPUs (GitLab-App) + 4 vCPUs (DB) = 24 vCPUs

### RAM-Anforderungen

**GitLab Application Node:**
- Basis: 4 GB
- Pro Puma Worker (empfohlen: CPU_count - 1): +1.5 GB
- Pro Sidekiq Worker: +1 GB
- Beispiel (8 vCPU): 4 + (7 × 1.5) + 2 = ~16 GB

**PostgreSQL:**
- Kleine DB (<10k Projekte): 8 GB
- Mittlere DB (10k-50k Projekte): 16 GB
- Große DB (>50k Projekte): 32+ GB

**Redis:**
- Kleine Installation: 2 GB
- Mittlere Installation: 4-8 GB
- Große Installation: 8-16 GB

### Aktuelle Terraform-Implementierung

Dieses Repository implementiert standardmäßig ein **Multi-Node Deployment** (siehe Deployment-Strategien oben):

```
┌─────────────────────────────────────────────────────────┐
│                    Proxmox Cluster                       │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  gitlab-01   │  │  gitlab-02   │  │ gitlab-data  │  │
│  │              │  │              │  │              │  │
│  │ 4 vCPUs      │  │ 4 vCPUs      │  │ 4 vCPUs      │  │
│  │ 8 GB RAM     │  │ 8 GB RAM     │  │ 16 GB RAM    │  │
│  │ 40 GB Disk   │  │ 40 GB Disk   │  │ 200 GB Disk  │  │
│  │              │  │              │  │              │  │
│  │ GitLab App   │  │ GitLab App   │  │ PostgreSQL   │  │
│  │ (zu install.)│  │ (zu install.)│  │ Redis        │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│         │                 │                  │          │
│         └─────────────────┴──────────────────┘          │
│                      vmbr0 (DHCP)                       │
└─────────────────────────────────────────────────────────┘
```

**Hinweis**: Die VMs werden mit Terraform provisioniert, die GitLab-Software muss anschließend installiert werden (siehe "Nächste Schritte"). Die Ressourcen können in `terraform.tfvars` an Ihre Anforderungen angepasst werden.

### Technologie-Stack

- **IaC**: Terraform >= 1.0
- **Provider**: bpg/proxmox (Proxmox VE Provider)
- **Virtualisierung**: Proxmox VE 7.x/8.x
- **Base Image**: Rocky Linux 9 (Cloud-Init)
- **Provisionierung**: Cloud-Init
- **Versionskontrolle**: Git

## 🎯 Features

- ✅ **Deklarative Infrastruktur**: Vollständige VM-Konfiguration als Code
- ✅ **Idempotent**: Wiederholbare Deployments ohne Seiteneffekte
- ✅ **Skalierbar**: Einfaches Hinzufügen weiterer Nodes via Variable
- ✅ **Sicher**: Secrets-Management via `.gitignore` und `.tfvars`
- ✅ **Cloud-Init**: Automatisierte OS-Konfiguration bei Erststart
- ✅ **Automatische Outputs**: IP-Adressen und SSH-Befehle nach Deployment

## 📚 Voraussetzungen

### Proxmox VE

- Proxmox VE 7.x oder höher
- API-Token mit entsprechenden Berechtigungen
- Cloud-Init-Template (siehe unten)

### Lokales System

```bash
# Terraform installieren
brew install terraform  # macOS
# oder
apt-get install terraform  # Ubuntu/Debian

# SSH-Schlüssel generieren (falls nicht vorhanden)
ssh-keygen -t ed25519 -C "your-email@example.com"
```

## 🔧 Konfigurations-Beispiele für verschiedene Szenarien

### Szenario 1: Single-Node für Entwicklung

Ideal für Entwicklungs-/Test-Umgebungen:

```hcl
gitlab_vms = {
  gitlab-all-in-one = {
    cores  = 8
    memory = 16384
    disk   = 200
  }
}
```

Nach Deployment: Omnibus GitLab installieren mit PostgreSQL + Redis + Gitaly auf einer VM.

### Szenario 2: Multi-Node für kleine Produktion (Standard)

Aktuelle Konfiguration, geeignet für 20-100 Benutzer:

```hcl
gitlab_vms = {
  gitlab-app-01 = {
    cores  = 4
    memory = 8192
    disk   = 40
  }
  gitlab-app-02 = {
    cores  = 4
    memory = 8192
    disk   = 40
  }
  gitlab-data = {
    cores  = 4
    memory = 16384
    disk   = 200
  }
}
```

Nach Deployment:
- `gitlab-app-01/02`: GitLab Application (Puma, Workhorse, Sidekiq, Gitaly)
- `gitlab-data`: PostgreSQL + Redis
- Optional: Load Balancer vor den App-Nodes

### Szenario 3: Multi-Node für mittlere Produktion

Für 100-300 Benutzer mit besserer Performance:

```hcl
gitlab_vms = {
  gitlab-app-01 = {
    cores  = 8
    memory = 16384
    disk   = 100
  }
  gitlab-app-02 = {
    cores  = 8
    memory = 16384
    disk   = 100
  }
  gitlab-app-03 = {
    cores  = 8
    memory = 16384
    disk   = 100
  }
  gitlab-postgres = {
    cores  = 8
    memory = 32768
    disk   = 500
  }
  gitlab-redis = {
    cores  = 4
    memory = 8192
    disk   = 50
  }
  gitlab-storage = {
    cores  = 4
    memory = 8192
    disk   = 1000
  }
}
```

Nach Deployment:
- `gitlab-app-01/02/03`: GitLab Application (Load-balanced)
- `gitlab-postgres`: Dedizierte PostgreSQL-Instanz
- `gitlab-redis`: Dedizierte Redis-Instanz
- `gitlab-storage`: NFS-Server für Git Repositories
- Externer Load Balancer (HAProxy/Nginx) erforderlich

### Szenario 4: High Availability Basis-Setup

Minimales HA-Setup für geschäftskritische Umgebungen:

```hcl
gitlab_vms = {
  # Application Nodes
  gitlab-app-01 = { cores = 8, memory = 16384, disk = 100 }
  gitlab-app-02 = { cores = 8, memory = 16384, disk = 100 }
  gitlab-app-03 = { cores = 8, memory = 16384, disk = 100 }

  # PostgreSQL Cluster (Patroni)
  gitlab-pg-01 = { cores = 4, memory = 8192, disk = 300 }
  gitlab-pg-02 = { cores = 4, memory = 8192, disk = 300 }
  gitlab-pg-03 = { cores = 4, memory = 8192, disk = 300 }

  # Redis Sentinel
  gitlab-redis-01 = { cores = 2, memory = 4096, disk = 20 }
  gitlab-redis-02 = { cores = 2, memory = 4096, disk = 20 }
  gitlab-redis-03 = { cores = 2, memory = 4096, disk = 20 }

  # Gitaly Cluster
  gitlab-gitaly-01 = { cores = 8, memory = 16384, disk = 500 }
  gitlab-gitaly-02 = { cores = 8, memory = 16384, disk = 500 }
  gitlab-gitaly-03 = { cores = 8, memory = 16384, disk = 500 }

  # Load Balancers
  gitlab-lb-01 = { cores = 2, memory = 4096, disk = 20 }
  gitlab-lb-02 = { cores = 2, memory = 4096, disk = 20 }
}
```

**Gesamtressourcen**: 66 vCPUs, 156 GB RAM, ~2.7 TB Storage

Nach Deployment:
- Komplexe Konfiguration mit Patroni, Redis Sentinel, Gitaly Praefect
- Erfordert dediziertes Ops-Team und ausführliche Dokumentation
- Siehe [GitLab High Availability Documentation](https://docs.gitlab.com/ee/administration/high_availability/)

## 🚀 Schnellstart

### 1. Cloud-Init Template erstellen

Auf dem Proxmox Host ausführen:

```bash
# Rocky Linux Cloud-Image herunterladen
cd /tmp
wget https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2

# VM mit ID 9000 erstellen
qm create 9000 --name rocky-9-template \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0

# Disk importieren und konfigurieren
qm importdisk 9000 Rocky-9-GenericCloud-Base.latest.x86_64.qcow2 local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0

# Cloud-Init Drive hinzufügen
qm set 9000 --ide2 local-lvm:cloudinit

# Boot-Konfiguration
qm set 9000 --boot c --bootdisk scsi0

# Serial Console für Cloud-Init
qm set 9000 --serial0 socket --vga serial0

# QEMU Guest Agent aktivieren (empfohlen)
qm set 9000 --agent enabled=1

# Als Template markieren
qm template 9000
```

### 2. Proxmox API-Token erstellen

1. In Proxmox Web-UI navigieren zu: **Datacenter → Permissions → API Tokens**
2. Neuen Token erstellen: `root@pam!terraform`
3. Berechtigungen: **PVEVMAdmin** (oder entsprechende Rolle)
4. Token-Secret kopieren (wird nur einmal angezeigt!)

### 3. Repository klonen und konfigurieren

```bash
git clone <repository-url>
cd terraform-proxmox-gitlab

# Variablen-Datei erstellen
cp terraform.tfvars.example terraform.tfvars

# Konfiguration anpassen
vim terraform.tfvars
```

### 4. `terraform.tfvars` konfigurieren

```hcl
# Proxmox API-Token (Format: USER@REALM!TOKENID=SECRET)
proxmox_api_token = "root@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Proxmox Node-Name (prüfen in Proxmox UI unter Datacenter)
proxmox_node = "pve01"

# SSH Public Key (aus ~/.ssh/id_ed25519.pub)
ssh_public_key = "ssh-ed25519 AAAA... your-email@example.com"

# Template VM ID (falls abweichend von 9000)
template_vm_id = 9000

# VM-Konfiguration (anpassbar nach Bedarf)
gitlab_vms = {
  gitlab-01 = {
    cores  = 4
    memory = 8192
    disk   = 40
  }
  gitlab-02 = {
    cores  = 4
    memory = 8192
    disk   = 40
  }
  gitlab-data = {
    cores  = 4
    memory = 16384
    disk   = 200
  }
}
```

### 5. Deployment durchführen

```bash
# Terraform initialisieren
terraform init

# Deployment-Plan prüfen
terraform plan

# Infrastruktur bereitstellen
terraform apply

# Nach erfolgreichem Deployment werden IP-Adressen ausgegeben:
# GitLab VMs erfolgreich erstellt!
# ================================
#
# gitlab-01 (VM ID: 111)
#     IP: 172.16.0.172
#     SSH: ssh rocky@172.16.0.172
#   ...
```

### 6. VMs verifizieren

```bash
# SSH-Zugriff testen
ssh rocky@172.16.0.172

# Alle VM-IPs anzeigen
terraform output vm_summary
```

## 📁 Projektstruktur

```
.
├── README.md                      # Diese Datei
├── .gitignore                     # Git-Ignore für Secrets
├── provider.tf                    # Proxmox Provider-Konfiguration
├── variables.tf                   # Variable-Definitionen
├── terraform.tfvars.example       # Beispiel-Variablen (ohne Secrets)
├── terraform.tfvars              # Actual Variablen (wird nicht committed!)
├── gitlab-vms.tf                  # VM-Ressourcen-Definitionen
├── outputs.tf                     # Output-Definitionen für IP-Adressen
├── versions.tf                    # Terraform & Provider Versionen
└── .terraform/                    # Terraform Cache (wird nicht committed!)
```

## 🔧 Konfigurationsoptionen

### VM-Ressourcen anpassen

In `terraform.tfvars`:

```hcl
gitlab_vms = {
  gitlab-01 = {
    cores  = 8       # CPU-Kerne erhöhen
    memory = 16384   # RAM erhöhen (in MB)
    disk   = 100     # Disk-Größe erhöhen (in GB)
  }
}
```

### Weitere VMs hinzufügen

```hcl
gitlab_vms = {
  # ... bestehende VMs
  gitlab-03 = {
    cores  = 4
    memory = 8192
    disk   = 40
  }
}
```

### Netzwerk-Bridge ändern

In `variables.tf`:

```hcl
variable "vm_network_bridge" {
  type    = string
  default = "vmbr1"  # Andere Bridge verwenden
}
```

## 🔒 Sicherheit

### Secrets-Management

**WICHTIG**: Folgende Dateien enthalten sensible Daten und dürfen NIEMALS committed werden:

- `terraform.tfvars` - API-Token, SSH-Keys
- `terraform.tfstate*` - Vollständiger Infrastruktur-State mit Secrets
- `.terraform/` - Provider-Cache

Diese Dateien sind bereits in `.gitignore` eingetragen.

### Best Practices

1. **API-Token Rotation**: Regelmäßig neue Tokens generieren
2. **Least Privilege**: Token nur mit minimal notwendigen Rechten
3. **SSH-Keys**: Ed25519 statt RSA verwenden (moderner, sicherer)
4. **State-Backend**: Für Produktiv-Umgebungen Remote State (S3, Terraform Cloud) nutzen
5. **HTTPS**: Proxmox API nur über HTTPS ansprechen (bereits konfiguriert)

## 🛠 Troubleshooting

### Problem: "No Guest Agent configured"

**Lösung**: QEMU Guest Agent im Template installieren:

```bash
# Im Template (vor dem Konvertieren zu Template):
sudo dnf install qemu-guest-agent -y
sudo systemctl enable --now qemu-guest-agent
```

### Problem: "SSH connection refused"

**Mögliche Ursachen**:
1. VM noch nicht vollständig gebootet (Cloud-Init läuft)
2. Falscher SSH-Key in `terraform.tfvars`
3. Firewall blockiert Port 22

**Lösung**:
```bash
# 1-2 Minuten warten, dann erneut versuchen
ssh rocky@<IP-ADRESSE>

# In Proxmox Console prüfen:
# VM auswählen → Console → Login testen
```

### Problem: "API Token validation error"

**Lösung**: Token-Format prüfen:
```
Korrekt: root@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Falsch:  root@pam!terraform!xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
         (! statt = vor Secret)
```

### Problem: "Template VM ID 9000 not found"

**Lösung**:
1. In Proxmox UI prüfen, ob Template existiert
2. VM ID in `terraform.tfvars` anpassen:
   ```hcl
   template_vm_id = 9001  # Ihre tatsächliche Template-ID
   ```

## 📊 Nützliche Terraform-Befehle

```bash
# State anzeigen
terraform show

# Einzelne Ressource anzeigen
terraform state show 'proxmox_virtual_environment_vm.gitlab["gitlab-01"]'

# Outputs anzeigen
terraform output
terraform output vm_ip_addresses

# Infrastruktur löschen
terraform destroy

# State aktualisieren (z.B. für neue IP-Adressen)
terraform refresh

# Formatierung prüfen
terraform fmt

# Konfiguration validieren
terraform validate
```

## 🔄 Workflow für Updates

```bash
# 1. Änderungen in .tf Dateien vornehmen
vim gitlab-vms.tf

# 2. Plan prüfen
terraform plan

# 3. Änderungen anwenden
terraform apply

# 4. Git Commit
git add gitlab-vms.tf
git commit -m "feat: Increase memory for gitlab-data to 32GB"
git push
```

## 📝 Nächste Schritte nach VM-Deployment

### Phase 1: GitLab-Installation (Pflicht)

**1. GitLab Omnibus installieren**

Für Single-Node oder Multi-Node Deployments:

```bash
# Auf allen GitLab-Application VMs:
ssh rocky@<vm-ip>

# Package Repository hinzufügen
curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.rpm.sh | sudo bash

# GitLab installieren
sudo EXTERNAL_URL="https://gitlab.example.com" dnf install -y gitlab-ee

# GitLab konfigurieren
sudo vim /etc/gitlab/gitlab.rb
sudo gitlab-ctl reconfigure
```

**2. PostgreSQL konfigurieren** (für Multi-Node)

Auf `gitlab-data` VM:
```bash
# PostgreSQL für externe Verbindungen konfigurieren
# In /etc/gitlab/gitlab.rb:
postgresql['enable'] = true
postgresql['listen_address'] = '0.0.0.0'
postgresql['md5_auth_cidr_addresses'] = ['172.16.0.0/24']  # Ihr Netzwerk

# Auf Application-Nodes: externes PostgreSQL verwenden
postgresql['enable'] = false
gitlab_rails['db_host'] = '172.16.0.X'  # gitlab-data IP
```

**3. Redis konfigurieren** (für Multi-Node)

```bash
# Auf gitlab-data:
redis['enable'] = true
redis['bind'] = '0.0.0.0'

# Auf Application-Nodes:
redis['enable'] = false
gitlab_rails['redis_host'] = '172.16.0.X'  # gitlab-data IP
```

### Phase 2: Hochverfügbarkeit (Optional, für Produktion)

**4. Load Balancer einrichten**

Option A: HAProxy (empfohlen):
```bash
# Auf separater VM oder bestehendem LB:
sudo dnf install haproxy

# /etc/haproxy/haproxy.cfg:
frontend gitlab_http
    bind *:80
    bind *:443 ssl crt /etc/haproxy/certs/gitlab.pem
    default_backend gitlab_backend

backend gitlab_backend
    balance roundrobin
    option httpchk GET /health_check
    http-check expect status 200
    server gitlab-app-01 172.16.0.X:80 check
    server gitlab-app-02 172.16.0.Y:80 check
```

Option B: Nginx:
```bash
# Nginx als Reverse Proxy
upstream gitlab {
    server 172.16.0.X:80;
    server 172.16.0.Y:80;
}

server {
    listen 80;
    server_name gitlab.example.com;
    location / {
        proxy_pass http://gitlab;
    }
}
```

**5. Shared Storage einrichten** (für Multi-Node)

Option A: NFS (einfach):
```bash
# Auf gitlab-storage VM:
sudo dnf install nfs-utils
sudo systemctl enable --now nfs-server

# /etc/exports:
/var/opt/gitlab/.ssh 172.16.0.0/24(rw,sync,no_root_squash)
/var/opt/gitlab/git-data 172.16.0.0/24(rw,sync,no_root_squash)

sudo exportfs -ra

# Auf Application-Nodes:
sudo mkdir -p /var/opt/gitlab/.ssh /var/opt/gitlab/git-data
sudo mount 172.16.0.X:/var/opt/gitlab/.ssh /var/opt/gitlab/.ssh
sudo mount 172.16.0.X:/var/opt/gitlab/git-data /var/opt/gitlab/git-data
```

Option B: Object Storage (empfohlen für Produktion):
```ruby
# In /etc/gitlab/gitlab.rb:
gitlab_rails['object_store']['enabled'] = true
gitlab_rails['object_store']['connection'] = {
  'provider' => 'AWS',
  'region' => 'eu-central-1',
  'aws_access_key_id' => 'YOUR_KEY',
  'aws_secret_access_key' => 'YOUR_SECRET',
  'endpoint' => 'https://s3.example.com'  # MinIO/Ceph
}
```

### Phase 3: Sicherheit & Monitoring (Empfohlen)

**6. TLS/SSL-Zertifikate einrichten**

Option A: Let's Encrypt (automatisch):
```ruby
# In /etc/gitlab/gitlab.rb:
external_url 'https://gitlab.example.com'
letsencrypt['enable'] = true
letsencrypt['contact_emails'] = ['admin@example.com']
```

Option B: Eigene Zertifikate:
```bash
sudo mkdir -p /etc/gitlab/ssl
sudo chmod 755 /etc/gitlab/ssl
# Zertifikat und Key nach /etc/gitlab/ssl/gitlab.example.com.crt/key kopieren
```

**7. Backup-Strategie implementieren**

```ruby
# In /etc/gitlab/gitlab.rb:
gitlab_rails['backup_path'] = "/var/opt/gitlab/backups"
gitlab_rails['backup_keep_time'] = 604800  # 7 Tage

# Automatisches Backup via Cron:
# 0 2 * * * /opt/gitlab/bin/gitlab-backup create CRON=1
```

Backup auf externes Storage:
```bash
# Nach S3/MinIO:
gitlab_rails['backup_upload_connection'] = {
  'provider' => 'AWS',
  'region' => 'eu-central-1',
  'aws_access_key_id' => 'YOUR_KEY',
  'aws_secret_access_key' => 'YOUR_SECRET'
}
gitlab_rails['backup_upload_remote_directory'] = 'gitlab-backups'
```

**8. Monitoring mit Prometheus/Grafana**

GitLab hat eingebaute Prometheus-Exporter:
```ruby
# In /etc/gitlab/gitlab.rb:
prometheus['enable'] = true
prometheus['listen_address'] = '0.0.0.0:9090'
node_exporter['enable'] = true
postgres_exporter['enable'] = true
redis_exporter['enable'] = true
```

Grafana Dashboard importieren:
- GitLab Omnibus: Dashboard ID 13396
- PostgreSQL: Dashboard ID 9628
- Redis: Dashboard ID 11835

**9. GitLab Runner installieren** (für CI/CD)

```bash
# Auf separater VM oder Application-Node:
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh" | sudo bash
sudo dnf install gitlab-runner

# Runner registrieren:
sudo gitlab-runner register \
  --url "https://gitlab.example.com/" \
  --registration-token "YOUR_TOKEN" \
  --executor "docker" \
  --docker-image "alpine:latest"
```

**10. DNS-Einträge konfigurieren**

```
; A-Records für Load Balancer oder Single-Node:
gitlab.example.com.    IN  A  172.16.0.X
registry.example.com.  IN  A  172.16.0.X
pages.example.com.     IN  A  172.16.0.X

; Wildcard für GitLab Pages:
*.pages.example.com.   IN  A  172.16.0.X
```

### Phase 4: Optimierung (Optional)

**11. Performance-Tuning**

```ruby
# In /etc/gitlab/gitlab.rb für 8 vCPU / 16 GB RAM VM:

# Puma (Application Server)
puma['worker_processes'] = 4
puma['min_threads'] = 4
puma['max_threads'] = 4

# Sidekiq (Background Jobs)
sidekiq['max_concurrency'] = 20

# PostgreSQL
postgresql['shared_buffers'] = "4GB"
postgresql['work_mem'] = "16MB"
postgresql['maintenance_work_mem'] = "512MB"
postgresql['effective_cache_size'] = "8GB"

# Gitaly (Git RPC Service)
gitaly['concurrency'] = [
  { 'rpc' => "/gitaly.SmartHTTPService/PostReceivePack", 'max_per_repo' => 3 },
  { 'rpc' => "/gitaly.SSHService/SSHUploadPack", 'max_per_repo' => 3 }
]
```

**12. Security Hardening**

```ruby
# SSH auf Key-only, HTTPS erzwingen
nginx['redirect_http_to_https'] = true
nginx['ssl_protocols'] = "TLSv1.2 TLSv1.3"

# Rate Limiting
gitlab_rails['rate_limit_requests_per_period'] = 10
gitlab_rails['rate_limit_period'] = 60

# 2FA erzwingen
gitlab_rails['require_two_factor_authentication'] = true
```

## 🎓 Best Practices für Produktion

### Sicherheit

1. **Secrets Management**: Vault/Sealed Secrets für Credentials verwenden
2. **Network Segmentation**: Datenbank-VMs in separatem VLAN
3. **Firewall**: Nur notwendige Ports öffnen (80, 443, 22)
4. **Regular Updates**: Monatliche GitLab-Updates einplanen
5. **SSH Hardening**: Key-only auth, fail2ban installieren
6. **Audit Logging**: GitLab Audit Events aktivieren

### Backup & Disaster Recovery

1. **3-2-1 Rule**: 3 Copies, 2 Media Types, 1 Offsite
2. **Automated Backups**: Täglich um 2 Uhr nachts
3. **Backup Testing**: Monatlich Restore-Test durchführen
4. **RTO/RPO definieren**:
   - Dev: RTO 24h, RPO 24h
   - Prod: RTO 4h, RPO 1h
   - Critical: RTO 1h, RPO 15min
5. **Dokumentation**: Restore-Prozedur dokumentieren

### Monitoring & Alerting

**Kritische Metriken überwachen:**
- CPU/RAM-Auslastung > 80%
- Disk Space < 20% frei
- PostgreSQL Connection Pool Saturation
- Sidekiq Queue Length > 1000
- Failed Jobs Rate
- HTTP 5xx Error Rate
- Git Push/Pull Latency

**Alerting Setup:**
```yaml
# Prometheus Alertmanager rules:
groups:
  - name: gitlab
    rules:
      - alert: GitLabDown
        expr: up{job="gitlab"} == 0
        for: 5m
        annotations:
          summary: "GitLab is down"

      - alert: HighMemoryUsage
        expr: (node_memory_Active_bytes / node_memory_MemTotal_bytes) > 0.9
        for: 10m
```

### Kapazitätsplanung

**Wann skalieren?**
- CPU-Auslastung dauerhaft > 70%
- RAM-Auslastung > 85%
- Disk I/O Wait > 20%
- Sidekiq Queue Length steigt kontinuierlich
- HTTP Response Time > 2s (P95)

**Skalierungs-Strategien:**
1. **Vertikale Skalierung**: Mehr CPU/RAM pro VM (bis 16 vCPU / 32 GB)
2. **Horizontale Skalierung**: Mehr Application-Nodes hinzufügen
3. **Service-Separation**: Sidekiq auf eigene VMs auslagern
4. **Caching**: Redis-Cache vergrößern, CDN vorschalten

## 🤝 Mitwirkende

- Thomas Mundt - Initial work & Architecture

## 📄 Lizenz

Dieses Projekt steht unter der MIT-Lizenz.

## 🙏 Danksagungen

- [bpg/terraform-provider-proxmox](https://github.com/bpg/terraform-provider-proxmox) - Exzellenter Proxmox Provider
- [GitLab](https://about.gitlab.com/) - DevOps Platform
- [Rocky Linux](https://rockylinux.org/) - Enterprise Linux

---

**Hinweis**: Dieses Projekt dient als Referenz-Implementation für Infrastructure-as-Code Best Practices im Enterprise-Umfeld.
