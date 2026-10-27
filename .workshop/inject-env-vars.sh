#!/bin/bash
# inject-env-vars.sh
# Injects lab environment variables into Antora configuration
# Called by the showroom workload after deployment
#
# This is a single-module lab (Red Hat Advanced Cluster Security), so there are
# no module_enable_* flags and no conditional nav - nav.adoc lists its three
# pages unconditionally.

set -e

REPO_DIR="/showroom/repo"
SITE_FILE="${REPO_DIR}/default-site.yml"

echo "=== Injecting lab environment variables ==="
echo "Working directory: ${REPO_DIR}"

# Check if default-site.yml exists
if [ ! -f "$SITE_FILE" ]; then
    echo "ERROR: ${SITE_FILE} not found"
    exit 1
fi

ATTRS=""

# TOC depth - only show main sections
ATTRS="${ATTRS}    toclevels: 2"$'\n'

# Standard lab variables
ATTRS="${ATTRS}    api_url: '${API_URL:-}'"$'\n'
ATTRS="${ATTRS}    master_url: '${MASTER_URL:-}'"$'\n'
ATTRS="${ATTRS}    admin_password: '${ADMIN_PASSWORD:-}'"$'\n'
ATTRS="${ATTRS}    ssh_username: '${SSH_USERNAME:-}'"$'\n'
ATTRS="${ATTRS}    ssh_password: '${SSH_PASSWORD:-}'"$'\n'
ATTRS="${ATTRS}    bastion_fqdn: '${BASTION_FQDN:-}'"$'\n'
ATTRS="${ATTRS}    guid: '${GUID:-}'"$'\n'
ATTRS="${ATTRS}    route_subdomain: '${ROUTE_SUBDOMAIN:-}'"$'\n'
ATTRS="${ATTRS}    environment: '${ENVIRONMENT:-Amazon Web Services}'"$'\n'
# Aliases - common alternate names content authors may use
ATTRS="${ATTRS}    bastion_ssh_user: '${SSH_USERNAME:-}'"$'\n'
ATTRS="${ATTRS}    bastion_ssh_password: '${SSH_PASSWORD:-}'"$'\n'
ATTRS="${ATTRS}    bastion_public_hostname: '${BASTION_FQDN:-}'"$'\n'
ATTRS="${ATTRS}    openshift_cluster_console_url: '${MASTER_URL:-}'"$'\n'
ATTRS="${ATTRS}    openshift_api_server_url: '${API_URL:-}'"$'\n'
ATTRS="${ATTRS}    openshift_cluster_admin_password: '${ADMIN_PASSWORD:-}'"$'\n'
ATTRS="${ATTRS}    openshift_cluster_admin_username: 'admin'"$'\n'
# Service URLs - derived from ROUTE_SUBDOMAIN
ATTRS="${ATTRS}    console_url: 'https://console-openshift-console.${ROUTE_SUBDOMAIN:-}'"$'\n'
ATTRS="${ATTRS}    rhacs_url: 'https://central-stackrox.${ROUTE_SUBDOMAIN:-}'"$'\n'
ATTRS="${ATTRS}    rhacs_admin_username: 'admin'"$'\n'
ATTRS="${ATTRS}    rhacs_admin_password: '${ADMIN_PASSWORD:-}'"$'\n'
ATTRS="${ATTRS}    acs_route: 'https://central-stackrox.${ROUTE_SUBDOMAIN:-}'"$'\n'
ATTRS="${ATTRS}    acs_portal_username: 'admin'"$'\n'
ATTRS="${ATTRS}    acs_portal_password: '${ADMIN_PASSWORD:-}'"$'\n'

echo "Attributes to inject:"
echo "$ATTRS"

# Check if asciidoc section already exists
if grep -q "^asciidoc:" "$SITE_FILE"; then
    echo "asciidoc section already exists, replacing attributes..."
    # Remove existing asciidoc section and add new one
    cp "$SITE_FILE" "${SITE_FILE}.bak"

    # Remove old asciidoc section (everything from "asciidoc:" to next top-level key or EOF)
    awk '
        /^asciidoc:/ { in_asciidoc=1; next }
        in_asciidoc && /^[a-z]/ { in_asciidoc=0 }
        !in_asciidoc { print }
    ' "${SITE_FILE}.bak" > "$SITE_FILE"
fi

# Append asciidoc section with attributes
echo "" >> "$SITE_FILE"
echo "asciidoc:" >> "$SITE_FILE"
echo "  attributes:" >> "$SITE_FILE"
echo -n "$ATTRS" >> "$SITE_FILE"

echo "=== Antora injection complete ==="

# ==============================================================================
# Generate ui-config.yml
# OCP Console and Terminal are base workloads; RHACS is this lab's whole point,
# so all three tabs are unconditional.
# ==============================================================================
echo "=== Generating ui-config.yml ==="

UI_CONFIG="${REPO_DIR}/ui-config.yml"
DOMAIN="${ROUTE_SUBDOMAIN:-}"

cat > "$UI_CONFIG" <<UIEOF
---
type: showroom

default_width: 30
persist_url_state: true

view_switcher:
  enabled: true
  default_mode: split

antora:
  name: rhacs-security
  version: main

tabs:
  - name: OCP Console
    url: 'https://console-openshift-console.${DOMAIN}'

  - name: Terminal
    path: /wetty
    port: 443

  - name: RHACS
    url: 'https://central-stackrox.${DOMAIN}'
UIEOF

# Copy to served location
cp "$UI_CONFIG" /showroom/www/ui-config.yml 2>/dev/null || true

echo "Generated ui-config.yml:"
cat "$UI_CONFIG"
echo "=== All injection complete ==="
