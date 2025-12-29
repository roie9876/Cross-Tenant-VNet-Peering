#!/bin/bash
#
# ISV peering script (SPN login).
# Creates peering from the ISV VNet to one or more customer VNets.
#
# CUSTOMER_VNETS format:
#   Simple: "vnet-customer-spoke,vnet-customer-2" (uses CUSTOMER_RESOURCE_GROUP and CUSTOMER_SUBSCRIPTION_ID)
#   Advanced: "SUB_ID:RG_NAME/VNET_NAME,RG_NAME/VNET_NAME"

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
require_value "CUSTOMER_VNETS" "$CUSTOMER_VNETS"

parse_vnet_entry() {
  local entry="$1"
  local sub_id rg vnet rest

  entry="${entry//[[:space:]]/}"
  if [[ "$entry" == *":"* ]]; then
    sub_id="${entry%%:*}"
    rest="${entry#*:}"
  else
    sub_id="$CUSTOMER_SUBSCRIPTION_ID"
    rest="$entry"
  fi

  if [[ "$rest" == *"/"* ]]; then
    rg="${rest%%/*}"
    vnet="${rest#*/}"
  else
    rg="$CUSTOMER_RESOURCE_GROUP"
    vnet="$rest"
  fi

  if [[ -z "$sub_id" || -z "$rg" || -z "$vnet" ]]; then
    fail "Invalid VNet entry: $entry (expected VNET, RG/VNET, or SUB_ID:RG/VNET)"
  fi

  echo "${sub_id}|${rg}|${vnet}"
}

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

ISV_VNET_ID=$(az network vnet show \
  --resource-group "$ISV_RESOURCE_GROUP" \
  --name "$ISV_VNET_NAME" \
  --query id -o tsv)

IFS=',' read -r -a VNET_ITEMS <<< "$CUSTOMER_VNETS"
if [[ ${#VNET_ITEMS[@]} -eq 0 ]]; then
  fail "CUSTOMER_VNETS is empty. Provide at least one VNet entry."
fi

for item in "${VNET_ITEMS[@]}"; do
  parsed=$(parse_vnet_entry "$item")
  customer_sub="${parsed%%|*}"
  rest="${parsed#*|}"
  customer_rg="${rest%%|*}"
  customer_vnet="${rest#*|}"

  remote_id="/subscriptions/${customer_sub}/resourceGroups/${customer_rg}/providers/Microsoft.Network/virtualNetworks/${customer_vnet}"
  peering_name="${ISV_PEERING_NAME_PREFIX}-${customer_vnet}"

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
