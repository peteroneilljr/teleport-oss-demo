#!/bin/bash

set -euo pipefail

# Configuration Variables
CLUSTER_PROXY_ADDRESS=${teleport_cluster_name}.${aws_route53_zone}
CLUSTER_NAME=${teleport_cluster_name}
TELEPORT_VERSION=${teleport_version}
TELEPORT_EMAIL=${teleport_email}
GH_CLIENT_ID=${gh_client_id}
GH_CLIENT_SECRET=${gh_client_secret}
GH_ORG_NAME=${gh_org_name}
GH_TEAM_NAME=${gh_team_name}
AWS_ROLE_READ_ONLINE=${aws_role_read_online}

# Logging Function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Create Teleport Resources
create_teleport_resource() {
    local resource_name=$1
    local resource_spec=$2
    log "Creating resource: $resource_name..."
    echo "$resource_spec" | tctl create -f
}

# Create Configuration Files
create_file() {
    local file_name=$1
    local file_content=$2
    log "Creating file: $file_name..."
    echo "$file_content" | tee $file_name
}

# Install tools
install_tool() {
    local name=$1
    local install_cmd=$2
    log "Installing $name..."
    eval "$install_cmd"
}

# ---------------------------------------------------------------------------- #
# Install Tools
# ---------------------------------------------------------------------------- #
log "Installing Tools..."
install_tool "Teleport" "curl -sS https://cdn.teleport.dev/install-v$TELEPORT_VERSION.sh | bash -s $TELEPORT_VERSION oss"
install_tool "kubectl" "curl -LO 'https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl' && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl"
install_tool "Helm" "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
install_tool "Docker" "yum install -y docker && service docker start && usermod -aG docker ec2-user && newgrp docker"
install_tool "Minikube" "curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64 && sudo -u ec2-user minikube start"
install_tool "PostgreSQL" "dnf install postgresql15.x86_64 postgresql15-server -y"

# ---------------------------------------------------------------------------- #
# Configure Teleport
# ---------------------------------------------------------------------------- #
log "Configuring Teleport..."
create_file "/etc/teleport.yaml" "
version: v3
teleport:
  nodename: $CLUSTER_PROXY_ADDRESS
  data_dir: /var/lib/teleport
  log:
    output: stderr
    severity: INFO
    format:
      output: text
auth_service:
  enabled: yes
  listen_addr: 0.0.0.0:3025
  cluster_name: $CLUSTER_PROXY_ADDRESS
  proxy_listener_mode: multiplex
  authentication:
    type: github 
ssh_service:
  enabled: yes
  labels:
    env: oss
  commands:
  - name: 'os'
    command: ['/usr/bin/uname']
    period: 1h0m0s
db_service:
  enabled: yes
  resources:
    - labels:
        '*': '*'
app_service:
  enabled: yes
  resources:
    - labels:
        '*': '*'
proxy_service:
  enabled: yes
  web_listen_addr: 0.0.0.0:443
  public_addr: $CLUSTER_PROXY_ADDRESS:443
  acme:
    enabled: yes
    email: $TELEPORT_EMAIL
"

# ---------------------------------------------------------------------------- #
# Setup Teleport as a systemd service
# ---------------------------------------------------------------------------- #
log "Setting up Teleport as a systemd service..."
teleport install systemd --output=/etc/systemd/system/teleport.service
systemctl enable teleport
systemctl restart teleport
sleep 5
systemctl status teleport

# ---------------------------------------------------------------------------- #
# Configure GitHub SSO
# ---------------------------------------------------------------------------- #
log "Configuring GitHub SSO..."
create_teleport_resource "github" "
kind: github
metadata:
  name: github
spec:
  api_endpoint_url: ''
  client_id: $GH_CLIENT_ID
  client_secret: $GH_CLIENT_SECRET
  display: ''
  endpoint_url: ''
  redirect_url: https://$CLUSTER_PROXY_ADDRESS:443/v1/webapi/github/callback
  teams_to_logins: null
  teams_to_roles:
  - organization: $GH_ORG_NAME
    roles:
    - editor
    - kube-access
    - db-access
    - node-access
    - app-access
    team: admins
version: v3
"

# ---------------------------------------------------------------------------- #
# Create Teleport Roles
# ---------------------------------------------------------------------------- #
create_teleport_resource "kube-access" "
kind: role
metadata:
  name: kube-access
version: v7
spec:
  allow:
    kubernetes_labels:
      '*': '*'
    kubernetes_resources:
      - kind: '*'
        namespace: '*'
        name: '*'
        verbs: ['*']
    kubernetes_groups:
    - system:masters
"

create_teleport_resource "db-access" "
kind: role
metadata:
  name: db-access
version: v7
spec:
  allow:
    db_labels:
      '*': '*'
    db_names:
    - '*'
    db_service_labels:
      '*': '*'
    db_users:
    - '*'
"

create_teleport_resource "app-access" "
kind: role
metadata:
  name: app-access
version: v7
spec:
  allow:
    app_labels:
      '*': '*'
    aws_role_arns:
    - $AWS_ROLE_READ_ONLINE
"

create_teleport_resource "node-access" "
kind: role
metadata:
  name: node-access
version: v7
spec:
  allow:
    node_labels:
      '*': '*'
    host_groups:
    - wheel
    host_sudoers:
    - 'ALL=(ALL) NOPASSWD: ALL'
    logins:
    - '{{external.logins}}'
    - ec2-user
  options:
    create_host_user: true
    create_host_user_default_shell: /bin/bash
    create_host_user_mode: keep
"

# ---------------------------------------------------------------------------- #
# Deploy Kubernetes Agent
# ---------------------------------------------------------------------------- #
log "Deploying Teleport Kubernetes Agent..."

create_file "/tmp/teleport-agent-values.yaml" "
roles: kube
authToken: $(tctl tokens add --type=kube --format=text)
proxyAddr: $CLUSTER_PROXY_ADDRESS:443
kubeClusterName: MiniKube
labels:
  env: oss
"

sudo -u ec2-user helm repo add teleport https://charts.releases.teleport.dev 
sudo -u ec2-user helm repo update
sudo -u ec2-user helm install teleport-agent teleport/teleport-kube-agent \
  -f /tmp/teleport-agent-values.yaml --version $TELEPORT_VERSION \
  --create-namespace --namespace teleport

# ---------------------------------------------------------------------------- #
# PostgreSQL Configuration
# ---------------------------------------------------------------------------- #
log "Installing and configuring PostgreSQL..."
postgresql-setup --initdb
tctl auth sign --format=db --host=localhost --out=/var/lib/pgsql/$CLUSTER_NAME --ttl=2190h
chown postgres:postgres /var/lib/pgsql/$CLUSTER_NAME.*

create_file "/var/lib/pgsql/data/postgresql.conf" "
ssl = on
ssl_ca_file = '/var/lib/pgsql/$CLUSTER_NAME.cas'
ssl_cert_file = '/var/lib/pgsql/$CLUSTER_NAME.crt'
ssl_key_file = '/var/lib/pgsql/$CLUSTER_NAME.key'
"

create_file "/var/lib/pgsql/data/pg_hba.conf" "
local   all             all                                     trust
hostssl all             all             ::/0                    cert
hostssl all             all             0.0.0.0/0               cert
"

systemctl enable postgresql
systemctl start postgresql

sudo -i -u postgres psql -c 'CREATE USER teleport;'
sudo -i -u postgres psql -c 'CREATE DATABASE teleport;'
sudo -i -u postgres psql -c 'GRANT ALL PRIVILEGES ON DATABASE teleport TO teleport;'

create_teleport_resource "postgresql" "
kind: db
version: v3
metadata:
  name: PostgreSQL
  description: 'PostgreSQL Database'
  labels:
    env: oss
    engine: postgres
spec:
  protocol: 'postgres'
  uri: 'localhost:5432'
"

# ---------------------------------------------------------------------------- #
# Grafana App
# ---------------------------------------------------------------------------- #
create_file "/etc/grafana.ini" "
[server]
domain = $CLUSTER_PROXY_ADDRESS
[auth.jwt]
enabled = true 
header_name = Teleport-Jwt-Assertion
username_claim = sub
email_claim = sub 
auto_sign_up = true
jwk_set_url = https://$CLUSTER_PROXY_ADDRESS/.well-known/jwks.json
username_attribute_path = username
role_attribute_path = contains(roles[*], 'app-access') && 'Admin' || contains(roles[*], 'editor') && 'Editor' || 'Viewer'
allow_assign_grafana_admin = true
cache_ttl = 60m
"

docker run --detach \
  --name grafana \
  --publish 3000:3000 \
  -v /etc/grafana.ini:/etc/grafana/grafana.ini \
  grafana/grafana


create_teleport_resource "grafana" "
kind: app
version: v3
metadata:
  name: Grafana
  description: 'Grafana'
  labels:
    env: oss
spec:
  uri: 'http://localhost:3000'
"

# ---------------------------------------------------------------------------- #
# AWS Console App
# ---------------------------------------------------------------------------- #
create_teleport_resource "awsconsole" "
kind: app
version: v3
metadata:
  name: AWS-Console
  description: 'AWS Console Access'
  labels:
    env: oss
spec:
  uri: 'https://console.aws.amazon.com/'
  cloud: AWS
"

log "Setup Complete!"
