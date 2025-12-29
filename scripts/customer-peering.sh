#!/bin/bash
#
# Customer peering script (SPN login).
# Creates peering from the customer VNet(s) to the ISV VNet(s).
#
# ISV_VNETS format:
#   Simple: "vnet-isv-hub,vnet-isv-2" (uses ISV_RESOURCE_GROUP and ISV_SUBSCRIPTION_ID)
#   Advanced: "SUB_ID:RG_NAME/VNET_NAME,RG_NAME/VNET_NAME"

set -euo pipefail

###############################################################################
# CONFIGURATION
###############################################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/customer.env.sh"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "[ERROR] Missing ${ENV_FILE}. Create it from the template and fill values." >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$ENV_FILE"

# Values are loaded from scripts/customer.env.sh
CUSTOMER_PEERING_NAME_PREFIX="peer-customer-to-isv"

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
    fail "Missing required value: $name (set it in scripts/customer.env.sh)"
  fi
}

require_value "CUSTOMER_TENANT_ID" "$CUSTOMER_TENANT_ID"
require_value "CUSTOMER_SUBSCRIPTION_ID" "$CUSTOMER_SUBSCRIPTION_ID"
require_value "CUSTOMER_APP_ID" "$CUSTOMER_APP_ID"
require_value "CUSTOMER_APP_SECRET" "$CUSTOMER_APP_SECRET"
require_value "CUSTOMER_RESOURCE_GROUP" "$CUSTOMER_RESOURCE_GROUP"
require_value "CUSTOMER_VNET_NAME" "$CUSTOMER_VNET_NAME"
require_value "ISV_TENANT_ID" "$ISV_TENANT_ID"
require_value "ISV_SUBSCRIPTION_ID" "$ISV_SUBSCRIPTION_ID"
require_value "ISV_RESOURCE_GROUP" "$ISV_RESOURCE_GROUP"
require_value "ISV_VNETS" "$ISV_VNETS"

parse_vnet_entry() {
  local entry="$1"
  local sub_id rg vnet rest

  entry="${entry//[[:space:]]/}"
  if [[ "$entry" == *":"* ]]; then
    sub_id="${entry%%:*}"
    rest="${entry#*:}"
  else
    sub_id="$ISV_SUBSCRIPTION_ID"
    rest="$entry"
  fi

  if [[ "$rest" == *"/"* ]]; then
    rg="${rest%%/*}"
    vnet="${rest#*/}"
  else
    rg="$ISV_RESOURCE_GROUP"
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

info "Logging in with customer SPN"
az login --service-principal \
  --username "$CUSTOMER_APP_ID" \
  --password "$CUSTOMER_APP_SECRET" \
  --tenant "$CUSTOMER_TENANT_ID" >/dev/null

az account set --subscription "$CUSTOMER_SUBSCRIPTION_ID"

###############################################################################
# CREATE PEERINGS
###############################################################################

CUSTOMER_VNET_ID=$(az network vnet show \
  --resource-group "$CUSTOMER_RESOURCE_GROUP" \
  --name "$CUSTOMER_VNET_NAME" \
  --query id -o tsv)

IFS=',' read -r -a VNET_ITEMS <<< "$ISV_VNETS"
if [[ ${#VNET_ITEMS[@]} -eq 0 ]]; then
  fail "ISV_VNETS is empty. Provide at least one VNet entry."
fi

for item in "${VNET_ITEMS[@]}"; do
  parsed=$(parse_vnet_entry "$item")
  isv_sub="${parsed%%|*}"
  rest="${parsed#*|}"
  isv_rg="${rest%%|*}"
  isv_vnet="${rest#*|}"

  remote_id="/subscriptions/${isv_sub}/resourceGroups/${isv_rg}/providers/Microsoft.Network/virtualNetworks/${isv_vnet}"
  peering_name="${CUSTOMER_PEERING_NAME_PREFIX}-${isv_vnet}"

  info "Creating customer peering: $peering_name -> $remote_id"
  if ! output=$(az network vnet peering create \
    --name "$peering_name" \
    --resource-group "$CUSTOMER_RESOURCE_GROUP" \
    --vnet-name "$CUSTOMER_VNET_NAME" \
    --remote-vnet "$remote_id" \
    --allow-vnet-access "$ALLOW_VNET_ACCESS" \
    --allow-forwarded-traffic "$ALLOW_FORWARDED_TRAFFIC" \
    --allow-gateway-transit "$ALLOW_GATEWAY_TRANSIT" \
    --use-remote-gateways "$USE_REMOTE_GATEWAYS" 2>&1); then
    echo "$output" >&2
    if echo "$output" | grep -E -q "missing service principal|AADSTS7000229"; then
      info "Customer SPN likely not registered in ISV tenant."
      info "Ask ISV admin to run scripts/isv-register-customer-spn.sh"
      info "Or use admin consent URL:"
      info "https://login.microsoftonline.com/${ISV_TENANT_ID}/adminconsent?client_id=${CUSTOMER_APP_ID}"
    fi
    exit 1
  fi
done

info "Customer peering creation complete."
