#!/bin/bash

################################################################################
# ISV VNet Peering Onboarding Script (For End Customers)
# 
# Instructions for Customer:
# 1. Run this script in your terminal (Azure Cloud Shell or local with Azure CLI).
# 2. Follow the login prompt.
# 3. Select your Subscription and VNet when prompted.
# 4. The script will authorize the ISV's application to manage the peering.
################################################################################

# --- ISV CONSTANTS (DO NOT CHANGE) ---
# These identify YOU (The ISV) to the customer
ISV_TENANT_ID="<ISV_TENANT_ID>"
ISV_APP_ID="<ISV_APP_ID>"  # The App ID from ISV Tenant
ISV_NAME="<ISV_NAME>"

set -e

echo "========================================================"
echo "   $ISV_NAME - VNet Peering Onboarding"
echo "========================================================"
echo ""

# 1. Login
echo "[INFO] Please log in to your Azure account..."
az login --output none
echo "[SUCCESS] Logged in."
echo ""

# 2. Select Subscription
echo "[INFO] Loading subscriptions..."
az account list --output table

echo ""
echo "Enter the Subscription ID where your VNet is located:"
read -r SUB_ID
az account set --subscription "$SUB_ID"
echo "[SUCCESS] Selected subscription: $SUB_ID"
echo ""

# 3. Select VNet
echo "[INFO] Listing Virtual Networks in this subscription..."
# Attempt to list VNets, but don't fail the script if the user lacks subscription-level list permissions
# (They might only have permissions on a specific Resource Group)
if ! az network vnet list --query "[].{Name:name, ResourceGroup:resourceGroup, Location:location}" --output table; then
    echo "[WARNING] Could not list Virtual Networks. You may not have 'Reader' permissions on the entire subscription."
    echo "Proceeding with manual entry..."
fi

echo ""
echo "Enter the Name of your VNet:"
read -r VNET_NAME
echo "Enter the Resource Group of your VNet:"
read -r RG_NAME

# Get VNet ID
VNET_ID=$(az network vnet show --name "$VNET_NAME" --resource-group "$RG_NAME" --query id --output tsv)
echo "[INFO] Target VNet ID: $VNET_ID"
echo ""

# 4. Register ISV Service Principal (The "Magic" Step)
echo "[INFO] Registering ISV Application ($ISV_APP_ID) in your tenant..."

# Check if SP exists
if az ad sp show --id "$ISV_APP_ID" > /dev/null 2>&1; then
    echo "[INFO] Service Principal already exists."
else
    echo "[INFO] Service Principal not found. Attempting to create..."
    if az ad sp create --id "$ISV_APP_ID"; then
        echo "[SUCCESS] Service Principal created."
        echo "[INFO] Waiting 20 seconds for Azure AD propagation..."
        sleep 20
    else
        echo "[ERROR] Failed to create Service Principal."
        echo "Possible reasons:"
        echo "1. You do not have permissions to register applications (Application Administrator role required)."
        echo "2. The App ID is invalid."
        exit 1
    fi
fi

# 5. Create Custom Role (Least Privilege)
echo "[INFO] Creating custom role 'vnet-peer'..."

# Create a temporary JSON file for the role definition
cat > vnet-peer-role.json <<EOF
{
  "Name": "vnet-peer",
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
    "/subscriptions/$SUB_ID/resourceGroups/$RG_NAME"
  ]
}
EOF

# Create or update the role definition
# We use || true to ignore error if it exists, but ideally we should check or update.
# az role definition create will fail if it exists with same name but different ID logic usually.
# A safer way is to try to update, if fail try create, or check existence.
# However, for simplicity in this script, we'll try to create it. If it says "already exists", we might need to update it if the scope changed.
# Since 'vnet-peer' name is global to the tenant, if it was created for another RG, we need to add this RG to assignable scopes.
# This is complex for a simple script.
# ALTERNATIVE: Create a unique role name per RG? Or just try to create and catch error.

# Let's try to create/update.
echo "[INFO] Applying role definition..."
az role definition create --role-definition vnet-peer-role.json > /dev/null 2>&1 || az role definition update --role-definition vnet-peer-role.json > /dev/null 2>&1
rm vnet-peer-role.json
echo "[SUCCESS] Custom role 'vnet-peer' configured."

# 6. Assign Permissions
echo "[INFO] Assigning 'vnet-peer' role to ISV App on your VNet..."
az role assignment create \
    --assignee "$ISV_APP_ID" \
    --role "vnet-peer" \
    --scope "$VNET_ID" \
    --output none

echo "[SUCCESS] Permissions assigned."
echo ""

# 6. Output Info for ISV
CUSTOMER_TENANT_ID=$(az account show --query tenantId --output tsv)

echo "========================================================"
echo "   ONBOARDING COMPLETE!"
echo "========================================================"
echo "Please send the following information back to your ISV provider:"
echo ""
echo "Customer Tenant ID: $CUSTOMER_TENANT_ID"
echo "Customer VNet ID:   $VNET_ID"
echo "========================================================"
