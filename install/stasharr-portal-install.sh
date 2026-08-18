#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: YourUsername
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/enymawse/stasharr-portal

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  curl \
  sudo \
  mc \
  gnupg \
  openssl
msg_ok "Installed Dependencies"

msg_info "Installing Docker"
setup_docker
msg_ok "Installed Docker"

msg_info "Deploying Stasharr Portal"
mkdir -p /opt/stasharr
cd /opt/stasharr || exit

DB_PASS=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c24)

cat <<EOF >/opt/stasharr/compose.yaml
x-db-env: &db-env
  POSTGRES_DB: stasharr
  POSTGRES_USER: stasharr
  POSTGRES_PASSWORD: ${DB_PASS}

services:
  postgres:
    image: postgres:17-alpine
    environment:
      <<: *db-env
    volumes:
      - stasharr_postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U \$\$POSTGRES_USER -d \$\$POSTGRES_DB']
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 10s
    restart: unless-stopped

  app:
    image: ghcr.io/enymawse/stasharr-portal:latest
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - stasharr_app_data:/var/lib/stasharr
    environment:
      <<: *db-env
      DATABASE_HOST: postgres
      DATABASE_URL: ""
      HOST: 0.0.0.0
      PORT: 3000
      DATABASE_MIGRATION_MAX_ATTEMPTS: 30
      DATABASE_MIGRATION_RETRY_DELAY_SECONDS: 2
      SESSION_COOKIE_SECURE: "false"
    ports:
      - "3000:3000"
    restart: unless-stopped

volumes:
  stasharr_postgres_data:
    name: stasharr_postgres_data
  stasharr_app_data:
    name: stasharr_app_data
EOF

cat <<EOF >/opt/stasharr/credentials.txt
Stasharr Portal - Postgres credentials
---------------------------------------
POSTGRES_DB:       stasharr
POSTGRES_USER:     stasharr
POSTGRES_PASSWORD: ${DB_PASS}

The application's SESSION_SECRET is auto-generated on first boot
and persisted in the stasharr_app_data volume.

Web UI: http://<container-ip>:3000
On first visit you will be prompted to create the single local
admin account for Stasharr itself (separate from the DB creds above).
EOF
chmod 600 /opt/stasharr/credentials.txt

$STD docker compose up -d
msg_ok "Deployed Stasharr Portal"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
