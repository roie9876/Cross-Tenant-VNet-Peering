#!/bin/bash
#
# ISV cleanup script for cross-tenant VNet peering resources (ISV SPN flow).
# This script can delete:
#   - ISV SPN (app registration + secret)
#   - Custom role and role assignments
#   - ISV RG/VNet (optional)
#
# Use with care. This is destructive.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/isv.env.sh"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "[ERROR] Missing ${ENV_FILE}. Create it from the template and fill values." >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$ENV_FILE"

###############################################################################
# CONFIGURATION
###############################################################################

# Values are loaded from scripts/isv.env.sh

# What to delete (true/false)
DELETE_ROLE_ASSIGNMENTS="true"
DELETE_ROLE_DEFINITION="true"
DELETE_ISV_APP="true"
DELETE_VNET="true"
DELETE_RESOURCE_GROUP="true"

###############################################################################
# HELPERS
###############################################################################

fail() {
  echo "[ERROR] $1" >&2
  exit 1
}

info() {
  echo "[INFO] $1"
}

###############################################################################
# CONFIRMATION
###############################################################################

echo "This will delete ISV-side resources. Type 'delete' to continue:"
read -r CONFIRM
if [[ "$CONFIRM" != "delete" ]]; then
  fail "Aborted."
fi

###############################################################################
# LOGIN AND CONTEXT
###############################################################################

command -v az >/dev/null 2>&1 || fail "Azure CLI (az) is required."

info "Logging into ISV tenant: $ISV_TENANT_ID"
az login --tenant "$ISV_TENANT_ID" >/dev/null
az account set --subscription "$ISV_SUBSCRIPTION_ID"

ROLE_SCOPE="/subscriptions/${ISV_SUBSCRIPTION_ID}/resourceGroups/${ISV_RESOURCE_GROUP}"

###############################################################################
# ROLE ASSIGNMENTS
###############################################################################

if [[ "$DELETE_ROLE_ASSIGNMENTS" == "true" ]]; then
  if [[ -n "$ISV_APP_ID" ]]; then
    info "Removing role assignment for ISV SPN on $ROLE_SCOPE"
    az role assignment delete \
      --assignee "$ISV_APP_ID" \
      --role "$ROLE_NAME" \
      --scope "$ROLE_SCOPE" >/dev/null 2>&1 || true

    info "Removing Reader role assignment for ISV SPN on ISV Subscription"
    az role assignment delete \
      --assignee "$ISV_APP_ID" \
      --role "Reader" \
      --scope "/subscriptions/${ISV_SUBSCRIPTION_ID}" >/dev/null 2>&1 || true
  fi

fi

###############################################################################
# ROLE DEFINITION
###############################################################################

if [[ "$DELETE_ROLE_DEFINITION" == "true" ]]; then
  info "Deleting custom role definition: $ROLE_NAME"
  az role definition delete --name "$ROLE_NAME" >/dev/null 2>&1 || true
fi

###############################################################################
# APP REGISTRATION / SPN
###############################################################################

if [[ "$DELETE_ISV_APP" == "true" && -n "$ISV_APP_ID" ]]; then
  info "Deleting ISV app registration: $ISV_APP_ID"
  az ad app delete --id "$ISV_APP_ID" >/dev/null 2>&1 || true
fi

###############################################################################
# VNET AND RESOURCE GROUP
###############################################################################

if [[ "$DELETE_RESOURCE_GROUP" == "true" ]]; then
  info "Deleting resource group: $ISV_RESOURCE_GROUP"
  az group delete --name "$ISV_RESOURCE_GROUP" --yes --no-wait >/dev/null 2>&1 || true
elif [[ "$DELETE_VNET" == "true" ]]; then
  info "Deleting VNet: $ISV_VNET_NAME"
  az network vnet delete \
    --name "$ISV_VNET_NAME" \
    --resource-group "$ISV_RESOURCE_GROUP" >/dev/null 2>&1 || true
fi

info "ISV cleanup complete."
