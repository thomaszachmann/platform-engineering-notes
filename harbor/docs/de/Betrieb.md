# Harbor Betrieb

## Automatisierte Installation mit Ansible

### Voraussetzungen

**Ansible Control Node:**
- Ansible 2.15 oder höher
- Python 3.9+
- SSH-Zugriff auf Ziel-VMs

**Ziel-VMs:**
- Rocky Linux 9 (minimal Installation)
- Root-Zugriff oder sudo-Berechtigungen
- Mindestens 4 CPU Cores, 8 GB RAM, 100 GB Disk

### Ansible Inventory

```yaml
# inventory/harbor.yml
all:
  children:
    harbor_nodes:
      hosts:
        harbor01.example.com:
          ansible_host: 10.0.20.11
          harbor_role: primary
        harbor02.example.com:
          ansible_host: 10.0.20.12
          harbor_role: secondary
      vars:
        ansible_user: ansible
        ansible_become: true

    harbor_db:
      hosts:
        postgres01.example.com:
          ansible_host: 10.0.30.21
        postgres02.example.com:
          ansible_host: 10.0.30.22

    harbor_storage:
      hosts:
        minio01.example.com:
          ansible_host: 10.0.30.31
        minio02.example.com:
          ansible_host: 10.0.30.32

  vars:
    # Harbor Configuration
    harbor_version: "2.10.0"
    harbor_hostname: "harbor.example.com"
    harbor_admin_password: !vault |
      $ANSIBLE_VAULT;1.1;AES256
      ...

    # TLS Configuration
    harbor_tls_cert_path: "/etc/harbor/ssl/{{ harbor_hostname }}.crt"
    harbor_tls_key_path: "/etc/harbor/ssl/{{ harbor_hostname }}.key"

    # External Database
    harbor_db_host: "postgres.example.com"
    harbor_db_port: 5432
    harbor_db_name: "harbor"
    harbor_db_user: "harbor"
    harbor_db_password: !vault |
      $ANSIBLE_VAULT;1.1;AES256
      ...

    # External Storage (S3/MinIO)
    harbor_storage_backend: "s3"
    harbor_s3_endpoint: "https://minio.example.com:9000"
    harbor_s3_bucket: "harbor-registry"
    harbor_s3_access_key: !vault |
      $ANSIBLE_VAULT;1.1;AES256
      ...
    harbor_s3_secret_key: !vault |
      $ANSIBLE_VAULT;1.1;AES256
      ...

    # Redis Configuration
    harbor_redis_host: "redis.example.com"
    harbor_redis_port: 6379
    harbor_redis_password: !vault |
      $ANSIBLE_VAULT;1.1;AES256
      ...
```

### Ansible Playbook Struktur

```
harbor-ansible/
├── inventory/
│   └── harbor.yml
├── group_vars/
│   ├── all.yml
│   └── harbor_nodes.yml
├── roles/
│   ├── common/
│   │   └── tasks/
│   │       └── main.yml
│   ├── podman/
│   │   └── tasks/
│   │       └── main.yml
│   ├── harbor/
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   ├── templates/
│   │   │   ├── harbor.yml.j2
│   │   │   └── docker-compose.yml.j2
│   │   └── handlers/
│   │       └── main.yml
│   └── monitoring/
│       └── tasks/
│           └── main.yml
├── playbooks/
│   ├── site.yml
│   ├── deploy-harbor.yml
│   └── update-harbor.yml
└── ansible.cfg
```

### Hauptplaybook

```yaml
# playbooks/site.yml
---
- name: Prepare Harbor Infrastructure
  hosts: all
  roles:
    - common

- name: Install and Configure PostgreSQL
  hosts: harbor_db
  roles:
    - postgresql

- name: Install and Configure MinIO
  hosts: harbor_storage
  roles:
    - minio

- name: Deploy Harbor
  hosts: harbor_nodes
  roles:
    - podman
    - harbor
    - monitoring
```

### Harbor-Rolle: Tasks

```yaml
# roles/harbor/tasks/main.yml
---
- name: Create Harbor directories
  file:
    path: "{{ item }}"
    state: directory
    mode: '0755'
  loop:
    - /opt/harbor
    - /etc/harbor
    - /etc/harbor/ssl
    - /var/log/harbor

- name: Download Harbor installer
  get_url:
    url: "https://github.com/goharbor/harbor/releases/download/v{{ harbor_version }}/harbor-offline-installer-v{{ harbor_version }}.tgz"
    dest: "/tmp/harbor-installer.tgz"
    checksum: "sha256:{{ harbor_checksum }}"

- name: Extract Harbor installer
  unarchive:
    src: "/tmp/harbor-installer.tgz"
    dest: "/opt"
    remote_src: yes

- name: Copy TLS certificates
  copy:
    src: "{{ item.src }}"
    dest: "{{ item.dest }}"
    mode: '0600'
  loop:
    - { src: "{{ harbor_tls_cert_local }}", dest: "{{ harbor_tls_cert_path }}" }
    - { src: "{{ harbor_tls_key_local }}", dest: "{{ harbor_tls_key_path }}" }

- name: Generate harbor.yml from template
  template:
    src: harbor.yml.j2
    dest: /opt/harbor/harbor.yml
    mode: '0644'
  notify: Reconfigure Harbor

- name: Run Harbor installer
  command: /opt/harbor/install.sh --with-trivy --with-chartmuseum
  args:
    chdir: /opt/harbor
    creates: /opt/harbor/harbor.yml.bak

- name: Create systemd service for Harbor
  template:
    src: harbor.service.j2
    dest: /etc/systemd/system/harbor.service
    mode: '0644'
  notify:
    - Reload systemd
    - Restart Harbor

- name: Enable and start Harbor service
  systemd:
    name: harbor
    enabled: yes
    state: started

- name: Configure firewalld
  firewalld:
    port: "{{ item }}"
    permanent: yes
    state: enabled
    immediate: yes
  loop:
    - 443/tcp
    - 80/tcp

- name: Install Harbor CLI tools
  get_url:
    url: "https://github.com/goharbor/harbor-cli/releases/latest/download/harbor-cli-linux-amd64"
    dest: /usr/local/bin/harbor-cli
    mode: '0755'
```

### Harbor-Konfiguration Template

```yaml
# roles/harbor/templates/harbor.yml.j2
hostname: {{ harbor_hostname }}

# HTTPS configuration
https:
  port: 443
  certificate: {{ harbor_tls_cert_path }}
  private_key: {{ harbor_tls_key_path }}

# Harbor admin password
harbor_admin_password: {{ harbor_admin_password }}

# External database (PostgreSQL)
database:
  type: external
  external:
    host: {{ harbor_db_host }}
    port: {{ harbor_db_port }}
    db_name: {{ harbor_db_name }}
    username: {{ harbor_db_user }}
    password: {{ harbor_db_password }}
    ssl_mode: require
    max_idle_conns: 100
    max_open_conns: 900

# External storage (S3/MinIO)
storage_service:
  s3:
    accesskey: {{ harbor_s3_access_key }}
    secretkey: {{ harbor_s3_secret_key }}
    region: us-east-1
    regionendpoint: {{ harbor_s3_endpoint }}
    bucket: {{ harbor_s3_bucket }}
    encrypt: false
    secure: true
    skipverify: false
    v4auth: true

# External Redis
external_redis:
  host: {{ harbor_redis_host }}:{{ harbor_redis_port }}
  password: {{ harbor_redis_password }}
  registry_db_index: 1
  jobservice_db_index: 2
  trivy_db_index: 5

# Log configuration
log:
  level: info
  local:
    rotate_count: 50
    rotate_size: 200M
    location: /var/log/harbor

# Authentication
auth_mode: ldap_auth
ldap:
  url: ldaps://ldap.example.com
  search_dn: cn=harbor,ou=services,dc=example,dc=com
  search_password: {{ ldap_password }}
  base_dn: ou=users,dc=example,dc=com
  uid: uid
  filter: (objectClass=person)
  scope: 2
  timeout: 5

# Vulnerability scanning
trivy:
  ignore_unfixed: false
  skip_update: false
  offline_scan: false
  insecure: false
  github_token: {{ trivy_github_token | default('') }}

# Metrics for Prometheus
metric:
  enabled: true
  port: 9090
  path: /metrics
```

### Deployment-Prozess

```bash
# 1. Secrets verschlüsseln
ansible-vault encrypt_string 'mein_sicheres_passwort' --name 'harbor_admin_password'

# 2. Syntax-Check
ansible-playbook -i inventory/harbor.yml playbooks/site.yml --syntax-check

# 3. Dry-Run
ansible-playbook -i inventory/harbor.yml playbooks/site.yml --check

# 4. Deployment auf ein Node (Testen)
ansible-playbook -i inventory/harbor.yml playbooks/site.yml --limit harbor01.example.com

# 5. Full Deployment
ansible-playbook -i inventory/harbor.yml playbooks/site.yml --ask-vault-pass

# 6. Verify Installation
ansible harbor_nodes -i inventory/harbor.yml -m shell -a "podman ps"
```

## Laufender Betrieb

### Tägliche Aufgaben

**Automatisiert:**
- Log-Rotation (systemd-timer)
- Backup PostgreSQL (Cronjob)
- Vulnerability-Scans (Harbor Scheduler)

**Manuell:**
- Monitoring-Dashboard prüfen
- Alerts reviewen

### Wöchentliche Aufgaben

- Disk-Usage prüfen
- Update-Status prüfen
- Security-Scan-Reports reviewen
- User/Projekt-Anfragen bearbeiten

### Monatliche Aufgaben

- Backup-Restore testen
- Security-Patches anwenden
- Performance-Metriken analysieren
- Kapazitätsplanung

### Update-Prozess

```yaml
# playbooks/update-harbor.yml
---
- name: Update Harbor to new version
  hosts: harbor_nodes
  serial: 1  # Ein Node nach dem anderen
  tasks:
    - name: Stop Harbor
      systemd:
        name: harbor
        state: stopped

    - name: Backup current installation
      archive:
        path: /opt/harbor
        dest: "/backup/harbor-backup-{{ ansible_date_time.iso8601 }}.tar.gz"

    - name: Download new Harbor version
      get_url:
        url: "https://github.com/goharbor/harbor/releases/download/v{{ new_harbor_version }}/harbor-offline-installer-v{{ new_harbor_version }}.tgz"
        dest: "/tmp/harbor-installer-new.tgz"

    - name: Extract new version
      unarchive:
        src: "/tmp/harbor-installer-new.tgz"
        dest: "/opt"
        remote_src: yes

    - name: Migrate data
      command: /opt/harbor/install.sh --with-trivy --with-chartmuseum
      args:
        chdir: /opt/harbor

    - name: Start Harbor
      systemd:
        name: harbor
        state: started

    - name: Wait for Harbor to be healthy
      uri:
        url: "https://{{ harbor_hostname }}/api/v2.0/health"
        status_code: 200
      register: result
      until: result.status == 200
      retries: 30
      delay: 10
```

### Troubleshooting

**Harbor startet nicht:**
```bash
# Logs prüfen
journalctl -u harbor -f

# Container-Status
podman ps -a

# Harbor-Logs
tail -f /var/log/harbor/registry.log
tail -f /var/log/harbor/core.log
```

**Performance-Probleme:**
```bash
# PostgreSQL Connections
psql -h postgres.example.com -U harbor -c "SELECT count(*) FROM pg_stat_activity;"

# Redis-Statistiken
redis-cli -h redis.example.com INFO stats

# Disk I/O
iostat -x 1
```

**Image-Push schlägt fehl:**
```bash
# Storage-Backend prüfen
aws s3 ls s3://harbor-registry/ --endpoint-url https://minio.example.com:9000

# Netzwerk-Verbindung
curl -v https://minio.example.com:9000
```

### Monitoring-Integration

**Prometheus Scrape Config:**
```yaml
scrape_configs:
  - job_name: 'harbor'
    static_configs:
      - targets:
        - harbor01.example.com:9090
        - harbor02.example.com:9090
    metrics_path: /metrics
```

**Grafana Dashboard:**
- Harbor Registry Operations
- Storage Usage Trends
- Image Pull/Push Rates
- Vulnerability Scan Results

### Backup-Automation

```yaml
# roles/backup/tasks/main.yml
- name: Create backup script
  template:
    src: harbor-backup.sh.j2
    dest: /usr/local/bin/harbor-backup.sh
    mode: '0750'

- name: Schedule daily backups
  cron:
    name: "Harbor PostgreSQL Backup"
    minute: "30"
    hour: "2"
    job: "/usr/local/bin/harbor-backup.sh"
    user: root
```

## Disaster Recovery

### Szenario 1: Single Node Failure

**Detection:**
- Load Balancer markiert Node als unhealthy
- Monitoring-Alert

**Recovery:**
```bash
# Automatisch: Load Balancer routet Traffic zu verbleibendem Node
# Manuell: Node neu deployen
ansible-playbook -i inventory/harbor.yml playbooks/deploy-harbor.yml --limit harbor01.example.com
```

**RTO:** < 30 Minuten

### Szenario 2: Komplettausfall

**Detection:**
- Alle Harbor-Nodes down
- Monitoring-Alert

**Recovery:**
```bash
# 1. Infrastructure wiederherstellen (VMs)
# 2. PostgreSQL-Backup einspielen
pg_restore -h postgres.example.com -U harbor -d harbor /backup/harbor-db-latest.dump

# 3. Harbor neu deployen
ansible-playbook -i inventory/harbor.yml playbooks/site.yml

# 4. Verification
curl -k https://harbor.example.com/api/v2.0/health
```

**RTO:** < 4 Stunden

## Betriebskosten

**Personal (pro Jahr):**
- Initiales Setup: ~40 Stunden
- Laufender Betrieb: ~40 Stunden/Jahr
- Updates/Patches: ~20 Stunden/Jahr

**GESAMT: ~100 Stunden/Jahr** (ca. 2 Stunden/Woche)

**Infrastruktur:**
- 2× Harbor-VMs: 4 vCPU, 8 GB RAM
- 1× PostgreSQL-HA: 2× VMs (4 vCPU, 16 GB RAM)
- 1× MinIO-Cluster: 2× VMs (4 vCPU, 8 GB RAM) + Storage
- 1× Redis: 2 vCPU, 4 GB RAM

**Lizenzkosten:**
- Harbor: Open Source (kostenlos)
- Rocky Linux: Kostenlos
- Podman: Kostenlos

## Verantwortlichkeiten

| Aufgabe | Rolle | Frequenz |
|---------|-------|----------|
| Monitoring prüfen | DevOps | Täglich |
| Backups verifizieren | DevOps | Wöchentlich |
| Updates anwenden | DevOps | Monatlich |
| User-Management | DevOps/Team Leads | Nach Bedarf |
| Security-Audits | Security Team | Quartalsweise |
| Kapazitätsplanung | DevOps Lead | Quartalsweise |
