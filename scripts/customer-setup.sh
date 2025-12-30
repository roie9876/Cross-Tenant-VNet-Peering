#!/bin/bash
#
# Customer setup script for cross-tenant VNet peering (SPN-first flow).
# This script:
#   1) Logs into the customer tenant/subscription.
#   2) Optionally creates a new RG + VNet.
#   3) Creates/updates the custom vnet-peer role at RG scope.
#   4) Registers the ISV SPN in the customer tenant and assigns it the role.
#
# You must run this as Owner/Contributor + User Access Administrator in the customer tenant.
# IMPORTANT: copy the secret shown at the end; it is only displayed once.

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

require_value() {
  local name="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    fail "Missing required value: $name (set it in scripts/customer.env.sh)"
  fi
}

require_value "CUSTOMER_TENANT_ID" "$CUSTOMER_TENANT_ID"
require_value "CUSTOMER_SUBSCRIPTION_ID" "$CUSTOMER_SUBSCRIPTION_ID"
require_value "ISV_APP_ID" "$ISV_APP_ID"
if [[ "$CREATE_NEW_RG_VNET" == "true" ]]; then
  require_value "CUSTOMER_LOCATION" "$CUSTOMER_LOCATION"
fi

get_customer_vnet_indices() {
  local indices=()
  local var
  for var in ${!CUSTOMER_VNET_NAME_@}; do
    local idx="${var##*_}"
    if [[ -n "${!var}" ]]; then
      indices+=("$idx")
    fi
  done
  echo "${indices[@]}"
}

get_var() {
  local name="$1"
  local value="${!name}"
  echo "$value"
}

VNET_INDICES=($(get_customer_vnet_indices))
if [[ ${#VNET_INDICES[@]} -eq 0 ]]; then
  fail "No customer VNets defined. Set CUSTOMER_VNET_NAME_1 and related fields in scripts/customer.env.sh."
fi

for idx in "${VNET_INDICES[@]}"; do
  require_value "CUSTOMER_VNET_NAME_${idx}" "$(get_var "CUSTOMER_VNET_NAME_${idx}")"
  require_value "CUSTOMER_VNET_ADDRESS_SPACE_${idx}" "$(get_var "CUSTOMER_VNET_ADDRESS_SPACE_${idx}")"
  require_value "CUSTOMER_SUBNET_NAME_${idx}" "$(get_var "CUSTOMER_SUBNET_NAME_${idx}")"
  require_value "CUSTOMER_SUBNET_PREFIX_${idx}" "$(get_var "CUSTOMER_SUBNET_PREFIX_${idx}")"
done

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

###############################################################################
# LOGIN AND CONTEXT
###############################################################################

command -v az >/dev/null 2>&1 || fail "Azure CLI (az) is required."

info "Logging into customer tenant: $CUSTOMER_TENANT_ID"
az login --tenant "$CUSTOMER_TENANT_ID" >/dev/null
az account set --subscription "$CUSTOMER_SUBSCRIPTION_ID"

###############################################################################
# OPTIONAL RG + VNET CREATION
###############################################################################

if [[ "$CREATE_NEW_RG_VNET" == "true" ]]; then
  info "Ensuring resource group exists: $CUSTOMER_RESOURCE_GROUP"
  az group create --name "$CUSTOMER_RESOURCE_GROUP" --location "$CUSTOMER_LOCATION" >/dev/null

  for idx in "${VNET_INDICES[@]}"; do
    vnet_name="$(get_var "CUSTOMER_VNET_NAME_${idx}")"
    vnet_space="$(get_var "CUSTOMER_VNET_ADDRESS_SPACE_${idx}")"
    subnet_name="$(get_var "CUSTOMER_SUBNET_NAME_${idx}")"
    subnet_prefix="$(get_var "CUSTOMER_SUBNET_PREFIX_${idx}")"

    info "Creating or updating VNet: $vnet_name"
    az network vnet create \
      --resource-group "$CUSTOMER_RESOURCE_GROUP" \
      --name "$vnet_name" \
      --address-prefix "$vnet_space" \
      --subnet-name "$subnet_name" \
      --subnet-prefix "$subnet_prefix" >/dev/null
  done
else
  info "Using existing RG/VNets in: $CUSTOMER_RESOURCE_GROUP"
fi

CUSTOMER_VNET_IDS=()
for idx in "${VNET_INDICES[@]}"; do
  vnet_name="$(get_var "CUSTOMER_VNET_NAME_${idx}")"
  vnet_id=$(az network vnet show \
    --resource-group "$CUSTOMER_RESOURCE_GROUP" \
    --name "$vnet_name" \
    --query id -o tsv)
  CUSTOMER_VNET_IDS+=("$vnet_id")
done

###############################################################################
# CREATE/UPDATE CUSTOM ROLE AT RG SCOPE
###############################################################################

ROLE_NAME="vnet-peer"

ROLE_SCOPE_LIST="$CUSTOMER_ROLE_SCOPES"
if [[ -z "$ROLE_SCOPE_LIST" ]]; then
  ROLE_SCOPE_LIST="${CUSTOMER_SUBSCRIPTION_ID}:${CUSTOMER_RESOURCE_GROUP}"
fi

ROLE_SCOPES=()
IFS=',' read -r -a SCOPE_ITEMS <<< "$ROLE_SCOPE_LIST"
for item in "${SCOPE_ITEMS[@]}"; do
  ROLE_SCOPES+=("$(parse_scope_entry "$item")")
done

ROLE_ID=$(az role definition list --name "$ROLE_NAME" --query "[0].name" -o tsv 2>/dev/null || true)

ROLE_FILE="$(mktemp)"
if [[ -z "$ROLE_ID" ]]; then
  cat > "$ROLE_FILE" <<EOF
{
  "Name": "${ROLE_NAME}",
  "IsCustom": true,
  "Description": "Allow VNet peering, sync and UDR changes on the scoped VNets.",
  "Actions": [
    "Microsoft.Network/virtualNetworks/read",
    "Microsoft.Network/virtualNetworks/write",
    "Microsoft.Network/virtualNetworks/subnets/read",
    "Microsoft.Network/virtualNetworks/subnets/write",
    "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/read",
    "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write",
    "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/delete",
    "Microsoft.Network/virtualNetworks/peer/action",
    "Microsoft.Network/routeTables/read",
    "Microsoft.Network/routeTables/write",
    "Microsoft.Network/routeTables/delete",
    "Microsoft.Network/routeTables/routes/read",
    "Microsoft.Network/routeTables/routes/write",
    "Microsoft.Network/routeTables/routes/delete",
    "Microsoft.Network/routeTables/join/action",
    "Microsoft.Network/networkSecurityGroups/read",
    "Microsoft.Network/networkSecurityGroups/join/action"
  ],
  "NotActions": [],
  "DataActions": [],
  "NotDataActions": [],
  "AssignableScopes": [
    "$(printf '%s' "${ROLE_SCOPES[0]}")"
  ]
}
EOF
  info "Creating custom role: $ROLE_NAME"
  az role definition create --role-definition "$ROLE_FILE" >/dev/null
else
  cat > "$ROLE_FILE" <<EOF
{
  "Name": "${ROLE_NAME}",
  "IsCustom": true,
  "Description": "Allow VNet peering, sync and UDR changes on the scoped VNets.",
  "Actions": [
    "Microsoft.Network/virtualNetworks/read",
    "Microsoft.Network/virtualNetworks/write",
    "Microsoft.Network/virtualNetworks/subnets/read",
    "Microsoft.Network/virtualNetworks/subnets/write",
    "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/read",
    "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write",
    "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/delete",
    "Microsoft.Network/virtualNetworks/peer/action",
    "Microsoft.Network/routeTables/read",
    "Microsoft.Network/routeTables/write",
    "Microsoft.Network/routeTables/delete",
    "Microsoft.Network/routeTables/routes/read",
    "Microsoft.Network/routeTables/routes/write",
    "Microsoft.Network/routeTables/routes/delete",
    "Microsoft.Network/routeTables/join/action",
    "Microsoft.Network/networkSecurityGroups/read",
    "Microsoft.Network/networkSecurityGroups/join/action"
  ],
  "NotActions": [],
  "DataActions": [],
  "NotDataActions": [],
  "AssignableScopes": [
    "$(printf '%s' "${ROLE_SCOPES[0]}")"
  ]
}
EOF
  info "Updating custom role: $ROLE_NAME"
  az role definition update --role-definition "$ROLE_FILE" >/dev/null
fi
rm -f "$ROLE_FILE"

###############################################################################
# REGISTER ISV SPN IN CUSTOMER TENANT + ASSIGN ROLE
###############################################################################

if [[ -n "$ISV_APP_ID" ]]; then
  info "Registering ISV SPN in customer tenant (App ID: $ISV_APP_ID)"
  if ! az ad sp show --id "$ISV_APP_ID" >/dev/null 2>&1; then
    if ! az ad sp create --id "$ISV_APP_ID" >/dev/null 2>&1; then
      info "If this failed, run admin consent in customer tenant:"
      info "https://login.microsoftonline.com/${CUSTOMER_TENANT_ID}/adminconsent?client_id=${ISV_APP_ID}"
      fail "ISV SPN registration failed."
    fi
  fi

  for scope in "${ROLE_SCOPES[@]}"; do
    info "Assigning role to ISV SPN on scope: $scope"
    az role assignment create \
      --assignee "$ISV_APP_ID" \
      --role "$ROLE_NAME" \
      --scope "$scope" >/dev/null
  done
else
  info "ISV_APP_ID not set; skip ISV SPN registration/role assignment."
fi

###############################################################################
# OUTPUTS
###############################################################################

cat <<EOF

=== CUSTOMER SETUP OUTPUTS (COPY THESE) ===
CUSTOMER_TENANT_ID=${CUSTOMER_TENANT_ID}
CUSTOMER_SUBSCRIPTION_ID=${CUSTOMER_SUBSCRIPTION_ID}
CUSTOMER_RESOURCE_GROUP=${CUSTOMER_RESOURCE_GROUP}
CUSTOMER_VNET_NAMES=$(for idx in "${VNET_INDICES[@]}"; do printf "%s " "$(get_var "CUSTOMER_VNET_NAME_${idx}")"; done)
CUSTOMER_VNET_IDS=$(printf "%s " "${CUSTOMER_VNET_IDS[@]}")
CUSTOMER_VNETS_EXAMPLE="$(for idx in "${VNET_INDICES[@]}"; do printf "%s " "$(get_var "CUSTOMER_VNET_NAME_${idx}")"; done)"

Next steps:
- Confirm ISV_APP_ID is set in scripts/customer.env.sh.
- The ISV SPN now has vnet-peer in the customer tenant.
EOF
