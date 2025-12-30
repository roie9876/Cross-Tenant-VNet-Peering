#!/bin/bash
#
# Customer peering script (SPN login).
# Creates peering from each customer VNet (CUSTOMER_VNET_NAME_*) to the ISV VNet(s).
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
CUSTOMER_UDR_NAME_PREFIX="udr-to-isv-lb"

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
require_value "CUSTOMER_RESOURCE_GROUP" "$CUSTOMER_RESOURCE_GROUP"
require_value "CUSTOMER_LOCATION" "$CUSTOMER_LOCATION"
require_value "ISV_TENANT_ID" "$ISV_TENANT_ID"
require_value "ISV_SUBSCRIPTION_ID" "$ISV_SUBSCRIPTION_ID"
require_value "ISV_RESOURCE_GROUP" "$ISV_RESOURCE_GROUP"
require_value "ISV_VNETS" "$ISV_VNETS"
if [[ "${CUSTOMER_UDR_ENABLE:-false}" == "true" ]]; then
  require_value "CUSTOMER_UDR_NEXT_HOP_IP" "$CUSTOMER_UDR_NEXT_HOP_IP"
fi

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
  fail "No customer VNets defined. Set CUSTOMER_VNET_NAME_1 and related fields in scripts/customer.env.sh."
fi

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

ISV_ENV_FILE="${SCRIPT_DIR}/isv.env.sh"
if [[ -z "${ISV_APP_ID:-}" ]]; then
  ISV_APP_ID="$(read_env_value "$ISV_ENV_FILE" "ISV_APP_ID")"
fi
if [[ -z "${ISV_APP_SECRET:-}" ]]; then
  ISV_APP_SECRET="$(read_env_value "$ISV_ENV_FILE" "ISV_APP_SECRET")"
fi

LOGIN_APP_ID="${CUSTOMER_APP_ID:-}"
LOGIN_APP_SECRET="${CUSTOMER_APP_SECRET:-}"
LOGIN_LABEL="customer SPN"
MISSING_SP_URL="https://login.microsoftonline.com/${ISV_TENANT_ID}/adminconsent?client_id=${CUSTOMER_APP_ID:-}"
MISSING_SP_MSG="Customer SPN likely not registered in ISV tenant."

if [[ -z "$LOGIN_APP_ID" || -z "$LOGIN_APP_SECRET" ]]; then
  if [[ -n "${ISV_APP_ID:-}" && -n "${ISV_APP_SECRET:-}" ]]; then
    LOGIN_APP_ID="$ISV_APP_ID"
    LOGIN_APP_SECRET="$ISV_APP_SECRET"
    LOGIN_LABEL="ISV SPN (registered in customer tenant)"
    MISSING_SP_URL="https://login.microsoftonline.com/${CUSTOMER_TENANT_ID}/adminconsent?client_id=${ISV_APP_ID}"
    MISSING_SP_MSG="ISV SPN likely not registered in customer tenant."
  fi
fi

require_value "LOGIN_APP_ID" "$LOGIN_APP_ID"
require_value "LOGIN_APP_SECRET" "$LOGIN_APP_SECRET"


###############################################################################
# LOGIN AND CONTEXT
###############################################################################

command -v az >/dev/null 2>&1 || fail "Azure CLI (az) is required."

info "Logging in with ${LOGIN_LABEL}"
az login --service-principal \
  --username "$LOGIN_APP_ID" \
  --password "$LOGIN_APP_SECRET" \
  --tenant "$CUSTOMER_TENANT_ID" >/dev/null

az account set --subscription "$CUSTOMER_SUBSCRIPTION_ID"

###############################################################################
# CREATE PEERINGS
###############################################################################

IFS=',' read -r -a VNET_ITEMS <<< "$ISV_VNETS"
if [[ ${#VNET_ITEMS[@]} -eq 0 ]]; then
  fail "ISV_VNETS is empty. Provide at least one VNet entry."
fi

for customer_vnet in "${CUSTOMER_VNET_NAMES[@]}"; do
  for item in "${VNET_ITEMS[@]}"; do
    parsed=$(parse_vnet_entry "$item")
    isv_sub="${parsed%%|*}"
    rest="${parsed#*|}"
    isv_rg="${rest%%|*}"
    isv_vnet="${rest#*|}"

    remote_id="/subscriptions/${isv_sub}/resourceGroups/${isv_rg}/providers/Microsoft.Network/virtualNetworks/${isv_vnet}"
    peering_name="${CUSTOMER_PEERING_NAME_PREFIX}-${customer_vnet}-to-${isv_vnet}"

    info "Creating customer peering: $peering_name -> $remote_id"
    if ! output=$(az network vnet peering create \
      --name "$peering_name" \
      --resource-group "$CUSTOMER_RESOURCE_GROUP" \
      --vnet-name "$customer_vnet" \
      --remote-vnet "$remote_id" \
      --allow-vnet-access "$ALLOW_VNET_ACCESS" \
      --allow-forwarded-traffic "$ALLOW_FORWARDED_TRAFFIC" \
      --allow-gateway-transit "$ALLOW_GATEWAY_TRANSIT" \
      --use-remote-gateways "$USE_REMOTE_GATEWAYS" 2>&1); then
      echo "$output" >&2
      if echo "$output" | grep -E -q "missing service principal|AADSTS7000229"; then
        info "$MISSING_SP_MSG"
        info "Ask the target tenant admin to run the appropriate register script."
        info "Or use admin consent URL:"
        info "$MISSING_SP_URL"
      fi
      exit 1
    fi
  done
done

if [[ "${CUSTOMER_UDR_ENABLE:-false}" == "true" ]]; then
  for customer_vnet in "${CUSTOMER_VNET_NAMES[@]}"; do
    udr_name="${CUSTOMER_UDR_NAME_PREFIX}-${customer_vnet}"
    info "Creating route table: $udr_name"
    az network route-table create \
      --name "$udr_name" \
      --resource-group "$CUSTOMER_RESOURCE_GROUP" \
      --location "$CUSTOMER_LOCATION" >/dev/null

    info "Creating routes from $customer_vnet to other customer VNets (next hop: $CUSTOMER_UDR_NEXT_HOP_IP)"
    route_index=1
    seen_prefixes=""

    for other_vnet in "${CUSTOMER_VNET_NAMES[@]}"; do
      if [[ "$other_vnet" == "$customer_vnet" ]]; then
        continue
      fi

      for prefix in $(az network vnet show \
        --resource-group "$CUSTOMER_RESOURCE_GROUP" \
        --name "$other_vnet" \
        --subscription "$CUSTOMER_SUBSCRIPTION_ID" \
        --query "addressSpace.addressPrefixes[]" -o tsv); do
        case " $seen_prefixes " in
          *" $prefix "*)
            continue
            ;;
        esac
        az network route-table route create \
          --resource-group "$CUSTOMER_RESOURCE_GROUP" \
          --route-table-name "$udr_name" \
          --name "to-customer-${route_index}" \
          --address-prefix "$prefix" \
          --next-hop-type "VirtualAppliance" \
          --next-hop-ip-address "$CUSTOMER_UDR_NEXT_HOP_IP" >/dev/null
        seen_prefixes="${seen_prefixes} ${prefix}"
        route_index=$((route_index + 1))
      done
    done

    info "Associating route table to all subnets in $customer_vnet"
    for subnet in $(az network vnet subnet list \
      --resource-group "$CUSTOMER_RESOURCE_GROUP" \
      --vnet-name "$customer_vnet" \
      --query "[].name" -o tsv); do
      az network vnet subnet update \
        --resource-group "$CUSTOMER_RESOURCE_GROUP" \
        --vnet-name "$customer_vnet" \
        --name "$subnet" \
        --route-table "$udr_name" >/dev/null
    done
  done
fi

info "Customer peering creation complete."
