# Harbor Ansible Makefile
# Vereinfacht häufige Ansible-Operationen

.PHONY: help install ping deploy deploy-check vault-create vault-edit vault-view requirements

# Standard-Target
help:
	@echo "Harbor Ansible - Verfügbare Targets:"
	@echo ""
	@echo "  make install         - Ansible und Collections installieren"
	@echo "  make requirements    - Ansible Collections installieren"
	@echo "  make ping            - Verbindung zu allen Hosts testen"
	@echo "  make deploy          - Komplettes Deployment durchführen"
	@echo "  make deploy-check    - Deployment im Check-Mode (Dry-Run)"
	@echo "  make vault-create    - Neue Vault-Datei erstellen"
	@echo "  make vault-edit      - Vault-Datei bearbeiten"
	@echo "  make vault-view      - Vault-Datei anzeigen"
	@echo ""
	@echo "Tag-basierte Deployments:"
	@echo "  make deploy-common   - Nur Common-Rolle deployen"
	@echo "  make deploy-postgres - Nur PostgreSQL deployen"
	@echo "  make deploy-redis    - Nur Redis deployen"
	@echo "  make deploy-minio    - Nur MinIO deployen"

# Ansible installieren
install:
	@echo "Installing Ansible..."
	pip3 install --user ansible
	@echo "Installing Ansible Collections..."
	ansible-galaxy collection install -r requirements.yml

# Collections installieren
requirements:
	@echo "Installing Ansible Collections..."
	ansible-galaxy collection install -r requirements.yml

# Ping-Test
ping:
	@echo "Testing connection to all hosts..."
	ansible -i inventory/harbor.yml all -m ping

# Komplettes Deployment
deploy:
	@echo "Deploying Harbor Data VM..."
	ansible-playbook -i inventory/harbor.yml playbooks/harbor-data.yml --ask-vault-pass

# Deployment Check-Mode
deploy-check:
	@echo "Running deployment in check mode..."
	ansible-playbook -i inventory/harbor.yml playbooks/harbor-data.yml --ask-vault-pass --check --diff

# Tag-basierte Deployments
deploy-common:
	ansible-playbook -i inventory/harbor.yml playbooks/harbor-data.yml --ask-vault-pass --tags common

deploy-postgres:
	ansible-playbook -i inventory/harbor.yml playbooks/harbor-data.yml --ask-vault-pass --tags postgresql

deploy-redis:
	ansible-playbook -i inventory/harbor.yml playbooks/harbor-data.yml --ask-vault-pass --tags redis

deploy-minio:
	ansible-playbook -i inventory/harbor.yml playbooks/harbor-data.yml --ask-vault-pass --tags minio

# Vault-Operationen
vault-create:
	@echo "Creating new vault file..."
	cp group_vars/harbor_data/vault.yml.example group_vars/harbor_data/vault.yml
	@echo "Edit the file now, then encrypt it with: make vault-encrypt"

vault-encrypt:
	@echo "Encrypting vault file..."
	ansible-vault encrypt group_vars/harbor_data/vault.yml

vault-edit:
	@echo "Editing vault file..."
	ansible-vault edit group_vars/harbor_data/vault.yml

vault-view:
	@echo "Viewing vault file..."
	ansible-vault view group_vars/harbor_data/vault.yml

# Wartungsoperationen
status:
	@echo "Checking service status on Data VM..."
	ansible harbor_data -i inventory/harbor.yml -b -a "systemctl status postgresql-16 redis minio --no-pager"

logs-postgres:
	ansible harbor_data -i inventory/harbor.yml -b -a "journalctl -u postgresql-16 -n 50 --no-pager"

logs-redis:
	ansible harbor_data -i inventory/harbor.yml -b -a "journalctl -u redis -n 50 --no-pager"

logs-minio:
	ansible harbor_data -i inventory/harbor.yml -b -a "journalctl -u minio -n 50 --no-pager"

# Clean up
clean:
	@echo "Cleaning up temporary files..."
	rm -f *.retry ansible.log
	rm -rf /tmp/ansible_facts/
