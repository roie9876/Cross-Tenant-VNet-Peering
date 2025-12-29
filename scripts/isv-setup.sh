#!/bin/bash
#
# ISV setup script for cross-tenant VNet peering (SPN-first flow).
# This script:
#   1) Logs into the ISV tenant/subscription.
#   2) Optionally creates a new RG + VNet.
#   3) Creates a multi-tenant App Registration + SPN + secret (prints the secret).
#   4) Creates/updates the custom vnet-peer role at RG scope.
#   5) Assigns the role to the ISV SPN on the ISV RG.
#   6) (Optional) Registers the CUSTOMER SPN in the ISV tenant and assigns it the role.
#
# You must run this as Owner/Contributor + User Access Administrator in the ISV tenant.
# IMPORTANT: copy the secret shown at the end; it is only displayed once.

set -euo pipefail

###############################################################################
# CONFIGURATION
###############################################################################

# Tenant/subscription
ISV_TENANT_ID=""
ISV_SUBSCRIPTION_ID=""
ISV_LOCATION="eastus"

# RG/VNet options
CREATE_NEW_RG_VNET="true"  # true = create new RG+VNet, false = use existing
ISV_RESOURCE_GROUP="rg-isv-hub"
ISV_VNET_NAME="vnet-isv-hub"
ISV_VNET_ADDRESS_SPACE="10.0.0.0/16"
ISV_SUBNET_NAME="default"
ISV_SUBNET_PREFIX="10.0.1.0/24"

# SPN creation
ISV_APP_DISPLAY_NAME="isv-vnet-peering-spn"

# Optional: when you have the customer's App ID, set it here to register in ISV tenant
CUSTOMER_APP_ID=""

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

###############################################################################
# LOGIN AND CONTEXT
###############################################################################

command -v az >/dev/null 2>&1 || fail "Azure CLI (az) is required."

info "Logging into ISV tenant: $ISV_TENANT_ID"
az login --tenant "$ISV_TENANT_ID" >/dev/null
az account set --subscription "$ISV_SUBSCRIPTION_ID"

###############################################################################
# OPTIONAL RG + VNET CREATION
###############################################################################

if [[ "$CREATE_NEW_RG_VNET" == "true" ]]; then
  info "Ensuring resource group exists: $ISV_RESOURCE_GROUP"
  az group create --name "$ISV_RESOURCE_GROUP" --location "$ISV_LOCATION" >/dev/null

  info "Creating or updating VNet: $ISV_VNET_NAME"
  az network vnet create \
    --resource-group "$ISV_RESOURCE_GROUP" \
    --name "$ISV_VNET_NAME" \
    --address-prefix "$ISV_VNET_ADDRESS_SPACE" \
    --subnet-name "$ISV_SUBNET_NAME" \
    --subnet-prefix "$ISV_SUBNET_PREFIX" >/dev/null
else
  info "Using existing RG/VNet: $ISV_RESOURCE_GROUP / $ISV_VNET_NAME"
fi

ISV_VNET_ID=$(az network vnet show \
  --resource-group "$ISV_RESOURCE_GROUP" \
  --name "$ISV_VNET_NAME" \
  --query id -o tsv)

###############################################################################
# CREATE MULTI-TENANT APP REGISTRATION + SPN + SECRET
###############################################################################

info "Creating multi-tenant App Registration: $ISV_APP_DISPLAY_NAME"
ISV_APP_ID=$(az ad app create \
  --display-name "$ISV_APP_DISPLAY_NAME" \
  --sign-in-audience AzureADMultipleOrgs \
  --query appId -o tsv)

info "Creating SPN for App ID: $ISV_APP_ID"
az ad sp create --id "$ISV_APP_ID" >/dev/null

info "Creating client secret for App ID: $ISV_APP_ID"
ISV_APP_SECRET=$(az ad app credential reset \
  --id "$ISV_APP_ID" \
  --append \
  --display-name "isv-spn-secret-$(date +%Y%m%d)" \
  --query password -o tsv)

###############################################################################
# CREATE/UPDATE CUSTOM ROLE AT RG SCOPE
###############################################################################

ROLE_NAME="vnet-peer"
ROLE_SCOPE="/subscriptions/${ISV_SUBSCRIPTION_ID}/resourceGroups/${ISV_RESOURCE_GROUP}"

ROLE_FILE="$(mktemp)"
cat > "$ROLE_FILE" <<EOF
{
  "properties": {
    "roleName": "${ROLE_NAME}",
    "description": "Allow VNet peering, sync and UDR changes on the scoped VNets.",
    "assignableScopes": [
      "${ROLE_SCOPE}"
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
# ASSIGN ROLE TO ISV SPN
###############################################################################

info "Assigning role to ISV SPN on ISV RG scope"
az role assignment create \
  --assignee "$ISV_APP_ID" \
  --role "$ROLE_NAME" \
  --scope "$ROLE_SCOPE" >/dev/null

###############################################################################
# OPTIONAL: REGISTER CUSTOMER SPN IN ISV TENANT + ASSIGN ROLE
###############################################################################

if [[ -n "$CUSTOMER_APP_ID" ]]; then
  info "Registering customer SPN in ISV tenant (App ID: $CUSTOMER_APP_ID)"
  if ! az ad sp create --id "$CUSTOMER_APP_ID" >/dev/null 2>&1; then
    info "If this failed, run admin consent in ISV tenant:"
    info "https://login.microsoftonline.com/${ISV_TENANT_ID}/adminconsent?client_id=${CUSTOMER_APP_ID}"
    fail "Customer SPN registration failed."
  fi

  info "Assigning role to customer SPN on ISV RG scope"
  az role assignment create \
    --assignee "$CUSTOMER_APP_ID" \
    --role "$ROLE_NAME" \
    --scope "$ROLE_SCOPE" >/dev/null
else
  info "CUSTOMER_APP_ID not set; skip customer SPN registration/role assignment."
fi

###############################################################################
# OUTPUTS
###############################################################################

cat <<EOF

=== ISV SETUP OUTPUTS (COPY THESE) ===
ISV_TENANT_ID=${ISV_TENANT_ID}
ISV_SUBSCRIPTION_ID=${ISV_SUBSCRIPTION_ID}
ISV_RESOURCE_GROUP=${ISV_RESOURCE_GROUP}
ISV_VNET_NAME=${ISV_VNET_NAME}
ISV_VNET_ID=${ISV_VNET_ID}
ISV_APP_ID=${ISV_APP_ID}
ISV_APP_SECRET=${ISV_APP_SECRET}

Next steps:
- Share ISV_APP_ID with the customer admin.
- Store ISV_APP_SECRET securely; it is required for the peering script.
EOF
