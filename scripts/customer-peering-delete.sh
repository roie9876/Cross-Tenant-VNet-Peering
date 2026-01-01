#!/bin/bash
#
# Customer peering delete script (ISV SPN login).
# Deletes peerings created by customer-peering.sh using the same prefix and VNet list.

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

read_env_value() {
  local file="$1"
  local key="$2"
  if [[ ! -f "$file" ]]; then
    return 0
  fi
  awk -F= -v key="$key" '
    $1 == key {
      val=$2
      sub(/^"/, "", val)
      sub(/"$/, "", val)
      print val
      exit
    }
  ' "$file"
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
# CONFIRMATION
###############################################################################

echo "This will delete customer peerings. Type 'delete' to continue:"
read -r CONFIRM
if [[ "$CONFIRM" != "delete" ]]; then
  fail "Aborted."
fi

###############################################################################
# LOGIN AND CONTEXT
###############################################################################

command -v az >/dev/null 2>&1 || fail "Azure CLI (az) is required."

ISV_ENV_FILE="${SCRIPT_DIR}/isv.env.sh"
if [[ -z "${ISV_APP_ID:-}" ]]; then
  ISV_APP_ID="$(read_env_value "$ISV_ENV_FILE" "ISV_APP_ID")"
fi
if [[ -z "${ISV_APP_SECRET:-}" ]]; then
  ISV_APP_SECRET="$(read_env_value "$ISV_ENV_FILE" "ISV_APP_SECRET")"
fi

if [[ -z "${ISV_APP_ID:-}" || -z "${ISV_APP_SECRET:-}" ]]; then
  fail "Missing ISV_APP_ID or ISV_APP_SECRET (set in scripts/customer.env.sh or scripts/isv.env.sh)"
fi

info "Logging in with ISV SPN"
az login --service-principal \
  --username "$ISV_APP_ID" \
  --password "$ISV_APP_SECRET" \
  --tenant "$CUSTOMER_TENANT_ID" >/dev/null

az account set --subscription "$CUSTOMER_SUBSCRIPTION_ID"

###############################################################################
# DELETE PEERINGS
###############################################################################

IFS=',' read -r -a VNET_ITEMS <<< "$ISV_VNETS"
if [[ ${#VNET_ITEMS[@]} -eq 0 ]]; then
  fail "ISV_VNETS is empty. Provide at least one VNet entry."
fi

CUSTOMER_VNET_NAMES=($(get_customer_vnet_names))
if [[ ${#CUSTOMER_VNET_NAMES[@]} -eq 0 ]]; then
  fail "No customer VNets defined. Set CUSTOMER_VNET_NAME_1 and related fields in scripts/customer.env.sh."
fi

for customer_vnet in "${CUSTOMER_VNET_NAMES[@]}"; do
  for item in "${VNET_ITEMS[@]}"; do
    parsed=$(parse_vnet_entry "$item")
    isv_sub="${parsed%%|*}"
    rest="${parsed#*|}"
    isv_rg="${rest%%|*}"
    isv_vnet="${rest#*|}"

    peering_name="${CUSTOMER_PEERING_NAME_PREFIX}-${customer_vnet}-to-${isv_vnet}"

    info "Deleting customer peering: $peering_name"
    az network vnet peering delete \
      --name "$peering_name" \
      --resource-group "$CUSTOMER_RESOURCE_GROUP" \
      --vnet-name "$customer_vnet" >/dev/null 2>&1 || true
  done
done

info "Customer peering deletion complete."
