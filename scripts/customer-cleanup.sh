#!/bin/bash
#
# Customer cleanup script for cross-tenant VNet peering resources (SPN-first flow).
# This script can delete:
#   - Customer SPN (app registration + secret)
#   - Custom role and role assignments
#   - Customer RG/VNet (optional)
#
# Use with care. This is destructive.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/customer.env.sh"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "[ERROR] Missing ${ENV_FILE}. Create it from the template and fill values." >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$ENV_FILE"

###############################################################################
# CONFIGURATION
###############################################################################

# Values are loaded from scripts/customer.env.sh

# What to delete (true/false)
DELETE_ROLE_ASSIGNMENTS="true"
DELETE_ROLE_DEFINITION="true"
DELETE_CUSTOMER_APP="true"
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

parse_scope_entry() {
  local entry="$1"
  local sub_id rg

  entry="${entry//[[:space:]]/}"
  if [[ "$entry" == *":"* ]]; then
    sub_id="${entry%%:*}"
    rg="${entry#*:}"
  else
    sub_id="$CUSTOMER_SUBSCRIPTION_ID"
    rg="$entry"
  fi

  if [[ -z "$sub_id" || -z "$rg" ]]; then
    fail "Invalid scope entry: $entry (expected SUB_ID:RG_NAME or RG_NAME)"
  fi

  echo "/subscriptions/${sub_id}/resourceGroups/${rg}"
}

###############################################################################
# CONFIRMATION
###############################################################################

echo "This will delete customer-side resources. Type 'delete' to continue:"
read -r CONFIRM
if [[ "$CONFIRM" != "delete" ]]; then
  fail "Aborted."
fi

###############################################################################
# LOGIN AND CONTEXT
###############################################################################

command -v az >/dev/null 2>&1 || fail "Azure CLI (az) is required."

info "Logging into customer tenant: $CUSTOMER_TENANT_ID"
az login --tenant "$CUSTOMER_TENANT_ID" >/dev/null
az account set --subscription "$CUSTOMER_SUBSCRIPTION_ID"

ROLE_NAME="vnet-peer"

ROLE_SCOPE_LIST="$CUSTOMER_ROLE_SCOPES"
if [[ -z "$ROLE_SCOPE_LIST" ]]; then
  ROLE_SCOPE_LIST="${CUSTOMER_SUBSCRIPTION_ID}:${CUSTOMER_RESOURCE_GROUP}"
fi

ROLE_SCOPES=()
IFS=',' read -r -a SCOPE_ITEMS <<< "$ROLE_SCOPE_LIST"
for item in "${SCOPE_ITEMS[@]}"; do
  ROLE_SCOPES+=("$(parse_scope_entry "$item")")
done

###############################################################################
# ROLE ASSIGNMENTS
###############################################################################

if [[ "$DELETE_ROLE_ASSIGNMENTS" == "true" ]]; then
  for scope in "${ROLE_SCOPES[@]}"; do
    if [[ -n "$CUSTOMER_APP_ID" ]]; then
      info "Removing role assignment for customer SPN on $scope"
      az role assignment delete \
        --assignee "$CUSTOMER_APP_ID" \
        --role "$ROLE_NAME" \
        --scope "$scope" >/dev/null 2>&1 || true
    fi

    if [[ -n "$ISV_APP_ID" ]]; then
      info "Removing role assignment for ISV SPN on $scope"
      az role assignment delete \
        --assignee "$ISV_APP_ID" \
        --role "$ROLE_NAME" \
        --scope "$scope" >/dev/null 2>&1 || true
    fi
  done
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

if [[ "$DELETE_CUSTOMER_APP" == "true" && -n "$CUSTOMER_APP_ID" ]]; then
  info "Deleting customer app registration: $CUSTOMER_APP_ID"
  az ad app delete --id "$CUSTOMER_APP_ID" >/dev/null 2>&1 || true
fi

###############################################################################
# VNET AND RESOURCE GROUP
###############################################################################

if [[ "$DELETE_RESOURCE_GROUP" == "true" ]]; then
  info "Deleting resource group: $CUSTOMER_RESOURCE_GROUP"
  az group delete --name "$CUSTOMER_RESOURCE_GROUP" --yes --no-wait >/dev/null 2>&1 || true
elif [[ "$DELETE_VNET" == "true" ]]; then
  info "Deleting VNet: $CUSTOMER_VNET_NAME"
  az network vnet delete \
    --name "$CUSTOMER_VNET_NAME" \
    --resource-group "$CUSTOMER_RESOURCE_GROUP" >/dev/null 2>&1 || true
fi

info "Customer cleanup complete."
