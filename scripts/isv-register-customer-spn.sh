#!/bin/bash
#
# ISV registration-only script.
# Registers the CUSTOMER SPN in the ISV tenant and assigns vnet-peer on the ISV RG.
#
# This script does NOT create app registrations. It only registers the external SPN
# and grants access. Run isv-setup.sh first.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/isv.env.sh"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "[ERROR] Missing ${ENV_FILE}. Create it from the template and fill values." >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$ENV_FILE"

fail() {
  echo "[ERROR] $1" >&2
  exit 1
}

info() {
  echo "[INFO] $1"
}

command -v az >/dev/null 2>&1 || fail "Azure CLI (az) is required."

if [[ -z "$CUSTOMER_APP_ID" ]]; then
  fail "CUSTOMER_APP_ID is empty. Set it in scripts/isv.env.sh."
fi

info "Logging into ISV tenant: $ISV_TENANT_ID"
az login --tenant "$ISV_TENANT_ID" >/dev/null
az account set --subscription "$ISV_SUBSCRIPTION_ID"

ROLE_NAME="vnet-peer"
ROLE_SCOPE="/subscriptions/${ISV_SUBSCRIPTION_ID}/resourceGroups/${ISV_RESOURCE_GROUP}"

ROLE_ID=$(az role definition list --name "$ROLE_NAME" --query "[0].name" -o tsv 2>/dev/null || true)
if [[ -z "$ROLE_ID" ]]; then
  fail "Role ${ROLE_NAME} not found. Run scripts/isv-setup.sh first."
fi

info "Registering customer SPN in ISV tenant (App ID: $CUSTOMER_APP_ID)"
if ! az ad sp show --id "$CUSTOMER_APP_ID" >/dev/null 2>&1; then
  if ! az ad sp create --id "$CUSTOMER_APP_ID" >/dev/null 2>&1; then
    info "Admin consent required. Open this URL in the ISV tenant:"
    info "https://login.microsoftonline.com/${ISV_TENANT_ID}/adminconsent?client_id=${CUSTOMER_APP_ID}"
    fail "Customer SPN registration failed."
  fi
fi

info "Assigning role to customer SPN on ISV RG scope"
az role assignment create \
  --assignee "$CUSTOMER_APP_ID" \
  --role "$ROLE_NAME" \
  --scope "$ROLE_SCOPE" >/dev/null 2>&1 || true

info "ISV registration complete."
