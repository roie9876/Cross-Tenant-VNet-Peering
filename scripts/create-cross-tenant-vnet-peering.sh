#!/bin/bash

################################################################################
# Cross-Tenant VNet Peering Automation Script
# 
# This script automates the creation of VNet peering between two Azure tenants
# using custom RBAC roles with least-privilege access.
#
# Prerequisites: See PREREQUISITES.md before running this script
################################################################################

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to validate IP address range
validate_address_space() {
    local addr_space=$1
    if [[ ! $addr_space =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        print_error "Invalid address space format: $addr_space"
        print_error "Expected format: X.X.X.X/Y (e.g., 10.0.0.0/16)"
        return 1
    fi
    return 0
}

################################################################################
# CONFIGURATION SECTION
# Update these variables for your environment
################################################################################

# Tenant A Configuration
TENANT_A_ID=""                    # e.g., "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
TENANT_A_SUBSCRIPTION_ID=""       # Subscription ID in Tenant A
TENANT_A_RESOURCE_GROUP=""        # Resource group name in Tenant A
TENANT_A_VNET_NAME=""             # VNet name in Tenant A
TENANT_A_PEERING_NAME=""          # Name for peering connection (e.g., "peer-tenantA-to-tenantB")

# Tenant B Configuration
TENANT_B_ID=""                    # e.g., "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
TENANT_B_SUBSCRIPTION_ID=""       # Subscription ID in Tenant B
TENANT_B_RESOURCE_GROUP=""        # Resource group name in Tenant B
TENANT_B_VNET_NAME=""             # VNet name in Tenant B
TENANT_B_PEERING_NAME=""          # Name for peering connection (e.g., "peer-tenantB-to-tenantA")

# Peering Options (set to true/false)
ALLOW_VNET_ACCESS="true"          # Allow VNet access (required for basic connectivity)
ALLOW_FORWARDED_TRAFFIC="false"   # Allow traffic forwarded by NVA
ALLOW_GATEWAY_TRANSIT_A="false"   # Allow gateway transit from Tenant A
USE_REMOTE_GATEWAYS_A="false"     # Use remote gateways in Tenant A
ALLOW_GATEWAY_TRANSIT_B="false"   # Allow gateway transit from Tenant B
USE_REMOTE_GATEWAYS_B="false"     # Use remote gateways in Tenant B

################################################################################
# PRE-FLIGHT CHECKS
################################################################################

print_info "Starting Cross-Tenant VNet Peering Script..."
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it first."
    print_info "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi
print_success "Azure CLI is installed"

# Check if jq is installed (for JSON parsing)
if ! command -v jq &> /dev/null; then
    print_warning "jq is not installed. JSON output will be less readable."
    print_info "Install with: brew install jq (macOS) or apt-get install jq (Linux)"
fi

# Validate required configuration variables
print_info "Validating configuration..."

if [[ -z "$TENANT_A_ID" ]]; then
    print_error "TENANT_A_ID is not set. Please configure the script."
    exit 1
fi

if [[ -z "$TENANT_B_ID" ]]; then
    print_error "TENANT_B_ID is not set. Please configure the script."
    exit 1
fi

if [[ -z "$TENANT_A_SUBSCRIPTION_ID" ]] || [[ -z "$TENANT_A_RESOURCE_GROUP" ]] || [[ -z "$TENANT_A_VNET_NAME" ]]; then
    print_error "Tenant A configuration is incomplete. Please set all required variables."
    exit 1
fi

if [[ -z "$TENANT_B_SUBSCRIPTION_ID" ]] || [[ -z "$TENANT_B_RESOURCE_GROUP" ]] || [[ -z "$TENANT_B_VNET_NAME" ]]; then
    print_error "Tenant B configuration is incomplete. Please set all required variables."
    exit 1
fi

if [[ -z "$TENANT_A_PEERING_NAME" ]]; then
    TENANT_A_PEERING_NAME="peer-${TENANT_A_VNET_NAME}-to-${TENANT_B_VNET_NAME}"
    print_warning "TENANT_A_PEERING_NAME not set, using default: $TENANT_A_PEERING_NAME"
fi

if [[ -z "$TENANT_B_PEERING_NAME" ]]; then
    TENANT_B_PEERING_NAME="peer-${TENANT_B_VNET_NAME}-to-${TENANT_A_VNET_NAME}"
    print_warning "TENANT_B_PEERING_NAME not set, using default: $TENANT_B_PEERING_NAME"
fi

print_success "Configuration validated"
echo ""

################################################################################
# TENANT A - GATHER VNET INFORMATION
################################################################################

print_info "=========================================="
print_info "STEP 1: Gathering VNet information from Tenant A"
print_info "=========================================="
echo ""

print_info "Logging into Tenant A..."
az login --tenant "$TENANT_A_ID" --use-device-code
print_success "Logged into Tenant A"

print_info "Setting subscription context to Tenant A..."
az account set --subscription "$TENANT_A_SUBSCRIPTION_ID"
print_success "Subscription set to: $TENANT_A_SUBSCRIPTION_ID"

print_info "Retrieving VNet information from Tenant A..."
TENANT_A_VNET_INFO=$(az network vnet show \
    --resource-group "$TENANT_A_RESOURCE_GROUP" \
    --name "$TENANT_A_VNET_NAME" \
    --query '{id:id, addressSpace:addressSpace.addressPrefixes[0]}' \
    --output json)

if [[ $? -ne 0 ]]; then
    print_error "Failed to retrieve VNet information from Tenant A"
    exit 1
fi

TENANT_A_VNET_ID=$(echo "$TENANT_A_VNET_INFO" | jq -r '.id')
TENANT_A_ADDRESS_SPACE=$(echo "$TENANT_A_VNET_INFO" | jq -r '.addressSpace')

print_success "Tenant A VNet ID: $TENANT_A_VNET_ID"
print_success "Tenant A Address Space: $TENANT_A_ADDRESS_SPACE"
echo ""

################################################################################
# TENANT B - GATHER VNET INFORMATION
################################################################################

print_info "=========================================="
print_info "STEP 2: Gathering VNet information from Tenant B"
print_info "=========================================="
echo ""

print_info "Logging into Tenant B..."
az login --tenant "$TENANT_B_ID" --use-device-code
print_success "Logged into Tenant B"

print_info "Setting subscription context to Tenant B..."
az account set --subscription "$TENANT_B_SUBSCRIPTION_ID"
print_success "Subscription set to: $TENANT_B_SUBSCRIPTION_ID"

print_info "Retrieving VNet information from Tenant B..."
TENANT_B_VNET_INFO=$(az network vnet show \
    --resource-group "$TENANT_B_RESOURCE_GROUP" \
    --name "$TENANT_B_VNET_NAME" \
    --query '{id:id, addressSpace:addressSpace.addressPrefixes[0]}' \
    --output json)

if [[ $? -ne 0 ]]; then
    print_error "Failed to retrieve VNet information from Tenant B"
    exit 1
fi

TENANT_B_VNET_ID=$(echo "$TENANT_B_VNET_INFO" | jq -r '.id')
TENANT_B_ADDRESS_SPACE=$(echo "$TENANT_B_VNET_INFO" | jq -r '.addressSpace')

print_success "Tenant B VNet ID: $TENANT_B_VNET_ID"
print_success "Tenant B Address Space: $TENANT_B_ADDRESS_SPACE"
echo ""

################################################################################
# VALIDATE ADDRESS SPACES
################################################################################

print_info "=========================================="
print_info "STEP 3: Validating Address Spaces"
print_info "=========================================="
echo ""

validate_address_space "$TENANT_A_ADDRESS_SPACE"
validate_address_space "$TENANT_B_ADDRESS_SPACE"

# Extract network prefixes for overlap check
TENANT_A_PREFIX=$(echo "$TENANT_A_ADDRESS_SPACE" | cut -d'/' -f1 | cut -d'.' -f1-2)
TENANT_B_PREFIX=$(echo "$TENANT_B_ADDRESS_SPACE" | cut -d'/' -f1 | cut -d'.' -f1-2)

if [[ "$TENANT_A_PREFIX" == "$TENANT_B_PREFIX" ]]; then
    print_warning "Potential address space overlap detected!"
    print_warning "Tenant A: $TENANT_A_ADDRESS_SPACE"
    print_warning "Tenant B: $TENANT_B_ADDRESS_SPACE"
    print_warning "This may cause routing issues. Continue? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_info "Exiting..."
        exit 0
    fi
else
    print_success "No address space overlap detected"
fi
echo ""

################################################################################
# DISPLAY SUMMARY AND CONFIRM
################################################################################

print_info "=========================================="
print_info "PEERING CONFIGURATION SUMMARY"
print_info "=========================================="
echo ""
echo "Tenant A:"
echo "  Tenant ID:        $TENANT_A_ID"
echo "  Subscription:     $TENANT_A_SUBSCRIPTION_ID"
echo "  Resource Group:   $TENANT_A_RESOURCE_GROUP"
echo "  VNet:             $TENANT_A_VNET_NAME"
echo "  Address Space:    $TENANT_A_ADDRESS_SPACE"
echo "  Peering Name:     $TENANT_A_PEERING_NAME"
echo ""
echo "Tenant B:"
echo "  Tenant ID:        $TENANT_B_ID"
echo "  Subscription:     $TENANT_B_SUBSCRIPTION_ID"
echo "  Resource Group:   $TENANT_B_RESOURCE_GROUP"
echo "  VNet:             $TENANT_B_VNET_NAME"
echo "  Address Space:    $TENANT_B_ADDRESS_SPACE"
echo "  Peering Name:     $TENANT_B_PEERING_NAME"
echo ""
echo "Peering Options:"
echo "  Allow VNet Access:          $ALLOW_VNET_ACCESS"
echo "  Allow Forwarded Traffic:    $ALLOW_FORWARDED_TRAFFIC"
echo "  Gateway Transit (Tenant A): $ALLOW_GATEWAY_TRANSIT_A"
echo "  Use Remote Gateways (A):    $USE_REMOTE_GATEWAYS_A"
echo "  Gateway Transit (Tenant B): $ALLOW_GATEWAY_TRANSIT_B"
echo "  Use Remote Gateways (B):    $USE_REMOTE_GATEWAYS_B"
echo ""

print_warning "Ready to create cross-tenant VNet peering. Continue? (y/n)"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    print_info "Exiting..."
    exit 0
fi
echo ""

################################################################################
# CREATE PEERING FROM TENANT A TO TENANT B
################################################################################

print_info "=========================================="
print_info "STEP 4: Creating peering from Tenant A to Tenant B"
print_info "=========================================="
echo ""

print_info "Logging into Tenant A..."
az login --tenant "$TENANT_A_ID" --use-device-code > /dev/null 2>&1
az account set --subscription "$TENANT_A_SUBSCRIPTION_ID"
print_success "Logged into Tenant A"

print_info "Creating peering: $TENANT_A_PEERING_NAME"

# Build the command with options
PEERING_CMD_A="az network vnet peering create \
    --name \"$TENANT_A_PEERING_NAME\" \
    --resource-group \"$TENANT_A_RESOURCE_GROUP\" \
    --vnet-name \"$TENANT_A_VNET_NAME\" \
    --remote-vnet \"$TENANT_B_VNET_ID\""

if [[ "$ALLOW_VNET_ACCESS" == "true" ]]; then
    PEERING_CMD_A="$PEERING_CMD_A --allow-vnet-access"
fi

if [[ "$ALLOW_FORWARDED_TRAFFIC" == "true" ]]; then
    PEERING_CMD_A="$PEERING_CMD_A --allow-forwarded-traffic"
fi

if [[ "$ALLOW_GATEWAY_TRANSIT_A" == "true" ]]; then
    PEERING_CMD_A="$PEERING_CMD_A --allow-gateway-transit"
fi

if [[ "$USE_REMOTE_GATEWAYS_A" == "true" ]]; then
    PEERING_CMD_A="$PEERING_CMD_A --use-remote-gateways"
fi

# Execute the command
eval "$PEERING_CMD_A" > /dev/null 2>&1

if [[ $? -eq 0 ]]; then
    print_success "Peering created successfully from Tenant A"
    
    # Get peering status
    PEERING_STATUS_A=$(az network vnet peering show \
        --name "$TENANT_A_PEERING_NAME" \
        --resource-group "$TENANT_A_RESOURCE_GROUP" \
        --vnet-name "$TENANT_A_VNET_NAME" \
        --query '{peeringState:peeringState, syncLevel:peeringSyncLevel, provisioningState:provisioningState}' \
        --output json)
    
    echo "Status: $PEERING_STATUS_A"
else
    print_error "Failed to create peering from Tenant A"
    print_error "This may be expected if the remote tenant hasn't created their side yet"
fi
echo ""

################################################################################
# CREATE PEERING FROM TENANT B TO TENANT A
################################################################################

print_info "=========================================="
print_info "STEP 5: Creating peering from Tenant B to Tenant A"
print_info "=========================================="
echo ""

print_info "Logging into Tenant B..."
az login --tenant "$TENANT_B_ID" --use-device-code > /dev/null 2>&1
az account set --subscription "$TENANT_B_SUBSCRIPTION_ID"
print_success "Logged into Tenant B"

print_info "Creating peering: $TENANT_B_PEERING_NAME"

# Build the command with options
PEERING_CMD_B="az network vnet peering create \
    --name \"$TENANT_B_PEERING_NAME\" \
    --resource-group \"$TENANT_B_RESOURCE_GROUP\" \
    --vnet-name \"$TENANT_B_VNET_NAME\" \
    --remote-vnet \"$TENANT_A_VNET_ID\""

if [[ "$ALLOW_VNET_ACCESS" == "true" ]]; then
    PEERING_CMD_B="$PEERING_CMD_B --allow-vnet-access"
fi

if [[ "$ALLOW_FORWARDED_TRAFFIC" == "true" ]]; then
    PEERING_CMD_B="$PEERING_CMD_B --allow-forwarded-traffic"
fi

if [[ "$ALLOW_GATEWAY_TRANSIT_B" == "true" ]]; then
    PEERING_CMD_B="$PEERING_CMD_B --allow-gateway-transit"
fi

if [[ "$USE_REMOTE_GATEWAYS_B" == "true" ]]; then
    PEERING_CMD_B="$PEERING_CMD_B --use-remote-gateways"
fi

# Execute the command
eval "$PEERING_CMD_B" > /dev/null 2>&1

if [[ $? -eq 0 ]]; then
    print_success "Peering created successfully from Tenant B"
    
    # Get peering status
    PEERING_STATUS_B=$(az network vnet peering show \
        --name "$TENANT_B_PEERING_NAME" \
        --resource-group "$TENANT_B_RESOURCE_GROUP" \
        --vnet-name "$TENANT_B_VNET_NAME" \
        --query '{peeringState:peeringState, syncLevel:peeringSyncLevel, provisioningState:provisioningState}' \
        --output json)
    
    echo "Status: $PEERING_STATUS_B"
else
    print_error "Failed to create peering from Tenant B"
fi
echo ""

################################################################################
# VERIFY PEERING STATUS
################################################################################

print_info "=========================================="
print_info "STEP 6: Verifying Peering Status"
print_info "=========================================="
echo ""

# Wait a few seconds for peering to sync
print_info "Waiting 5 seconds for peering synchronization..."
sleep 5

# Check Tenant A
print_info "Checking peering status in Tenant A..."
az login --tenant "$TENANT_A_ID" --use-device-code > /dev/null 2>&1
az account set --subscription "$TENANT_A_SUBSCRIPTION_ID"

FINAL_STATUS_A=$(az network vnet peering list \
    --resource-group "$TENANT_A_RESOURCE_GROUP" \
    --vnet-name "$TENANT_A_VNET_NAME" \
    --query "[?name=='$TENANT_A_PEERING_NAME'].{Name:name, PeeringState:peeringState, SyncLevel:peeringSyncLevel, ProvisioningState:provisioningState}" \
    --output table)

echo ""
echo "Tenant A Peering Status:"
echo "$FINAL_STATUS_A"
echo ""

# Check Tenant B
print_info "Checking peering status in Tenant B..."
az login --tenant "$TENANT_B_ID" --use-device-code > /dev/null 2>&1
az account set --subscription "$TENANT_B_SUBSCRIPTION_ID"

FINAL_STATUS_B=$(az network vnet peering list \
    --resource-group "$TENANT_B_RESOURCE_GROUP" \
    --vnet-name "$TENANT_B_VNET_NAME" \
    --query "[?name=='$TENANT_B_PEERING_NAME'].{Name:name, PeeringState:peeringState, SyncLevel:peeringSyncLevel, ProvisioningState:provisioningState}" \
    --output table)

echo ""
echo "Tenant B Peering Status:"
echo "$FINAL_STATUS_B"
echo ""

################################################################################
# COMPLETION
################################################################################

print_success "=========================================="
print_success "Cross-Tenant VNet Peering Setup Complete!"
print_success "=========================================="
echo ""
print_info "Peering Status Summary:"
print_info "  Tenant A: $TENANT_A_PEERING_NAME"
print_info "  Tenant B: $TENANT_B_PEERING_NAME"
echo ""
print_info "Expected State: PeeringState=Connected, SyncLevel=FullyInSync"
echo ""
print_info "Next Steps:"
print_info "  1. Test connectivity between VNets using VMs or other resources"
print_info "  2. Configure Network Security Groups (NSGs) as needed"
print_info "  3. Set up User Defined Routes (UDRs) if required"
print_info "  4. Monitor peering status using Azure Portal or CLI"
echo ""
print_info "For troubleshooting, see: Cross-Tenant-VNet-Peering-Guide.md"
