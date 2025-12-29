#!/bin/bash
#
# ISV peering script (SPN login).
# Creates peering from the ISV VNet to one or more customer VNets.
#
# Expected list format for CUSTOMER_VNETS:
#   "SUB_ID:RG_NAME/VNET_NAME,SUB_ID:RG_NAME/VNET_NAME,RG_NAME/VNET_NAME"
# If SUB_ID is omitted, CUSTOMER_SUBSCRIPTION_ID is used.
#
# Example:
#   CUSTOMER_VNETS="sub-b-1111:rg-cust-1/vnet-cust-1,sub-b-2222:rg-cust-2/vnet-cust-2"

set -euo pipefail

###############################################################################
# CONFIGURATION
###############################################################################

ISV_TENANT_ID=""
ISV_SUBSCRIPTION_ID=""
ISV_APP_ID=""
ISV_APP_SECRET=""

ISV_RESOURCE_GROUP=""
ISV_VNET_NAME=""

CUSTOMER_SUBSCRIPTION_ID=""  # used when entries in CUSTOMER_VNETS do not include a subscription
CUSTOMER_VNETS=""

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
  az network vnet peering create \
    --name "$peering_name" \
    --resource-group "$ISV_RESOURCE_GROUP" \
    --vnet-name "$ISV_VNET_NAME" \
    --remote-vnet "$remote_id" \
    --allow-vnet-access "$ALLOW_VNET_ACCESS" \
    --allow-forwarded-traffic "$ALLOW_FORWARDED_TRAFFIC" \
    --allow-gateway-transit "$ALLOW_GATEWAY_TRANSIT" \
    --use-remote-gateways "$USE_REMOTE_GATEWAYS" >/dev/null
done

info "ISV peering creation complete."
