#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: YourUsername
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/enymawse/stasharr-portal

# Import main orchestrator (production repo — reliable fetch on this network)
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

# Application Configuration
APP="Stasharr-Portal"
var_tags="${var_tags:-media;whisparr;stash}"

# Container Resources
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"

# Container Type & OS
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/stasharr ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if [[ -d /opt/stasharr-src/.git ]]; then
    # Custom fork build detected — rebuild the image from source instead
    # of pulling the official ghcr.io image.
    msg_info "Updating ${APP} (custom fork build)"
    cd /opt/stasharr-src || exit
    $STD git pull
    $STD docker build -t stasharr-portal:custom .
    cd /opt/stasharr || exit
    $STD docker compose up -d
    $STD docker image prune -f
    msg_ok "Updated ${APP} from custom fork"
  else
    msg_info "Updating ${APP}"
    cd /opt/stasharr || exit
    $STD docker compose pull
    $STD docker compose up -d
    $STD docker image prune -f
    msg_ok "Updated ${APP}"
  fi
  exit
}

start
build_container
description

# ------------------------------------------------------------------------------
# Manual install step — bypasses build.func's remote install-fetch entirely.
# The framework's own attempt to curl install/stasharr-portal-install.sh from
# a fork may silently fail on networks that block that specific path. This
# pushes a fully self-contained install script directly into the container
# and runs it locally, with no in-container curl calls to any GitHub-hosted
# framework files.
# ------------------------------------------------------------------------------
TARGET_CTID="${CTID:-$CT_ID}"

if [[ -z "$TARGET_CTID" ]]; then
  echo "ERROR: Could not determine container ID — cannot push install script."
  exit 1
fi

echo "Fetching install script and pushing into container ${TARGET_CTID}..."
INSTALL_TMP="$(mktemp)"
if ! curl -fsSL "https://raw.githubusercontent.com/odd-one77/proxmox-scripts/main/install/stasharr-portal-install.sh" -o "$INSTALL_TMP"; then
  echo "ERROR: Failed to download install script from odd-one77/proxmox-scripts."
  exit 1
fi

pct push "$TARGET_CTID" "$INSTALL_TMP" /root/stasharr-install.sh
rm -f "$INSTALL_TMP"

echo "Running install script inside container ${TARGET_CTID}..."
pct exec "$TARGET_CTID" -- bash /root/stasharr-install.sh
pct exec "$TARGET_CTID" -- rm -f /root/stasharr-install.sh

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${GATEWAY}${BGN}http://${IP}:3000${CL}"
echo -e "${INFO}${YW}On first visit you'll be prompted to create the single local admin account.${CL}"
echo -e "${INFO}${YW}Generated Postgres credentials are saved in /opt/stasharr/credentials.txt${CL}"
