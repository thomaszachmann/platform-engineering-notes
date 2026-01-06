# Entscheidung: Harbor auf VMs (Podman) statt Kubernetes

## Executive Summary

Für den Betrieb einer hochverfügbaren Container-Registry wird Harbor auf dedizierten virtuellen Maschinen betrieben.
Diese Architektur bietet maximale Stabilität, geringe Betriebskomplexität und klare Verantwortlichkeiten, insbesondere in On-Prem- und KMU-Umgebungen.

## Begründung

- Harbor ist kein transientes Workload, sondern **kritische Infrastruktur**
- Kubernetes erhöht Komplexität, ohne funktionalen Mehrwert

### VM-basierter Betrieb:

- reduziert Ausfallrisiken
- vereinfacht Audits
- senkt Betriebskosten

## Entscheidungskriterien

| Kriterium | VM + Podman | Kubernetes |
|-----------|-------------|------------|
| Betriebssicherheit | sehr hoch | mittel |
| Auditierbarkeit | sehr hoch | mittel |
| Fehlersuche | einfach | komplex |
| Personalbedarf | gering | hoch |
| Vendor Lock-in | gering | mittel |

### Fazit

👉 Für diesen Kunden ist VM + Podman die wirtschaftlich und technisch sinnvollere Lösung.

# BSI- / ISO-konformes Setup (praxisnah)

## Relevante Normen

- ISO/IEC 27001
- BSI IT-Grundschutz (OPS.1, SYS.1, APP.4)

## Technische Maßnahmen

### Systemhärtung

- Minimalinstallation (Rocky Linux 9)
- SELinux enforcing
- Firewalld mit Whitelisting
- Keine Root-Logins per SSH

### Zugriff & Authentifizierung

**Harbor:**
- LDAP / OIDC
- RBAC pro Projekt

**PostgreSQL:**
- eigener DB-User
- kein Remote-Superuser

**MinIO:**
- getrennte Access Keys

### Netzwerk

**Getrennte Netze:**
- Management
- Service

**TLS für:**
- Harbor
- DB
- S3 (intern oder extern)

### Backup & Recovery

- **PostgreSQL:** pg_dump (täglich)
- **MinIO:** Versioning + Mirror
- **VM-Backups:** ohne laufende DB-Snapshots

---

✔ Audit-Statement-tauglich
✔ BSI-konform argumentierbar


# Betriebskostenvergleich (ehrlich gerechnet)

## Beispiel: 3 Jahre Betrieb

| Kostenfaktor | VM + Podman | Kubernetes |
|--------------|-------------|------------|
| VMs / Nodes | niedrig | hoch |
| Betrieb (h/Jahr) | ~40 h | ~120 h |
| Schulung | gering | hoch |
| Fehlerkosten | gering | mittel |
| Komplexitätsrisiko | gering | hoch |

## Fazit (wirtschaftlich)

Kubernetes kostet im Betrieb **2–3× mehr**, ohne dass Harbor davon nennenswert profitiert.

---

# Klare Empfehlung

## Wir empfehlen:

- Harbor auf dedizierten VMs
- Active/Active Architektur
- Externe State-Services
- Vollautomatisiertes Provisioning
- BSI-/ISO-konformes Betriebsmodell

## Das ist:

✔ technisch sauber
✔ wirtschaftlich sinnvoll
✔ langfristig wartbar