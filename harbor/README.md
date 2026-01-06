# Harbor auf VMs: Entscheidungsgrundlage und Implementierung

## Executive Summary

Für den Betrieb einer hochverfügbaren Container-Registry wird Harbor auf dedizierten virtuellen Maschinen betrieben.
Diese Architektur bietet maximale Stabilität, geringe Betriebskomplexität und klare Verantwortlichkeiten, insbesondere in On-Prem- und KMU-Umgebungen.

## Begründung

- Harbor ist kein transientes Workload, sondern **kritische Infrastruktur**
- Kubernetes erhöht Komplexität, ohne funktionalen Mehrwert

### VM-basierter Betrieb:

- reduziert Ausfallrisiken
- vereinfacht Audits
- senkt Betriebskosten (80% günstiger als Kubernetes über 3 Jahre)

## Dokumentation

Diese README bietet einen Überblick. Für detaillierte Informationen siehe:

### Deutsche Dokumentation

**[Architektur](docs/de/Architektur.md)**
- Architekturentscheidung: VMs vs. Kubernetes
- Active/Active Deployment-Architektur
- Netzwerksegmentierung
- Technologie-Stack
- Monitoring und Backup-Strategie

**[Betrieb](docs/de/Betrieb.md)**
- Automatisierte Installation mit Ansible
- Ansible Inventory und Playbook-Struktur
- Harbor-Deployment mit Podman
- Laufender Betrieb und Wartung
- Update-Prozeduren
- Troubleshooting-Guide
- Disaster Recovery

**[Sicherheit (ISO/BSI)](docs/de/Sicherheit_ISO_BSI.md)**
- ISO/IEC 27001 und BSI IT-Grundschutz Compliance
- Systemhärtung (SELinux, Firewalld, SSH)
- Zugriffskontrolle und RBAC
- LDAP/OIDC-Integration
- Netzwerksicherheit und TLS
- Vulnerability Management
- Logging, Monitoring und Auditing
- Backup und Recovery
- Audit-Checkliste

**[Kosten](docs/de/Kosten.md)**
- Detaillierter TCO-Vergleich (3 Jahre)
- Initiale Implementierung
- Laufende Betriebskosten
- Infrastrukturkosten
- Fehlerkosten und Risiken
- Break-Even-Analyse
- Sensitivitätsanalyse

### English Documentation

**[Overview](docs/en/Overview.md)**
- Architecture decision rationale
- Deployment with Ansible
- Security and compliance
- Operational costs
- Quick start guide

## Schnellübersicht

### Entscheidungskriterien

| Kriterium | VM + Podman | Kubernetes |
|-----------|-------------|------------|
| Betriebssicherheit | sehr hoch | mittel |
| Auditierbarkeit | sehr hoch | mittel |
| Fehlersuche | einfach | komplex |
| Personalbedarf | gering | hoch |
| Vendor Lock-in | gering | mittel |
| **Kosten (3 Jahre)** | **78.200 €** | **140.800 €** |

### Klare Empfehlung

Wir empfehlen:
- Harbor auf dedizierten VMs
- Active/Active Architektur
- Externe State-Services (PostgreSQL, MinIO, Redis)
- Vollautomatisiertes Provisioning mit Ansible
- BSI-/ISO-konformes Betriebsmodell

**Diese Lösung ist:**
- Technisch sauber
- Wirtschaftlich sinnvoll (80% günstiger als Kubernetes)
- Langfristig wartbar
- Audit-tauglich

## Quick Start

```bash
# 1. Repository klonen
git clone https://github.com/yourorg/harbor-ansible.git
cd harbor-ansible

# 2. Inventory konfigurieren
vim inventory/harbor.yml

# 3. Secrets verschlüsseln
ansible-vault create group_vars/all/vault.yml

# 4. Deployment starten
ansible-playbook -i inventory/harbor.yml playbooks/site.yml --ask-vault-pass

# 5. Installation verifizieren
curl -k https://harbor.example.com/api/v2.0/health
```

Detaillierte Installationsanleitung: siehe [Betrieb.md](docs/de/Betrieb.md)

## Technologie-Stack

| Komponente | Technologie | Version |
|------------|-------------|---------|
| Betriebssystem | Rocky Linux | 9.x |
| Container Runtime | Podman | 4.x |
| Harbor | Harbor | 2.x |
| Datenbank | PostgreSQL | 14+ |
| Object Storage | MinIO / S3 | Latest |
| Cache/Queue | Redis | 7.x |
| Automation | Ansible | 2.15+ |
| Monitoring | Prometheus + Grafana | Latest |

## Compliance

Diese Implementierung erfüllt die Anforderungen von:
- ISO/IEC 27001 (Information Security Management)
- BSI IT-Grundschutz (OPS.1, SYS.1, APP.4, NET.1)
- DSGVO (durch Logging, Zugriffskontrolle, Verschlüsselung)

Details: siehe [Sicherheit_ISO_BSI.md](docs/de/Sicherheit_ISO_BSI.md)

## Lizenz und Support

Alle verwendeten Komponenten sind Open Source:
- Harbor: Apache License 2.0
- Rocky Linux: Kostenlos
- Podman: Apache License 2.0
- PostgreSQL: PostgreSQL License
- MinIO: GNU AGPL v3.0

**Keine Lizenzkosten** für diese Lösung.