#!/bin/bash
#
# ISV peering script (SPN login).
# Creates peering from the ISV VNet to one or more customer VNets.
#
# Customer VNets are read from CUSTOMER_VNET_NAME_1, CUSTOMER_VNET_NAME_2, ...

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

# Peering options
ALLOW_VNET_ACCESS="true"
ALLOW_FORWARDED_TRAFFIC="true"
ALLOW_GATEWAY_TRANSIT="false"
USE_REMOTE_GATEWAYS="false"

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

require_value() {
  local name="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    fail "Missing required value: $name (set it in scripts/isv.env.sh)"
  fi
}

require_value "ISV_TENANT_ID" "$ISV_TENANT_ID"
require_value "ISV_SUBSCRIPTION_ID" "$ISV_SUBSCRIPTION_ID"
require_value "ISV_APP_ID" "$ISV_APP_ID"
require_value "ISV_APP_SECRET" "$ISV_APP_SECRET"
require_value "ISV_RESOURCE_GROUP" "$ISV_RESOURCE_GROUP"
require_value "ISV_VNET_NAME" "$ISV_VNET_NAME"
require_value "CUSTOMER_TENANT_ID" "$CUSTOMER_TENANT_ID"
require_value "CUSTOMER_SUBSCRIPTION_ID" "$CUSTOMER_SUBSCRIPTION_ID"
require_value "CUSTOMER_RESOURCE_GROUP" "$CUSTOMER_RESOURCE_GROUP"

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

CUSTOMER_VNET_NAMES=($(get_customer_vnet_names))
if [[ ${#CUSTOMER_VNET_NAMES[@]} -eq 0 ]]; then
  fail "No customer VNets defined. Set CUSTOMER_VNET_NAME_1 and related fields in scripts/isv.env.sh."
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
# CREATE PEERINGS
###############################################################################

for customer_vnet in "${CUSTOMER_VNET_NAMES[@]}"; do
  remote_id="/subscriptions/${CUSTOMER_SUBSCRIPTION_ID}/resourceGroups/${CUSTOMER_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/${customer_vnet}"
  peering_name="${ISV_PEERING_NAME_PREFIX}-${ISV_VNET_NAME}-to-${customer_vnet}"

  info "Creating ISV peering: $peering_name -> $remote_id"
  if ! output=$(az network vnet peering create \
    --name "$peering_name" \
    --resource-group "$ISV_RESOURCE_GROUP" \
    --vnet-name "$ISV_VNET_NAME" \
    --remote-vnet "$remote_id" \
    --allow-vnet-access "$ALLOW_VNET_ACCESS" \
    --allow-forwarded-traffic "$ALLOW_FORWARDED_TRAFFIC" \
    --allow-gateway-transit "$ALLOW_GATEWAY_TRANSIT" \
    --use-remote-gateways "$USE_REMOTE_GATEWAYS" 2>&1); then
    echo "$output" >&2
    if echo "$output" | grep -E -q "missing service principal|AADSTS7000229"; then
      info "Customer SPN likely not registered in customer tenant."
      info "Ask customer admin to run scripts/customer-register-isv-spn.sh"
      info "Or use admin consent URL:"
      info "https://login.microsoftonline.com/${CUSTOMER_TENANT_ID}/adminconsent?client_id=${ISV_APP_ID}"
    fi
    exit 1
  fi
done

info "ISV peering creation complete."
