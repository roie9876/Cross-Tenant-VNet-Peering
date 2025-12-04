#!/bin/bash

################################################################################
# Configuration Template for Cross-Tenant VNet Peering
#
# INSTRUCTIONS:
# 1. Copy this file: cp config-template.sh config-private.sh
# 2. Fill in your actual values in config-private.sh
# 3. Source it in your script: source config-private.sh
# 4. NEVER commit config-private.sh to git (it's in .gitignore)
################################################################################

# ISV Tenant Configuration
export ISV_TENANT_ID=""                    # Your ISV Tenant GUID
export ISV_SUBSCRIPTION_ID=""       # Subscription ID in ISV Tenant
export ISV_RESOURCE_GROUP=""        # Resource group name
export ISV_VNET_NAME=""             # VNet name
export ISV_PEERING_NAME=""          # Peering connection name (e.g., "peer-a-to-b")

# Customer Tenant Configuration
export CUSTOMER_TENANT_ID=""                    # Your Customer Tenant GUID
export CUSTOMER_SUBSCRIPTION_ID=""       # Subscription ID in Customer Tenant
export CUSTOMER_RESOURCE_GROUP=""        # Resource group name
export CUSTOMER_VNET_NAME=""             # VNet name
export CUSTOMER_PEERING_NAME=""          # Peering connection name (e.g., "peer-b-to-a")

# Peering Options
export ALLOW_VNET_ACCESS="true"          # Basic connectivity (required)
export ALLOW_FORWARDED_TRAFFIC="false"   # Enable if using NVA or for gateway transit
export ALLOW_GATEWAY_TRANSIT_ISV="false"   # ISV Tenant allows gateway transit
export USE_REMOTE_GATEWAYS_ISV="false"     # ISV Tenant uses remote gateway
export ALLOW_GATEWAY_TRANSIT_CUSTOMER="false"   # Customer Tenant allows gateway transit
export USE_REMOTE_GATEWAYS_CUSTOMER="false"     # Customer Tenant uses remote gateway

################################################################################
# EXAMPLE VALUES (for reference only - replace with your actual values)
################################################################################

# Example ISV Tenant:
# export ISV_TENANT_ID="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
# export ISV_SUBSCRIPTION_ID="11111111-2222-3333-4444-555555555555"
# export ISV_RESOURCE_GROUP="rg-production"
# export ISV_VNET_NAME="vnet-prod-eastus"
# export ISV_PEERING_NAME="peer-prod-to-partner"

# Example Customer Tenant:
# export CUSTOMER_TENANT_ID="ffffffff-gggg-hhhh-iiii-jjjjjjjjjjjj"
# export CUSTOMER_SUBSCRIPTION_ID="66666666-7777-8888-9999-000000000000"
# export CUSTOMER_RESOURCE_GROUP="rg-partner"
# export CUSTOMER_VNET_NAME="vnet-partner-westus"
# export CUSTOMER_PEERING_NAME="peer-partner-to-prod"

################################################################################
# VALIDATION
################################################################################

# Check if all required variables are set
validate_config() {
    local required_vars=(
        "ISV_TENANT_ID"
        "ISV_SUBSCRIPTION_ID"
        "ISV_RESOURCE_GROUP"
        "ISV_VNET_NAME"
        "CUSTOMER_TENANT_ID"
        "CUSTOMER_SUBSCRIPTION_ID"
        "CUSTOMER_RESOURCE_GROUP"
        "CUSTOMER_VNET_NAME"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo "ERROR: The following required variables are not set:"
        printf '  - %s\n' "${missing_vars[@]}"
        return 1
    fi
    
    return 0
}

# Uncomment to auto-validate when sourced
# validate_config
