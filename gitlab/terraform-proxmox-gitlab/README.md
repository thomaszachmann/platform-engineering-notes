# GitLab - Proxmox Deployment mit Terraform

Infrastructure-as-Code (IaC) Lösung für die automatisierte Bereitstellung einer hochverfügbaren GitLab-Instanz auf Proxmox Virtual Environment.

## 📋 Projektübersicht

Dieses Projekt implementiert eine professionelle, skalierbare GitLab-Infrastruktur mittels deklarativer Terraform-Konfiguration. Die Lösung folgt Infrastructure-as-Code Best Practices und ermöglicht reproduzierbare, versionskontrollierte Deployments.

### Architektur

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
│  │ GitLab Core  │  │ GitLab Core  │  │ PostgreSQL   │  │
│  │ GitLab Web   │  │ GitLab Web   │  │ Redis        │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│         │                 │                  │          │
│         └─────────────────┴──────────────────┘          │
│                      vmbr0 (DHCP)                       │
└─────────────────────────────────────────────────────────┘
```

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

## 📝 Nächste Schritte

Nach erfolgreichem Deployment:

1. **GitLab Installation**: Ansible Playbook für GitLab-Deployment erstellen
2. **Monitoring**: Prometheus/Grafana für VM-Monitoring einrichten
3. **Backup**: Automated Backup-Strategie implementieren
4. **Load Balancer**: HAProxy/Nginx für HA-Setup konfigurieren
5. **DNS**: DNS-Einträge für GitLab-VMs erstellen
6. **TLS**: Let's Encrypt Zertifikate für GitLab einrichten
7. **GitLab Runners**: CI/CD Runner-Konfiguration einrichten
8. **Storage**: Object Storage (S3/MinIO) für Artifacts und LFS konfigurieren

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
