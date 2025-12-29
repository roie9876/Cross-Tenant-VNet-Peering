#!/bin/bash
#
# ISV peering delete script (SPN login).
# Deletes peerings created by isv-peering.sh using the same prefix and VNet list.

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
ISV_PEERING_NAME_PREFIX="peer-isv-to-customer"

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

get_customer_vnet_names() {
  local names=()
  local var
  for var in ${!CUSTOMER_VNET_NAME_@}; do
    local name="${!var}"
    if [[ -n "$name" ]]; then
      names+=("$name")
    fi
  done
  echo "${names[@]}"
}

###############################################################################
# CONFIRMATION
###############################################################################

echo "This will delete ISV peerings. Type 'delete' to continue:"
read -r CONFIRM
if [[ "$CONFIRM" != "delete" ]]; then
  fail "Aborted."
fi

###############################################################################
# LOGIN AND CONTEXT
###############################################################################

command -v az >/dev/null 2>&1 || fail "Azure CLI (az) is required."

info "Logging in with ISV SPN"
az login --service-principal \
  --username "$ISV_APP_ID" \
  --password "$ISV_APP_SECRET" \
  --tenant "$ISV_TENANT_ID" >/dev/null

az account set --subscription "$ISV_SUBSCRIPTION_ID"

###############################################################################
# DELETE PEERINGS
###############################################################################

CUSTOMER_VNET_NAMES=($(get_customer_vnet_names))
if [[ ${#CUSTOMER_VNET_NAMES[@]} -eq 0 ]]; then
  fail "No customer VNets defined. Set CUSTOMER_VNET_NAME_1 and related fields in scripts/isv.env.sh."
fi

for customer_vnet in "${CUSTOMER_VNET_NAMES[@]}"; do
  peering_name="${ISV_PEERING_NAME_PREFIX}-${ISV_VNET_NAME}-to-${customer_vnet}"

  info "Deleting ISV peering: $peering_name"
  az network vnet peering delete \
    --name "$peering_name" \
    --resource-group "$ISV_RESOURCE_GROUP" \
    --vnet-name "$ISV_VNET_NAME" >/dev/null 2>&1 || true
done

info "ISV peering deletion complete."
