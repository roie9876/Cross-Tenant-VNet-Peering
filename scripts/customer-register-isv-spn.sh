#!/bin/bash
#
# Customer registration-only script.
# Registers the ISV SPN in the customer tenant and assigns vnet-peer on the customer RGs.
#
# This script does NOT create app registrations. It only registers the external SPN
# and grants access. Run customer-setup.sh first.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/customer.env.sh"
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

command -v az >/dev/null 2>&1 || fail "Azure CLI (az) is required."

if [[ -z "$ISV_APP_ID" ]]; then
  fail "ISV_APP_ID is empty. Set it in scripts/customer.env.sh."
fi

info "Logging into customer tenant: $CUSTOMER_TENANT_ID"
az login --tenant "$CUSTOMER_TENANT_ID" >/dev/null
az account set --subscription "$CUSTOMER_SUBSCRIPTION_ID"

ROLE_NAME="vnet-peer"

ROLE_ID=$(az role definition list --name "$ROLE_NAME" --query "[0].name" -o tsv 2>/dev/null || true)
if [[ -z "$ROLE_ID" ]]; then
  fail "Role ${ROLE_NAME} not found. Run scripts/customer-setup.sh first."
fi

ROLE_SCOPE_LIST="$CUSTOMER_ROLE_SCOPES"
if [[ -z "$ROLE_SCOPE_LIST" ]]; then
  ROLE_SCOPE_LIST="${CUSTOMER_SUBSCRIPTION_ID}:${CUSTOMER_RESOURCE_GROUP}"
fi

ROLE_SCOPES=()
IFS=',' read -r -a SCOPE_ITEMS <<< "$ROLE_SCOPE_LIST"
for item in "${SCOPE_ITEMS[@]}"; do
  ROLE_SCOPES+=("$(parse_scope_entry "$item")")
done

info "Registering ISV SPN in customer tenant (App ID: $ISV_APP_ID)"
if ! az ad sp show --id "$ISV_APP_ID" >/dev/null 2>&1; then
  if ! az ad sp create --id "$ISV_APP_ID" >/dev/null 2>&1; then
    info "Admin consent required. Open this URL in the customer tenant:"
    info "https://login.microsoftonline.com/${CUSTOMER_TENANT_ID}/adminconsent?client_id=${ISV_APP_ID}"
    fail "ISV SPN registration failed."
  fi
fi

for scope in "${ROLE_SCOPES[@]}"; do
  info "Assigning role to ISV SPN on scope: $scope"
  az role assignment create \
    --assignee "$ISV_APP_ID" \
    --role "$ROLE_NAME" \
    --scope "$scope" >/dev/null 2>&1 || true
done

info "Customer registration complete."
