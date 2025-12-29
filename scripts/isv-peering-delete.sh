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

  peering_name="${ISV_PEERING_NAME_PREFIX}-${customer_vnet}"

  info "Deleting ISV peering: $peering_name"
  az network vnet peering delete \
    --name "$peering_name" \
    --resource-group "$ISV_RESOURCE_GROUP" \
    --vnet-name "$ISV_VNET_NAME" >/dev/null 2>&1 || true
done

info "ISV peering deletion complete."
