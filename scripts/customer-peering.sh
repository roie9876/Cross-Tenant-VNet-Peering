#!/bin/bash
#
# Customer peering script (SPN login).
# Creates peering from the customer VNet(s) to the ISV VNet(s).
#
# Expected list format for ISV_VNETS:
#   "SUB_ID:RG_NAME/VNET_NAME,SUB_ID:RG_NAME/VNET_NAME,RG_NAME/VNET_NAME"
# If SUB_ID is omitted, ISV_SUBSCRIPTION_ID is used.
#
# Example:
#   ISV_VNETS="sub-a-1111:rg-isv-hub/vnet-isv-hub"

set -euo pipefail

###############################################################################
# CONFIGURATION
###############################################################################

CUSTOMER_TENANT_ID=""
CUSTOMER_SUBSCRIPTION_ID=""
CUSTOMER_APP_ID=""
CUSTOMER_APP_SECRET=""

CUSTOMER_RESOURCE_GROUP=""
CUSTOMER_VNET_NAME=""

ISV_SUBSCRIPTION_ID=""  # used when entries in ISV_VNETS do not include a subscription
ISV_VNETS=""

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

  rg="${rest%%/*}"
  vnet="${rest#*/}"

  if [[ -z "$sub_id" || -z "$rg" || -z "$vnet" || "$rg" == "$rest" ]]; then
    fail "Invalid VNet entry: $entry (expected SUB_ID:RG/VNET or RG/VNET)"
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
  az network vnet peering create \
    --name "$peering_name" \
    --resource-group "$CUSTOMER_RESOURCE_GROUP" \
    --vnet-name "$CUSTOMER_VNET_NAME" \
    --remote-vnet "$remote_id" \
    --allow-vnet-access "$ALLOW_VNET_ACCESS" \
    --allow-forwarded-traffic "$ALLOW_FORWARDED_TRAFFIC" \
    --allow-gateway-transit "$ALLOW_GATEWAY_TRANSIT" \
    --use-remote-gateways "$USE_REMOTE_GATEWAYS" >/dev/null
done

info "Customer peering creation complete."
