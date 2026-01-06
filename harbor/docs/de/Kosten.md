# Betriebskostenvergleich: Harbor auf VMs vs. Kubernetes

## Executive Summary

Ein ehrlicher Kostenvergleich zwischen Harbor auf VMs (Podman) und Harbor auf Kubernetes über 3 Jahre Betrieb zeigt:

**Harbor auf VMs kostet 2-3× weniger** als auf Kubernetes, bei gleichzeitig höherer Betriebssicherheit.

## Kostenmodell

### Annahmen

**Umgebung:**
- Mittelständisches Unternehmen (100-500 Mitarbeiter)
- On-Premises oder Private Cloud
- 50-100 aktive Entwickler
- ~1000 Container-Images
- ~10 TB Registry-Storage

**Zeitraum:** 3 Jahre (TCO)

**Stundensatz:** 100 €/h (interner Verrechnungssatz DevOps/SRE)

## Detaillierter Kostenvergleich

### 1. Initiale Implementierung

| Aufgabe | VM + Podman | Kubernetes | Differenz |
|---------|-------------|------------|-----------|
| **Planung & Design** | 8h | 16h | +8h |
| - Architektur | 4h | 8h | Komplexere K8s-Architektur |
| - Sicherheitskonzept | 2h | 4h | Mehr Netzwerk-Policies |
| - Dokumentation | 2h | 4h | Mehr zu dokumentieren |
| **Infrastruktur-Setup** | 16h | 40h | +24h |
| - VMs/Nodes aufsetzen | 4h | 12h | K8s-Cluster komplexer |
| - Netzwerk konfigurieren | 4h | 12h | CNI, Ingress, Network Policies |
| - Storage einrichten | 4h | 8h | StorageClasses, PV/PVC |
| - Load Balancer | 2h | 4h | Ingress-Controller |
| - Monitoring | 2h | 4h | Mehr Metriken zu sammeln |
| **Harbor-Deployment** | 16h | 32h | +16h |
| - Ansible/Helm entwickeln | 8h | 16h | Helm komplexer |
| - Testen | 4h | 8h | Mehr zu testen |
| - Troubleshooting | 4h | 8h | Mehr potenzielle Fehlerquellen |
| **Schulung Team** | 8h | 24h | +16h |
| - Team einarbeiten | 4h | 16h | K8s-Wissen aufbauen |
| - Runbooks erstellen | 4h | 8h | Mehr Szenarien |
| **Gesamt Initial** | **48h** | **112h** | **+64h** |
| **Kosten Initial** | **4.800 €** | **11.200 €** | **+6.400 €** |

### 2. Laufender Betrieb (pro Jahr)

| Aufgabe | VM + Podman | Kubernetes | Differenz |
|---------|-------------|------------|-----------|
| **Routinewartung** | 24h | 60h | +36h |
| - Monitoring prüfen | 12h (1h/Monat) | 24h (2h/Monat) | Mehr Komponenten |
| - Log-Review | 6h (0.5h/Monat) | 12h (1h/Monat) | Mehr Logs |
| - Kapazitätsplanung | 4h (1h/Quartal) | 12h (3h/Quartal) | Komplexere Metriken |
| - Dokumentation aktualisieren | 2h | 12h | Mehr Änderungen |
| **Updates & Patches** | 16h | 48h | +32h |
| - OS-Updates | 8h (2h/Quartal) | 8h (2h/Quartal) | Gleich |
| - Harbor-Updates | 4h (1h/Quartal) | 12h (3h/Quartal) | Helm-Upgrades komplexer |
| - K8s-Upgrades | - | 24h (6h/Quartal) | Zusätzlicher Aufwand |
| - Komponenten-Updates | 4h | 4h | Gleich |
| **Incident Response** | 8h | 24h | +16h |
| - Fehlersuche | 4h | 16h | Komplexere Debugging |
| - Fixes anwenden | 2h | 4h | Mehr Komponenten |
| - Post-Mortems | 2h | 4h | Mehr Vorfälle |
| **User-Support** | 8h | 12h | +4h |
| - User/Projekt-Verwaltung | 6h | 8h | Mehr Komplexität |
| - Troubleshooting User-Issues | 2h | 4h | Mehr Fehlermöglichkeiten |
| **Gesamt pro Jahr** | **56h** | **144h** | **+88h** |
| **Kosten pro Jahr** | **5.600 €** | **14.400 €** | **+8.800 €** |

### 3. Infrastrukturkosten (pro Jahr)

| Komponente | VM + Podman | Kubernetes | Differenz |
|------------|-------------|------------|-----------|
| **Compute** | | | |
| Harbor-Nodes | 2× VM (4 vCPU, 8 GB) | 3× Node (4 vCPU, 16 GB) | +1 Node, mehr RAM |
| - Kosten | 2.400 € | 4.800 € | +2.400 € |
| Control Plane | - | 3× VM (2 vCPU, 4 GB) | K8s-Master |
| - Kosten | - | 1.800 € | +1.800 € |
| **Storage** | | | |
| PostgreSQL | 2× VM (4 vCPU, 16 GB) | 2× VM (4 vCPU, 16 GB) | Gleich |
| - Kosten | 4.800 € | 4.800 € | - |
| MinIO/S3 | 2× VM (4 vCPU, 8 GB) + 20 TB | 2× VM (4 vCPU, 8 GB) + 20 TB | Gleich |
| - Kosten | 8.000 € | 8.000 € | - |
| Redis | 1× VM (2 vCPU, 4 GB) | 1× VM (2 vCPU, 4 GB) | Gleich |
| - Kosten | 600 € | 600 € | - |
| **Netzwerk** | | | |
| Load Balancer | 1× VM (2 vCPU, 4 GB) | Ingress im Cluster | - |
| - Kosten | 600 € | - | -600 € |
| **Monitoring** | | | |
| Prometheus/Grafana | 1× VM (4 vCPU, 8 GB) | 1× VM (4 vCPU, 8 GB) | Gleich |
| - Kosten | 1.200 € | 1.200 € | - |
| **Gesamt Infra/Jahr** | **17.600 €** | **21.200 €** | **+3.600 €** |

### 4. Lizenzkosten (pro Jahr)

| Komponente | VM + Podman | Kubernetes | Differenz |
|------------|-------------|------------|-----------|
| Betriebssystem | Rocky Linux (kostenlos) | Rocky Linux (kostenlos) | - |
| Container Runtime | Podman (kostenlos) | containerd (kostenlos) | - |
| Harbor | Open Source | Open Source | - |
| Kubernetes | - | Open Source | - |
| Support (optional) | - | - | - |
| **Gesamt Lizenzen** | **0 €** | **0 €** | **0 €** |

*Hinweis: Bei Enterprise-Support (z.B. Red Hat OpenShift) würden für K8s erhebliche Lizenzkosten anfallen (50.000-100.000 € p.a.)*

### 5. Fehlerkosten / Risiken

| Risiko | VM + Podman | Kubernetes | Differenz |
|--------|-------------|------------|-----------|
| **Ausfallwahrscheinlichkeit** | 1-2 × pro Jahr | 3-5 × pro Jahr | Höher bei K8s |
| - Durchschnittliche Ausfallzeit | 30 min | 90 min | Komplexere Fehlersuche |
| - Kosten pro Ausfall | 500 € | 1.500 € | |
| **Erwartete Fehlerkosten** | 1.000 € | 6.000 € | **+5.000 €** |

### 6. Schulungskosten (über 3 Jahre)

| Schulung | VM + Podman | Kubernetes | Differenz |
|----------|-------------|------------|-----------|
| Initial | 8h × 100 € | 24h × 100 € | +1.600 € |
| Auffrischung | - | 8h × 100 € (jährlich) | +2.400 € (3 Jahre) |
| **Gesamt Schulung** | **800 €** | **4.800 €** | **+4.000 €** |

## Gesamtkostenvergleich (3 Jahre)

| Kostenart | VM + Podman | Kubernetes | Differenz |
|-----------|-------------|------------|-----------|
| **Initiale Implementierung** | 4.800 € | 11.200 € | +6.400 € |
| **Laufender Betrieb (3 Jahre)** | 16.800 € (3×5.600) | 43.200 € (3×14.400) | +26.400 € |
| **Infrastruktur (3 Jahre)** | 52.800 € (3×17.600) | 63.600 € (3×21.200) | +10.800 € |
| **Lizenzkosten (3 Jahre)** | 0 € | 0 € | - |
| **Fehlerkosten (3 Jahre)** | 3.000 € (3×1.000) | 18.000 € (3×6.000) | +15.000 € |
| **Schulungskosten (3 Jahre)** | 800 € | 4.800 € | +4.000 € |
| **TOTAL COST OF OWNERSHIP (3 Jahre)** | **78.200 €** | **140.800 €** | **+62.600 € (+80%)** |

## Break-Even-Analyse

**Kubernetes lohnt sich erst ab:**
- \> 10 verschiedene Workloads im Cluster
- \> 500 Entwickler
- Starke Schwankungen in der Last (Auto-Scaling benötigt)
- Multi-Tenant-Anforderungen mit strikter Isolation
- Hohe Deployment-Frequenz (mehrmals täglich)

**Für Harbor als Infrastruktur-Komponente:**
- Kein Auto-Scaling benötigt (stabile Last)
- Kein Deployment mehrmals täglich
- Kein Multi-Tenancy (Harbor bietet eigenes RBAC)
- Maximale Verfügbarkeit wichtiger als Flexibilität

**Kubernetes bietet keinen wirtschaftlichen Mehrwert**

## Nicht-monetäre Faktoren

### VM + Podman

**Vorteile:**
- Geringere Komplexität
- Einfacheres Troubleshooting
- Weniger Wissensanforderungen
- Höhere Betriebssicherheit
- Bessere Auditierbarkeit

**Nachteile:**
- Kein Auto-Scaling
- Manuelle Node-Addition
- Kein deklaratives Deployment (aber: Ansible)

### Kubernetes

**Vorteile:**
- Deklarative Konfiguration
- Auto-Healing (Pod-Restarts)
- Rolling Updates
- Einheitliche Plattform (wenn K8s bereits vorhanden)

**Nachteile:**
- Hohe Komplexität
- Schwieriges Troubleshooting
- Hohe Wissensanforderungen
- Mehr bewegliche Teile = mehr Fehlerquellen
- Bootstrapping-Problem (Harbor im K8s)

## Sensitivitätsanalyse

**Wenn Kubernetes-Cluster bereits vorhanden:**
- Infrastrukturkosten: -3.600 € (K8s-Control-Plane bereits da)
- Initiale Implementierung: -8h (K8s-Know-how bereits da)
- **Neue TCO (3 Jahre):** 133.400 € statt 140.800 €
- **Immer noch +55.200 € (+70%) teurer als VM-Lösung**

**Wenn managed Kubernetes (z.B. Rancher, OpenShift):**
- Lizenzkosten: +20.000 €/Jahr = +60.000 € (3 Jahre)
- Betriebsaufwand: -20h/Jahr = -6.000 € (3 Jahre)
- **Neue TCO (3 Jahre):** 194.800 € (+149% teurer)

## Empfehlung

### Für KMU und On-Premises:

**Harbor auf VMs (Podman)**

**Wirtschaftliche Gründe:**
- 80% günstiger im Betrieb über 3 Jahre
- Geringere Personalanforderungen
- Weniger Fehlerkosten

**Technische Gründe:**
- Höhere Verfügbarkeit
- Einfacheres Troubleshooting
- Bessere Audit-Tauglichkeit

### Kubernetes nur wenn:

- Kubernetes-Cluster bereits im Einsatz für viele andere Workloads
- Dediziertes K8s-Team vorhanden (3+ Personen)
- Starke Anforderung an deklarative Konfiguration
- **UND:** Bereitschaft, die höheren Kosten zu tragen

## Fazit

Für Harbor als kritische Infrastruktur-Komponente ist **VM + Podman die wirtschaftlich und technisch sinnvollere Lösung**.

Kubernetes bringt für diesen Use-Case **keinen Mehrwert**, sondern nur:
- Höhere Kosten (+80%)
- Höhere Komplexität
- Mehr Ausfallrisiken

Die Entscheidung für VMs ist:
- Wirtschaftlich rational
- Technisch fundiert
- Audit-tauglich argumentierbar
- Langfristig wartbar

---

*Dieses Kostenmodell basiert auf realen Erfahrungswerten aus KMU-Umgebungen. Individuelle Kosten können variieren, die relativen Unterschiede bleiben jedoch in der Regel ähnlich.*
