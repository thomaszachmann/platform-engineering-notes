# Harbor Ansible Automation

Ansible-Rollen und Playbooks für die automatisierte Bereitstellung der Harbor Container Registry Infrastruktur auf Rocky Linux 9.

## Überblick

Dieses Ansible-Projekt automatisiert die Konfiguration der Harbor Data VM mit folgenden Services:

- **PostgreSQL 16**: Datenbank-Backend für Harbor
- **Redis 7**: Cache und Message Queue
- **MinIO**: S3-kompatibles Object Storage für Container Images

## Voraussetzungen

### Lokales System

```bash
# Ansible installieren
pip3 install ansible

# Erforderliche Ansible Collections installieren
ansible-galaxy collection install ansible.posix
ansible-galaxy collection install community.postgresql
ansible-galaxy collection install community.general
```

### Ziel-VMs

- Rocky Linux 9.x
- SSH-Zugriff mit SSH-Key
- Sudo-Rechte für den Ansible-Benutzer
- VMs bereits über Terraform bereitgestellt

## Projektstruktur

```
ansible/
├── README.md                      # Diese Datei
├── ansible.cfg                    # Ansible-Konfiguration
├── inventory/
│   └── harbor.yml                 # Inventory-Datei
├── playbooks/
│   └── harbor-data.yml            # Playbook für Data VM
├── group_vars/
│   └── harbor_data/
│       ├── vars.yml               # Öffentliche Variablen
│       └── vault.yml.example      # Beispiel für Secrets
└── roles/
    ├── common/                    # Basis-Systemhärtung
    ├── postgresql/                # PostgreSQL-Installation
    ├── redis/                     # Redis-Installation
    └── minio/                     # MinIO-Installation
```

## Quick Start

### 1. Inventory konfigurieren

IP-Adressen in `inventory/harbor.yml` anpassen (aus Terraform-Output):

```yaml
harbor_data:
  hosts:
    harbor-data:
      ansible_host: 172.16.0.174  # Anpassen!
```

### 2. Vault-Datei erstellen

```bash
# Beispiel-Vault kopieren
cp group_vars/harbor_data/vault.yml.example group_vars/harbor_data/vault.yml

# Passwörter anpassen
vim group_vars/harbor_data/vault.yml

# Mit ansible-vault verschlüsseln
ansible-vault encrypt group_vars/harbor_data/vault.yml
```

### 3. SSH-Zugriff testen

```bash
# Connectivity prüfen
ansible -i inventory/harbor.yml harbor_data -m ping

# Erwartete Ausgabe:
# harbor-data | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }
```

### 4. Deployment durchführen

```bash
# Komplettes Deployment
ansible-playbook -i inventory/harbor.yml playbooks/harbor-data.yml --ask-vault-pass

# Oder mit spezifischen Tags
ansible-playbook -i inventory/harbor.yml playbooks/harbor-data.yml --ask-vault-pass --tags postgresql

# Dry-Run (Check Mode)
ansible-playbook -i inventory/harbor.yml playbooks/harbor-data.yml --ask-vault-pass --check
```

## Rollen-Übersicht

### Common-Rolle

**Zweck**: Basis-Systemhärtung (BSI/ISO-konform)

**Features**:
- SELinux Enforcing
- Firewalld aktiviert
- SSH-Härtung (kein Root-Login, nur Key-Auth)
- Kernel-Parameter für Sicherheit
- Auditd für Compliance
- Chrony für Zeitsynchronisierung

**Tags**: `common`, `base`

### PostgreSQL-Rolle

**Zweck**: PostgreSQL-Datenbank für Harbor

**Features**:
- PostgreSQL 16 Installation
- Performance-Tuning für 16GB RAM
- Automatische Datenbank- und User-Erstellung
- pg_hba.conf für sichere Authentifizierung
- Firewall- und SELinux-Konfiguration

**Tags**: `postgresql`, `database`

**Wichtige Variablen**:
```yaml
postgresql_version: "16"
harbor_db_name: "harbor"
harbor_db_user: "harbor"
harbor_db_password: "..."  # In vault.yml
```

### Redis-Rolle

**Zweck**: Redis für Caching und Queuing

**Features**:
- Redis 7.x Installation
- Memory-Limit und Eviction-Policy
- Passwort-Authentifizierung
- Persistenz-Konfiguration
- Firewall- und SELinux-Konfiguration

**Tags**: `redis`, `cache`

**Wichtige Variablen**:
```yaml
redis_port: 6379
redis_maxmemory: "4gb"
redis_password: "..."  # In vault.yml
```

### MinIO-Rolle

**Zweck**: S3-kompatibles Object Storage

**Features**:
- MinIO Binary-Installation
- Systemd-Service-Konfiguration
- Automatische Bucket-Erstellung
- Harbor-spezifischer User mit Policy
- Web-Console auf Port 9001

**Tags**: `minio`, `storage`

**Wichtige Variablen**:
```yaml
minio_api_port: 9000
minio_console_port: 9001
minio_harbor_bucket: "harbor-storage"
minio_root_password: "..."  # In vault.yml
```

## Verwendung mit Tags

```bash
# Nur Basis-Konfiguration
ansible-playbook -i inventory/harbor.yml playbooks/harbor-data.yml --tags common

# Nur PostgreSQL
ansible-playbook -i inventory/harbor.yml playbooks/harbor-data.yml --tags postgresql

# Nur Redis
ansible-playbook -i inventory/harbor.yml playbooks/harbor-data.yml --tags redis

# Nur MinIO
ansible-playbook -i inventory/harbor.yml playbooks/harbor-data.yml --tags minio

# Mehrere Tags
ansible-playbook -i inventory/harbor.yml playbooks/harbor-data.yml --tags "postgresql,redis"
```

## Konfiguration anpassen

### PostgreSQL Performance-Tuning

In `group_vars/harbor_data/vars.yml`:

```yaml
postgresql_shared_buffers: "8GB"      # Erhöhen für mehr RAM
postgresql_effective_cache_size: "24GB"
postgresql_max_connections: 300
```

### Redis Memory-Limit

```yaml
redis_maxmemory: "8gb"  # Mehr RAM für Redis
```

### MinIO Bucket-Name

```yaml
minio_harbor_bucket: "my-custom-bucket"
```

## Wartung und Updates

### PostgreSQL-Backup erstellen

```bash
ansible harbor_data -i inventory/harbor.yml -b -a \
  "sudo -u postgres pg_dump harbor > /tmp/harbor_backup.sql"
```

### Redis-Daten anzeigen

```bash
ansible harbor_data -i inventory/harbor.yml -b -a \
  "redis-cli -a YOUR_PASSWORD INFO"
```

### MinIO-Status prüfen

```bash
# MinIO Console öffnen
# http://<harbor-data-ip>:9001
```

## Troubleshooting

### Ansible-Verbindung schlägt fehl

```bash
# SSH-Konfiguration prüfen
ssh -v rocky@<harbor-data-ip>

# Ansible-Verbindung debuggen
ansible -i inventory/harbor.yml harbor_data -m ping -vvv
```

### PostgreSQL startet nicht

```bash
# Logs prüfen
ansible harbor_data -i inventory/harbor.yml -b -a \
  "journalctl -u postgresql-16 -n 50"
```

### Redis-Verbindung fehlschlägt

```bash
# Firewall prüfen
ansible harbor_data -i inventory/harbor.yml -b -a \
  "firewall-cmd --list-ports"

# Redis-Status prüfen
ansible harbor_data -i inventory/harbor.yml -b -a \
  "systemctl status redis"
```

### MinIO startet nicht

```bash
# MinIO-Logs prüfen
ansible harbor_data -i inventory/harbor.yml -b -a \
  "journalctl -u minio -n 50"

# Datenverzeichnis-Berechtigungen prüfen
ansible harbor_data -i inventory/harbor.yml -b -a \
  "ls -la /data/minio"
```

## Sicherheit

### Secrets-Management

**WICHTIG**: Niemals Passwörter im Klartext committen!

```bash
# Vault-Datei erstellen und verschlüsseln
ansible-vault create group_vars/harbor_data/vault.yml

# Vault-Datei bearbeiten
ansible-vault edit group_vars/harbor_data/vault.yml

# Vault-Passwort ändern
ansible-vault rekey group_vars/harbor_data/vault.yml
```

### Best Practices

1. **SSH-Keys**: Nur Key-basierte Authentifizierung
2. **Firewall**: Nur notwendige Ports öffnen
3. **SELinux**: Immer auf Enforcing lassen
4. **Updates**: Regelmäßig System-Updates durchführen
5. **Backups**: Automatische Backups für PostgreSQL einrichten

## Compliance

Diese Ansible-Konfiguration erfüllt:

- **BSI IT-Grundschutz**: SYS.1.1 (Server), APP.4.3 (DBMS)
- **ISO/IEC 27001**: A.12 (Operations Security)
- **CIS Benchmarks**: Rocky Linux 9 Hardening

## Nächste Schritte

Nach erfolgreicher Data-VM-Konfiguration:

1. Harbor Core VMs konfigurieren (harbor-01, harbor-02)
2. Harbor-Installation via Docker Compose / Podman
3. HAProxy/Nginx Load Balancer einrichten
4. TLS-Zertifikate installieren
5. Monitoring mit Prometheus/Grafana

## Support und Mitwirkung

Bei Fragen oder Problemen:

1. Issues im Repository erstellen
2. Logs mit `journalctl` sammeln
3. Ansible-Output mit `-vvv` debuggen

## Lizenz

MIT License - siehe LICENSE-Datei
