# Harbor Architektur

## Überblick

Harbor wird als hochverfügbare Container-Registry auf dedizierten virtuellen Maschinen betrieben.

## Architekturentscheidung: VMs statt Kubernetes

### Warum VM-basiert?

Harbor ist kein transientes Workload, sondern **kritische Infrastruktur**:

- Zentrale Registry für alle Container-Images
- Muss immer verfügbar sein, auch wenn Kubernetes-Cluster ausfallen
- Bootstrapping-Problem: Wie startet man einen K8s-Cluster, wenn die Registry im Cluster liegt?

### Vorteile VM + Podman

| Aspekt | VM + Podman | Kubernetes |
|--------|-------------|------------|
| **Betriebssicherheit** | Sehr hoch - weniger bewegliche Teile | Mittel - viele Abhängigkeiten |
| **Auditierbarkeit** | Sehr hoch - klare Systemgrenzen | Mittel - komplexe Netzwerk-Policies |
| **Fehlersuche** | Einfach - klassische Systemd-Logs | Komplex - Pod-Logs, Events, etc. |
| **Personalbedarf** | Gering - Linux-Standardwissen | Hoch - K8s-Spezialwissen |
| **Vendor Lock-in** | Gering - portable | Mittel - K8s-spezifisch |

## Deployment-Architektur

### Active/Active Setup

```
┌─────────────────────────────────────────────────────┐
│                  Load Balancer                       │
│              (haproxy / nginx)                       │
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

### Komponenten

#### Harbor Nodes
- **Betriebssystem:** Rocky Linux 9 (minimal)
- **Container Runtime:** Podman 4.x
- **Harbor Version:** 2.x (aktuelle stable)
- **Konfiguration:** Identisch auf allen Nodes
- **Deployment:** Via Ansible

#### Shared State Services

**PostgreSQL:**
- HA-Cluster (Patroni + etcd) oder managed Service
- Speichert Harbor-Metadaten (Projekte, User, Tags)
- Backup: pg_dump täglich

**Object Storage (MinIO / S3):**
- Speichert Container-Images (Blobs)
- Versioning aktiviert
- Optional: Replikation zu Zweitstandort

**Redis:**
- Session-Management
- Job-Queue für Harbor
- Optional: Redis Sentinel für HA

### Netzwerkarchitektur

#### Netzwerksegmentierung

```
┌─────────────────────────────────────────────┐
│           Management Network                 │
│    (SSH, Ansible, Monitoring)               │
│         VLAN 10 - 10.0.10.0/24              │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│           Service Network                    │
│    (Harbor API/UI, Image Pull/Push)         │
│         VLAN 20 - 10.0.20.0/24              │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│           Backend Network                    │
│    (PostgreSQL, MinIO, Redis)               │
│         VLAN 30 - 10.0.30.0/24              │
└─────────────────────────────────────────────┘
```

#### Firewall-Regeln

**Harbor Nodes (Service Network):**
- TCP 443 (HTTPS) - eingehend von Clients
- TCP 80 (HTTP) - optional, Redirect zu 443

**Harbor Nodes (Backend Network):**
- TCP 5432 (PostgreSQL)
- TCP 9000 (MinIO/S3)
- TCP 6379 (Redis)

**Management Network:**
- TCP 22 (SSH) - nur von Jumphost
- TCP 9090 (Prometheus Exporter)

### Storage-Konzept

#### Lokaler Storage
- **/etc/harbor:** Konfiguration
- **/var/log/harbor:** Logs (Retention: 30 Tage)
- Kein lokaler Image-Storage (alles in S3/MinIO)

#### Shared Storage
- **PostgreSQL:** Dedizierte DB-VMs mit lokalen SSDs
- **MinIO/S3:** Dedizierte Storage-Nodes oder Cloud-S3

## Skalierung und Performance

### Horizontale Skalierung
- Weitere Harbor-Nodes hinter Load Balancer
- Session-State in Redis → stateless Harbor-Nodes
- Limitierender Faktor: PostgreSQL (vertikal skalieren oder Sharding)

### Performance-Tuning
- **Harbor:** Worker-Count in harbor.yml
- **PostgreSQL:** Connection Pooling (PgBouncer)
- **MinIO:** Distributed Mode für höheren Durchsatz
- **CDN:** Optional für häufig genutzte Images

## Backup und Disaster Recovery

### Backup-Strategie

**Metadaten (PostgreSQL):**
- Täglich: Full Backup (pg_dump)
- Retention: 30 Tage
- Test-Restore: Monatlich

**Images (S3/MinIO):**
- Versioning aktiviert
- Optional: Cross-Region Replication
- Wichtige Images: Zusätzlich auf Tape

**Konfiguration:**
- Ansible-Repository ist Single Source of Truth
- Tägliches Backup nach Git

### Recovery Time Objective (RTO)
- **Ziel:** < 4 Stunden
- **Node-Ausfall:** < 30 Minuten (automatisches Failover)
- **Komplettausfall:** < 4 Stunden (Restore aus Backup)

### Recovery Point Objective (RPO)
- **Metadaten:** < 24 Stunden
- **Images:** 0 (Versioning/Replikation)

## Monitoring und Alerting

### Metriken
- **Harbor:** Prometheus Exporter
- **PostgreSQL:** pg_exporter
- **MinIO:** Prometheus Endpoint
- **System:** node_exporter

### Alerts
- Harbor-Service down
- Disk-Usage > 80%
- PostgreSQL Connection Errors
- S3 Availability < 99%

## Technologie-Stack

| Komponente | Technologie | Version |
|------------|-------------|---------|
| Betriebssystem | Rocky Linux | 9.x |
| Container Runtime | Podman | 4.x |
| Harbor | Harbor | 2.x |
| Datenbank | PostgreSQL | 14+ |
| Object Storage | MinIO / S3 | Latest Stable |
| Cache/Queue | Redis | 7.x |
| Load Balancer | HAProxy / nginx | Latest Stable |
| Automation | Ansible | 2.15+ |
| Monitoring | Prometheus + Grafana | Latest Stable |
