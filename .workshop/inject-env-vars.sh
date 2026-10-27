#!/usr/bin/env bash
# Inject the RHACS lab's runtime attributes and Showroom tabs after deployment.
set -euo pipefail

REPO_DIR="${SHOWROOM_REPO_DIR:-/showroom/repo}"
WWW_DIR="${SHOWROOM_WWW_DIR:-/showroom/www}"
SITE_FILE="${REPO_DIR}/default-site.yml"
UI_CONFIG="${REPO_DIR}/ui-config.yml"

if [[ ! -f "$SITE_FILE" ]]; then
    echo "ERROR: ${SITE_FILE} not found" >&2
    exit 1
fi
: "${ROUTE_SUBDOMAIN:?ROUTE_SUBDOMAIN must be set for the lab console URLs}"
: "${ADMIN_PASSWORD:?ADMIN_PASSWORD must be set for the lab credentials}"

CONSOLE_URL="${MASTER_URL:-https://console-openshift-console.${ROUTE_SUBDOMAIN}}"
RHACS_URL="${RHACS_URL:-https://central-stackrox.${ROUTE_SUBDOMAIN}}"

# Escape single quotes so passwords and URLs remain valid YAML scalar values.
yaml_string() {
    local value="$1"
    local quote="'"
    if [[ "$value" == *$'\n'* || "$value" == *$'\r'* ]]; then
        echo "ERROR: Lab configuration values must be single-line strings" >&2
        return 1
    fi
    value="${value//${quote}/${quote}${quote}}"
    printf "'%s'" "$value"
}

attribute() {
    printf '    %s: ' "$1"
    yaml_string "$2"
    printf '\n'
}

SITE_TMP="$(mktemp "${SITE_FILE}.XXXXXX")"
UI_TMP="$(mktemp "${UI_CONFIG}.XXXXXX")"
trap 'rm -f "$SITE_TMP" "$UI_TMP"' EXIT

# Replace the runtime AsciiDoc section, retaining the rest of the playbook.
awk '
    /^asciidoc:/ { in_asciidoc=1; next }
    in_asciidoc && /^[[:alnum:]_-]+:/ { in_asciidoc=0 }
    !in_asciidoc { print }
' "$SITE_FILE" > "$SITE_TMP"

{
    printf 'asciidoc:\n  attributes:\n    toclevels: 2\n'
    attribute openshift_cluster_console_url "$CONSOLE_URL"
    attribute openshift_cluster_admin_username "${ADMIN_USERNAME:-admin}"
    attribute openshift_cluster_admin_password "$ADMIN_PASSWORD"
    attribute rhacs_url "$RHACS_URL"
    attribute rhacs_admin_username "${RHACS_ADMIN_USERNAME:-admin}"
    attribute rhacs_admin_password "${RHACS_ADMIN_PASSWORD:-$ADMIN_PASSWORD}"
} >> "$SITE_TMP"

cat > "$UI_TMP" <<UIEOF
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
    url: $(yaml_string "$CONSOLE_URL")

  - name: Terminal
    path: /wetty
    port: 443

  - name: RHACS
    url: $(yaml_string "$RHACS_URL")
UIEOF

# Preserve permissions for the Showroom build and web server processes.
cat "$SITE_TMP" > "$SITE_FILE"
cat "$UI_TMP" > "$UI_CONFIG"
if [[ -d "$WWW_DIR" ]]; then
    cp "$UI_CONFIG" "${WWW_DIR}/ui-config.yml"
fi

echo "RHACS lab attributes and Showroom tabs configured."
