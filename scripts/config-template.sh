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

# Tenant A Configuration
export TENANT_A_ID=""                    # Your Tenant A GUID
export TENANT_A_SUBSCRIPTION_ID=""       # Subscription ID in Tenant A
export TENANT_A_RESOURCE_GROUP=""        # Resource group name
export TENANT_A_VNET_NAME=""             # VNet name
export TENANT_A_PEERING_NAME=""          # Peering connection name (e.g., "peer-a-to-b")

# Tenant B Configuration
export TENANT_B_ID=""                    # Your Tenant B GUID
export TENANT_B_SUBSCRIPTION_ID=""       # Subscription ID in Tenant B
export TENANT_B_RESOURCE_GROUP=""        # Resource group name
export TENANT_B_VNET_NAME=""             # VNet name
export TENANT_B_PEERING_NAME=""          # Peering connection name (e.g., "peer-b-to-a")

# Peering Options
export ALLOW_VNET_ACCESS="true"          # Basic connectivity (required)
export ALLOW_FORWARDED_TRAFFIC="false"   # Enable if using NVA or for gateway transit
export ALLOW_GATEWAY_TRANSIT_A="false"   # Tenant A allows gateway transit
export USE_REMOTE_GATEWAYS_A="false"     # Tenant A uses remote gateway
export ALLOW_GATEWAY_TRANSIT_B="false"   # Tenant B allows gateway transit
export USE_REMOTE_GATEWAYS_B="false"     # Tenant B uses remote gateway

################################################################################
# EXAMPLE VALUES (for reference only - replace with your actual values)
################################################################################

# Example Tenant A:
# export TENANT_A_ID="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
# export TENANT_A_SUBSCRIPTION_ID="11111111-2222-3333-4444-555555555555"
# export TENANT_A_RESOURCE_GROUP="rg-production"
# export TENANT_A_VNET_NAME="vnet-prod-eastus"
# export TENANT_A_PEERING_NAME="peer-prod-to-partner"

# Example Tenant B:
# export TENANT_B_ID="ffffffff-gggg-hhhh-iiii-jjjjjjjjjjjj"
# export TENANT_B_SUBSCRIPTION_ID="66666666-7777-8888-9999-000000000000"
# export TENANT_B_RESOURCE_GROUP="rg-partner"
# export TENANT_B_VNET_NAME="vnet-partner-westus"
# export TENANT_B_PEERING_NAME="peer-partner-to-prod"

################################################################################
# VALIDATION
################################################################################

# Check if all required variables are set
validate_config() {
    local required_vars=(
        "TENANT_A_ID"
        "TENANT_A_SUBSCRIPTION_ID"
        "TENANT_A_RESOURCE_GROUP"
        "TENANT_A_VNET_NAME"
        "TENANT_B_ID"
        "TENANT_B_SUBSCRIPTION_ID"
        "TENANT_B_RESOURCE_GROUP"
        "TENANT_B_VNET_NAME"
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
