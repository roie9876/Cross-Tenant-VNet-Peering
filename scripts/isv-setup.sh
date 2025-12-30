#!/bin/bash
#
# ISV setup script for cross-tenant VNet peering (SPN-first flow).
# This script:
#   1) Logs into the ISV tenant/subscription.
#   2) Optionally creates a new RG + VNet.
#   3) Creates a multi-tenant App Registration + SPN + secret (prints the secret).
#   4) Creates/updates the custom vnet-peer role at RG scope.
#   5) Assigns the role to the ISV SPN on the ISV RG.
#
# You must run this as Owner/Contributor + User Access Administrator in the ISV tenant.
# IMPORTANT: copy the secret shown at the end; it is only displayed once.

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
require_value "ISV_RESOURCE_GROUP" "$ISV_RESOURCE_GROUP"
require_value "ISV_VNET_NAME" "$ISV_VNET_NAME"
require_value "ISV_APP_DISPLAY_NAME" "$ISV_APP_DISPLAY_NAME"
if [[ "$CREATE_NEW_RG_VNET" == "true" ]]; then
  require_value "ISV_LOCATION" "$ISV_LOCATION"
  require_value "ISV_VNET_ADDRESS_SPACE" "$ISV_VNET_ADDRESS_SPACE"
  require_value "ISV_SUBNET_NAME" "$ISV_SUBNET_NAME"
  require_value "ISV_SUBNET_PREFIX" "$ISV_SUBNET_PREFIX"
fi

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
if ! az ad sp show --id "$ISV_APP_ID" >/dev/null 2>&1; then
  az ad sp create --id "$ISV_APP_ID" >/dev/null
else
  info "SPN already exists for App ID: $ISV_APP_ID"
fi

info "Creating client secret for App ID: $ISV_APP_ID"
ISV_APP_SECRET=$(az ad app credential reset \
  --id "$ISV_APP_ID" \
  --append \
  --display-name "isv-spn-secret-$(date +%Y%m%d)" \
  --query password -o tsv)

info "Updating scripts/isv.env.sh with ISV_APP_ID and ISV_APP_SECRET"
ENV_FILE_PATH="$ENV_FILE" ISV_APP_ID="$ISV_APP_ID" ISV_APP_SECRET="$ISV_APP_SECRET" python - <<'PY'
from pathlib import Path
import os

env_path = Path(os.environ["ENV_FILE_PATH"])
text = env_path.read_text()

def set_var(name, value, content):
    lines = content.splitlines()
    out = []
    found = False
    for line in lines:
        if line.startswith(f"{name}="):
            out.append(f'{name}="{value}"')
            found = True
        else:
            out.append(line)
    if not found:
        out.append(f'{name}="{value}"')
    return "\n".join(out) + "\n"

env = text
env = set_var("ISV_APP_ID", os.environ["ISV_APP_ID"], env)
env = set_var("ISV_APP_SECRET", os.environ["ISV_APP_SECRET"], env)
env_path.write_text(env)
PY

if [[ -f "${SCRIPT_DIR}/customer.env.sh" ]]; then
  info "Updating scripts/customer.env.sh with ISV_APP_ID (demo convenience)"
  ENV_FILE_PATH="${SCRIPT_DIR}/customer.env.sh" ISV_APP_ID="$ISV_APP_ID" python - <<'PY'
from pathlib import Path
import os

env_path = Path(os.environ["ENV_FILE_PATH"])
text = env_path.read_text()

def set_var(name, value, content):
    lines = content.splitlines()
    out = []
    found = False
    for line in lines:
        if line.startswith(f"{name}="):
            out.append(f'{name}="{value}"')
            found = True
        else:
            out.append(line)
    if not found:
        out.append(f'{name}="{value}"')
    return "\n".join(out) + "\n"

env = text
env = set_var("ISV_APP_ID", os.environ["ISV_APP_ID"], env)
env_path.write_text(env)
PY
fi

###############################################################################
# CREATE/UPDATE CUSTOM ROLE AT RG SCOPE
###############################################################################

ROLE_NAME="vnet-peer"
ROLE_SCOPE="/subscriptions/${ISV_SUBSCRIPTION_ID}/resourceGroups/${ISV_RESOURCE_GROUP}"

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
    "${ROLE_SCOPE}"
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
    "${ROLE_SCOPE}"
  ]
}
EOF
  info "Updating custom role: $ROLE_NAME"
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
ISV_VNETS_EXAMPLE="${ISV_SUBSCRIPTION_ID}:${ISV_RESOURCE_GROUP}/${ISV_VNET_NAME}"

Next steps:
- Share ISV_APP_ID with the customer admin.
- Store ISV_APP_SECRET securely; it is required for the peering script.
- Paste ISV_APP_ID and ISV_APP_SECRET into scripts/isv.env.sh
EOF
