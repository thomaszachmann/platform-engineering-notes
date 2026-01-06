# Harbor Sicherheit nach ISO/IEC 27001 und BSI IT-Grundschutz

## Überblick

Dieses Dokument beschreibt die Sicherheitsmaßnahmen für Harbor gemäß ISO/IEC 27001 und BSI IT-Grundschutz, angepasst an die Anforderungen von KMU und On-Premises-Umgebungen.

## Relevante Normen und Bausteine

### ISO/IEC 27001:2022
- **A.8:** Asset Management
- **A.9:** Access Control
- **A.12:** Operations Security
- **A.13:** Communications Security
- **A.14:** System Acquisition, Development and Maintenance
- **A.17:** Business Continuity
- **A.18:** Compliance

### BSI IT-Grundschutz
- **OPS.1.1.2:** Ordnungsgemäße IT-Administration
- **SYS.1.1:** Allgemeiner Server
- **SYS.1.3:** Server unter Linux
- **APP.4.3:** Relationale Datenbanken
- **NET.1.1:** Netzarchitektur und -design
- **CON.3:** Datensicherungskonzept

## Systemhärtung

### Betriebssystem-Härtung (Rocky Linux 9)

#### Minimalinstallation
```bash
# Nur notwendige Pakete installieren
dnf group install "Minimal Install"
dnf install podman firewalld vim wget curl

# Unnötige Services deaktivieren
systemctl disable postfix
systemctl disable cups
```

#### SELinux
```bash
# SELinux im Enforcing-Modus
getenforce  # Muss "Enforcing" zurückgeben

# SELinux-Kontext für Harbor
semanage fcontext -a -t container_file_t "/opt/harbor(/.*)?"
restorecon -R /opt/harbor
```

**Audit-Anforderung:**
- SELinux muss auf "enforcing" stehen
- Ausnahmen nur dokumentiert mit Begründung

#### Firewalld-Konfiguration
```bash
# Default: Alles blocken, nur explizit erlauben
firewall-cmd --set-default-zone=drop

# Service-Zone für Harbor
firewall-cmd --permanent --new-zone=harbor-service
firewall-cmd --permanent --zone=harbor-service --add-service=https
firewall-cmd --permanent --zone=harbor-service --add-source=10.0.0.0/8

# Management-Zone (nur Jumphost)
firewall-cmd --permanent --new-zone=management
firewall-cmd --permanent --zone=management --add-service=ssh
firewall-cmd --permanent --zone=management --add-source=10.0.10.5/32

# Monitoring
firewall-cmd --permanent --zone=management --add-port=9090/tcp

firewall-cmd --reload
```

**Audit-Anforderung:**
- Firewall aktiv und korrekt konfiguriert
- Default-Policy: DROP
- Nur notwendige Ports offen

#### SSH-Härtung
```bash
# /etc/ssh/sshd_config
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
Protocol 2
X11Forwarding no
MaxAuthTries 3
LoginGraceTime 30
AllowUsers ansible admin-user
```

**Audit-Anforderung:**
- Root-Login deaktiviert
- Nur Key-basierte Authentifizierung
- Zugriff nur von Jumphost

### Kernel-Härtung

```bash
# /etc/sysctl.d/99-harbor-hardening.conf

# IP-Forwarding deaktivieren (nicht benötigt)
net.ipv4.ip_forward = 0

# SYN-Cookies gegen SYN-Flood
net.ipv4.tcp_syncookies = 1

# Source Routing deaktivieren
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# ICMP-Redirects ignorieren
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0

# Reverse Path Filtering
net.ipv4.conf.all.rp_filter = 1

# Log Martians
net.ipv4.conf.all.log_martians = 1

# IPv6 deaktivieren (falls nicht benötigt)
net.ipv6.conf.all.disable_ipv6 = 1

# Kernel-Pointer vor Lesezugriff schützen
kernel.kptr_restrict = 2

# Core Dumps einschränken
kernel.core_uses_pid = 1
fs.suid_dumpable = 0
```

## Zugriffskontrolle und Authentifizierung

### Harbor RBAC

```yaml
# Harbor Projekt-Rollen
Project Admin:
  - Vollzugriff auf Projekt
  - User-Management
  - Replikations-Policies

Project Maintainer:
  - Push/Pull Images
  - Tag-Management
  - Vulnerability-Scans

Developer:
  - Push/Pull Images
  - Eigene Tags löschen

Guest:
  - Nur Pull (read-only)
```

**Best Practices:**
- Least Privilege Principle
- Jedes Team hat eigenes Projekt
- Developer standardmäßig nur Developer-Rolle
- Admin-Accounts nur für designated Admins

### LDAP/OIDC-Integration

**LDAP-Konfiguration:**
```yaml
# harbor.yml
auth_mode: ldap_auth
ldap:
  url: ldaps://ldap.example.com:636
  search_dn: cn=harbor-service,ou=services,dc=example,dc=com
  search_password: <vault>
  base_dn: ou=users,dc=example,dc=com
  uid: uid
  filter: (&(objectClass=inetOrgPerson)(memberOf=cn=harbor-users,ou=groups,dc=example,dc=com))
  scope: 2
  timeout: 5
  verify_cert: true

# Gruppe-zu-Rolle Mapping
ldap_group_admin_dn: cn=harbor-admins,ou=groups,dc=example,dc=com
ldap_group_membership_attribute: memberOf
```

**OIDC-Konfiguration (alternativ):**
```yaml
auth_mode: oidc_auth
oidc:
  name: Keycloak
  endpoint: https://keycloak.example.com/realms/company
  client_id: harbor
  client_secret: <vault>
  groups_claim: groups
  admin_group: harbor-admins
  verify_cert: true
  auto_onboard: true
  user_claim: preferred_username
```

**Audit-Anforderung:**
- Zentrale Authentifizierung (kein lokaler Harbor-User außer Admin)
- TLS-verschlüsselte Verbindung zu LDAP/OIDC
- Gruppen-basierte Zugriffskontrolle

### PostgreSQL-Sicherheit

```bash
# Eigener DB-User für Harbor (kein Superuser)
CREATE USER harbor WITH PASSWORD '<secure-password>';
CREATE DATABASE harbor OWNER harbor;

# Verbindung nur von Harbor-Nodes
# /var/lib/pgsql/data/pg_hba.conf
hostssl harbor harbor 10.0.20.11/32 scram-sha-256
hostssl harbor harbor 10.0.20.12/32 scram-sha-256

# SSL erzwingen
ssl = on
ssl_cert_file = '/var/lib/pgsql/data/server.crt'
ssl_key_file = '/var/lib/pgsql/data/server.key'
ssl_ca_file = '/var/lib/pgsql/data/ca.crt'
```

**Audit-Anforderung:**
- Dedizierter DB-User (kein Superuser)
- Kein Remote-Superuser-Zugriff
- TLS-verschlüsselte Verbindungen
- Passwort-Rotation alle 90 Tage

### MinIO/S3-Sicherheit

```bash
# Separate Access Keys pro Service
mc admin user add myminio harbor-registry
mc admin policy attach myminio readwrite --user harbor-registry

# Bucket-Policy (least privilege)
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::harbor-registry/*",
        "arn:aws:s3:::harbor-registry"
      ]
    }
  ]
}

# TLS erzwingen
mc admin config set myminio api secure=on
```

**Audit-Anforderung:**
- Getrennte Access Keys pro Anwendung
- Bucket-Policies mit minimalen Berechtigungen
- TLS-verschlüsselte Verbindungen
- Access Key Rotation alle 90 Tage

## Netzwerksicherheit

### Netzwerksegmentierung

```
┌─────────────────────────────────────────────┐
│  External (untrusted)                        │
│  ↓                                           │
│  Firewall / Reverse Proxy                   │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  Service Network (VLAN 20)                   │
│  - Harbor UI/API (HTTPS)                     │
│  - Image Pull/Push                           │
│  Source: K8s-Cluster, Developer-Workstations│
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  Backend Network (VLAN 30)                   │
│  - PostgreSQL                                │
│  - MinIO/S3                                  │
│  - Redis                                     │
│  Source: nur Harbor-Nodes                    │
└──────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│  Management Network (VLAN 10)                │
│  - SSH (nur von Jumphost)                    │
│  - Monitoring (Prometheus)                   │
│  - Ansible                                   │
│  Source: nur Jumphost                        │
└─────────────────────────────────────────────┘
```

**Firewall-Regeln (exemplarisch):**

```bash
# Service Network → Harbor
ALLOW TCP 443 FROM 10.0.0.0/8 TO 10.0.20.11,10.0.20.12

# Harbor → PostgreSQL
ALLOW TCP 5432 FROM 10.0.20.11,10.0.20.12 TO 10.0.30.21,10.0.30.22

# Harbor → MinIO
ALLOW TCP 9000 FROM 10.0.20.11,10.0.20.12 TO 10.0.30.31,10.0.30.32

# Harbor → Redis
ALLOW TCP 6379 FROM 10.0.20.11,10.0.20.12 TO 10.0.30.40

# Management Network
ALLOW TCP 22 FROM 10.0.10.5 TO 10.0.20.11,10.0.20.12  # Nur Jumphost

# Default: DENY ALL
```

**Audit-Anforderung:**
- Getrennte Netzwerke für Management, Service, Backend
- Default-Policy: DENY
- Dokumentierte Firewall-Regeln

### TLS/SSL-Verschlüsselung

**Harbor (extern):**
```yaml
# TLS 1.2 minimum, TLS 1.3 bevorzugt
https:
  port: 443
  certificate: /etc/harbor/ssl/harbor.crt
  private_key: /etc/harbor/ssl/harbor.key

  # Strong Cipher Suites
  strong_ssl_ciphers: true
```

**PostgreSQL (intern):**
```bash
ssl = on
ssl_min_protocol_version = 'TLSv1.2'
ssl_prefer_server_ciphers = on
ssl_ciphers = 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384'
```

**MinIO (intern):**
```bash
mc admin config set myminio api tls_min_version=1.2
```

**Audit-Anforderung:**
- TLS für alle Verbindungen (extern + intern)
- Mindestens TLS 1.2
- Strong Cipher Suites
- Gültige Zertifikate von vertrauenswürdiger CA

## Logging und Monitoring

### Zentrale Log-Sammlung

```yaml
# Harbor-Logs nach Syslog
- name: Configure rsyslog for Harbor
  template:
    src: rsyslog-harbor.conf.j2
    dest: /etc/rsyslog.d/30-harbor.conf
  content: |
    # Harbor Logs
    $ModLoad imfile
    $InputFileName /var/log/harbor/core.log
    $InputFileTag harbor-core:
    $InputFileStateFile stat-harbor-core
    $InputFileSeverity info
    $InputRunFileMonitor

    # An zentrale Log-Server senden
    *.* @@syslog.example.com:514
```

**Zu loggenden Events:**
- Login-Versuche (erfolgreich + fehlgeschlagen)
- Admin-Aktionen (User-Anlage, Projekt-Erstellung)
- Image-Push/Pull
- Konfigurationsänderungen
- System-Fehler
- Security-Scan-Ergebnisse

**Audit-Anforderung:**
- Zentrale Log-Sammlung
- Log-Retention mindestens 90 Tage
- Geschützt vor unbefugter Änderung
- Regelmäßige Review

### Security Monitoring

**Prometheus Alerts:**
```yaml
groups:
  - name: harbor-security
    rules:
      - alert: HarborLoginFailures
        expr: rate(harbor_core_http_request_total{code="401"}[5m]) > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Hohe Anzahl fehlgeschlagener Logins"

      - alert: HarborVulnerableImages
        expr: harbor_project_vulnerabilities{severity="Critical"} > 0
        for: 1h
        labels:
          severity: critical
        annotations:
          summary: "Kritische Vulnerabilities in Images gefunden"

      - alert: HarborDiskUsageHigh
        expr: harbor_storage_usage_bytes / harbor_storage_total_bytes > 0.8
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Harbor Storage über 80% voll"
```

**Audit-Anforderung:**
- Monitoring für Security-Events
- Alerting bei Anomalien
- Dokumentierte Eskalation

## Vulnerability Management

### Image-Scanning

```yaml
# harbor.yml - Trivy-Konfiguration
trivy:
  ignore_unfixed: false
  skip_update: false
  offline_scan: false
  insecure: false
  severity: UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL

# Automatischer Scan bei Push
scanner:
  auto_scan: true

# Vulnerability-Policy
project_policies:
  - name: production
    prevent_vulnerable_images: true
    severity_threshold: HIGH
  - name: development
    prevent_vulnerable_images: false
```

**Best Practices:**
- Daily Scan aller Images
- Deployment-Gate: Keine Images mit HIGH/CRITICAL Vulnerabilities in Production
- Automatische Benachrichtigung an Projekt-Owners
- Quarterly Review aller Images

**Audit-Anforderung:**
- Aktiviertes Vulnerability-Scanning
- Dokumentierter Prozess für Remediation
- Nachweise über regelmäßige Scans

### Patch-Management

**OS-Updates:**
```bash
# Monatliches Patching-Fenster
# Automatische Security-Updates für Rocky Linux
dnf install dnf-automatic
systemctl enable --now dnf-automatic.timer

# /etc/dnf/automatic.conf
[commands]
upgrade_type = security
apply_updates = yes
```

**Harbor-Updates:**
- Quartalsweise Updates auf neueste Stable-Version
- Testinstallation vor Production-Rollout
- Rollback-Plan dokumentiert

**Audit-Anforderung:**
- Dokumentierter Patch-Management-Prozess
- Nachweis regelmäßiger Updates
- Emergency-Patching-Prozedur

## Backup und Recovery

### Backup-Anforderungen (ISO 27001 / BSI)

**PostgreSQL (Metadaten):**
```bash
#!/bin/bash
# /usr/local/bin/harbor-backup.sh

BACKUP_DIR=/backup/harbor-db
RETENTION_DAYS=30

# Full Backup
pg_dump -h postgres.example.com -U harbor -F c -b -v \
  -f "${BACKUP_DIR}/harbor-$(date +%Y%m%d-%H%M%S).dump" harbor

# Verschlüsselung
gpg --encrypt --recipient backup@example.com \
  "${BACKUP_DIR}/harbor-$(date +%Y%m%d-%H%M%S).dump"

# Alte Backups löschen
find ${BACKUP_DIR} -name "*.dump.gpg" -mtime +${RETENTION_DAYS} -delete

# Backup-Verification
pg_restore --list "${BACKUP_DIR}/harbor-$(date +%Y%m%d-%H%M%S).dump" > /dev/null
if [ $? -eq 0 ]; then
  echo "Backup erfolgreich verifiziert"
else
  echo "FEHLER: Backup korrupt!" | mail -s "Harbor Backup Failed" admin@example.com
fi
```

**MinIO/S3 (Images):**
- Versioning aktiviert
- Optional: Cross-Region-Replikation
- Lifecycle-Policy für alte Versionen

**Konfiguration:**
- Ansible-Repository (Git)
- Daily Commit + Push

**Audit-Anforderungen:**
- **RPO:** < 24 Stunden (Metadaten), 0 (Images via Versioning)
- **RTO:** < 4 Stunden
- Monatlicher Restore-Test dokumentiert
- Verschlüsselte Backups
- Geografisch getrennte Speicherung

## Compliance und Auditing

### Audit-Checkliste (ISO 27001)

- [ ] Asset-Inventory vollständig
- [ ] Zugriffskontrolle dokumentiert und umgesetzt
- [ ] Netzwerksegmentierung implementiert
- [ ] TLS für alle Verbindungen
- [ ] Zentrale Authentifizierung (LDAP/OIDC)
- [ ] Logging aktiviert und zentral gesammelt
- [ ] Backup-Strategie dokumentiert und getestet
- [ ] Patch-Management-Prozess etabliert
- [ ] Vulnerability-Scanning aktiv
- [ ] Incident-Response-Plan dokumentiert
- [ ] Business-Continuity-Plan getestet

### BSI IT-Grundschutz Mapping

| Baustein | Maßnahme | Status |
|----------|----------|--------|
| SYS.1.3 | OS-Härtung (SELinux, Firewall) | Umgesetzt |
| OPS.1.1.2 | Dokumentierte Admin-Prozesse | Umgesetzt |
| APP.4.3 | PostgreSQL-Härtung | Umgesetzt |
| NET.1.1 | Netzwerksegmentierung | Umgesetzt |
| CON.3 | Datensicherungskonzept | Umgesetzt |
| OPS.1.1.5 | Patch- und Änderungsmanagement | Umgesetzt |

### Dokumentationspflichten

**Betriebsdokumentation:**
- Architektur-Übersicht
- Netzwerkdiagramm
- Zugriffskontroll-Matrix
- Backup-Konzept
- Disaster-Recovery-Plan

**Change-Management:**
- Alle Änderungen dokumentiert (Git-Commits)
- Change-Approval für Production
- Rollback-Prozeduren

**Incident-Response:**
- Security-Incident-Kategorisierung
- Eskalationspfade
- Post-Incident-Review-Prozess

## Zusammenfassung

Diese Harbor-Installation erfüllt die Anforderungen von:

**ISO/IEC 27001** - Information Security Management
**BSI IT-Grundschutz** - OPS.1, SYS.1, APP.4, NET.1
**DSGVO** - Durch Logging, Zugriffskontrolle, Verschlüsselung

Die Umsetzung ist **audit-tauglich** und kann gegenüber Auditoren verteidigt werden.
