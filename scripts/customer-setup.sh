#!/bin/bash
#
# Customer setup script for cross-tenant VNet peering (SPN-first flow).
# This script:
#   1) Logs into the customer tenant/subscription.
#   2) Optionally creates a new RG + VNet.
#   3) Creates a multi-tenant App Registration + SPN + secret (prints the secret).
#   4) Creates/updates the custom vnet-peer role at RG scope.
#   5) Assigns the role to the CUSTOMER SPN on the target RG scopes.
#   6) (Optional) Registers the ISV SPN in the customer tenant and assigns it the role.
#
# You must run this as Owner/Contributor + User Access Administrator in the customer tenant.
# IMPORTANT: copy the secret shown at the end; it is only displayed once.

set -euo pipefail

###############################################################################
# CONFIGURATION
###############################################################################

# Tenant/subscription
CUSTOMER_TENANT_ID=""
CUSTOMER_SUBSCRIPTION_ID=""
CUSTOMER_LOCATION="eastus"

# RG/VNet options
CREATE_NEW_RG_VNET="false"  # true = create new RG+VNet, false = use existing
CUSTOMER_RESOURCE_GROUP="rg-customer-spoke"
CUSTOMER_VNET_NAME="vnet-customer-spoke"
CUSTOMER_VNET_ADDRESS_SPACE="10.100.0.0/16"
CUSTOMER_SUBNET_NAME="default"
CUSTOMER_SUBNET_PREFIX="10.100.1.0/24"

# SPN creation
CUSTOMER_APP_DISPLAY_NAME="customer-vnet-peering-spn"

# Optional: when you have the ISV App ID, set it here to register in customer tenant
ISV_APP_ID=""

# Role assignment scopes (RG level), comma-separated list:
# Format: "SUB_ID:RG_NAME,SUB_ID:RG_NAME,RG_NAME"
# If SUB_ID is omitted, CUSTOMER_SUBSCRIPTION_ID is used.
CUSTOMER_ROLE_SCOPES=""

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

  info "Creating or updating VNet: $CUSTOMER_VNET_NAME"
  az network vnet create \
    --resource-group "$CUSTOMER_RESOURCE_GROUP" \
    --name "$CUSTOMER_VNET_NAME" \
    --address-prefix "$CUSTOMER_VNET_ADDRESS_SPACE" \
    --subnet-name "$CUSTOMER_SUBNET_NAME" \
    --subnet-prefix "$CUSTOMER_SUBNET_PREFIX" >/dev/null
else
  info "Using existing RG/VNet: $CUSTOMER_RESOURCE_GROUP / $CUSTOMER_VNET_NAME"
fi

CUSTOMER_VNET_ID=$(az network vnet show \
  --resource-group "$CUSTOMER_RESOURCE_GROUP" \
  --name "$CUSTOMER_VNET_NAME" \
  --query id -o tsv)

###############################################################################
# CREATE MULTI-TENANT APP REGISTRATION + SPN + SECRET
###############################################################################

info "Creating multi-tenant App Registration: $CUSTOMER_APP_DISPLAY_NAME"
CUSTOMER_APP_ID=$(az ad app create \
  --display-name "$CUSTOMER_APP_DISPLAY_NAME" \
  --sign-in-audience AzureADMultipleOrgs \
  --query appId -o tsv)

info "Creating SPN for App ID: $CUSTOMER_APP_ID"
az ad sp create --id "$CUSTOMER_APP_ID" >/dev/null

info "Creating client secret for App ID: $CUSTOMER_APP_ID"
CUSTOMER_APP_SECRET=$(az ad app credential reset \
  --id "$CUSTOMER_APP_ID" \
  --append \
  --display-name "customer-spn-secret-$(date +%Y%m%d)" \
  --query password -o tsv)

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

ROLE_FILE="$(mktemp)"
cat > "$ROLE_FILE" <<EOF
{
  "properties": {
    "roleName": "${ROLE_NAME}",
    "description": "Allow VNet peering, sync and UDR changes on the scoped VNets.",
    "assignableScopes": [
      "$(printf '%s' "${ROLE_SCOPES[0]}")"
    ],
    "permissions": [
      {
        "actions": [
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
        "notActions": [],
        "dataActions": [],
        "notDataActions": []
      }
    ]
  }
}
EOF

info "Creating or updating custom role: $ROLE_NAME"
if ! az role definition create --role-definition "$ROLE_FILE" >/dev/null 2>&1; then
  az role definition update --role-definition "$ROLE_FILE" >/dev/null
fi
rm -f "$ROLE_FILE"

###############################################################################
# ASSIGN ROLE TO CUSTOMER SPN (ALL RG SCOPES)
###############################################################################

for scope in "${ROLE_SCOPES[@]}"; do
  info "Assigning role to customer SPN on scope: $scope"
  az role assignment create \
    --assignee "$CUSTOMER_APP_ID" \
    --role "$ROLE_NAME" \
    --scope "$scope" >/dev/null
done

###############################################################################
# OPTIONAL: REGISTER ISV SPN IN CUSTOMER TENANT + ASSIGN ROLE
###############################################################################

if [[ -n "$ISV_APP_ID" ]]; then
  info "Registering ISV SPN in customer tenant (App ID: $ISV_APP_ID)"
  if ! az ad sp create --id "$ISV_APP_ID" >/dev/null 2>&1; then
    info "If this failed, run admin consent in customer tenant:"
    info "https://login.microsoftonline.com/${CUSTOMER_TENANT_ID}/adminconsent?client_id=${ISV_APP_ID}"
    fail "ISV SPN registration failed."
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
CUSTOMER_VNET_NAME=${CUSTOMER_VNET_NAME}
CUSTOMER_VNET_ID=${CUSTOMER_VNET_ID}
CUSTOMER_APP_ID=${CUSTOMER_APP_ID}
CUSTOMER_APP_SECRET=${CUSTOMER_APP_SECRET}

Next steps:
- Share CUSTOMER_APP_ID with the ISV admin.
- Store CUSTOMER_APP_SECRET securely; it is required for the peering script.
EOF
