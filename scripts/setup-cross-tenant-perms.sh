#!/bin/bash
# Setup Cross-Tenant Permissions for SPNs

# Configuration
ISV_TENANT_ID="<ISV_TENANT_ID>"
ISV_APP_ID="<ISV_APP_ID>"
ISV_VNET_ID="<ISV_VNET_ID>"

CUSTOMER_TENANT_ID="<CUSTOMER_TENANT_ID>"
CUSTOMER_APP_ID="<CUSTOMER_APP_ID>"
CUSTOMER_VNET_ID="<CUSTOMER_VNET_ID>"

echo "This script will set up the necessary cross-tenant permissions."
echo "You will need to log in as a Global Admin (human user) for each tenant."

# --- ISV Tenant Setup ---
echo ""
echo "=== Step 1: Configure ISV Tenant ==="
echo "Please login to ISV Tenant ($ISV_TENANT_ID) as an Admin..."
az login --tenant "$ISV_TENANT_ID" --allow-no-subscriptions

echo "Registering Customer's SPN ($CUSTOMER_APP_ID) in ISV Tenant..."
# Create the service principal for the *other* tenant's app in *this* tenant
az ad sp create --id "$CUSTOMER_APP_ID" || echo "SPN might already exist or App is not Multi-Tenant. Continuing..."

echo "Assigning Network Contributor role to Customer's SPN on ISV Tenant's VNet..."
az role assignment create     --assignee "$CUSTOMER_APP_ID"     --role "Network Contributor"     --scope "$ISV_VNET_ID"

# --- Customer Tenant Setup ---
echo ""
echo "=== Step 2: Configure Customer Tenant ==="
echo "Please login to Customer Tenant ($CUSTOMER_TENANT_ID) as an Admin..."
az login --tenant "$CUSTOMER_TENANT_ID" --allow-no-subscriptions

echo "Registering ISV's SPN ($ISV_APP_ID) in Customer Tenant..."
az ad sp create --id "$ISV_APP_ID" || echo "SPN might already exist or App is not Multi-Tenant. Continuing..."

echo "Assigning Network Contributor role to ISV's SPN on Customer Tenant's VNet..."
az role assignment create     --assignee "$ISV_APP_ID"     --role "Network Contributor"     --scope "$CUSTOMER_VNET_ID"

echo ""
echo "=== Setup Complete ==="
echo "You can now run ./roie-env.sh"
