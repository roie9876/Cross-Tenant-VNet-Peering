#!/bin/bash

################################################################################
# Cross-Tenant VNet Peering Automation Script (Generic Template)
# 
# This script automates the creation of VNet peering between two Azure tenants
# (ISV Tenant and Customer Tenant) using custom RBAC roles with least-privilege access.
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

# Function to get access token for auxiliary authorization
get_access_token() {
    local tenant_id=$1
    local client_id=$2
    local client_secret=$3
    
    # Get token using curl
    response=$(curl -s -X POST "https://login.microsoftonline.com/$tenant_id/oauth2/v2.0/token" \
        -d "grant_type=client_credentials" \
        -d "client_id=$client_id" \
        --data-urlencode "client_secret=$client_secret" \
        -d "scope=https://management.azure.com/.default")
        
    # Extract token
    token=$(echo "$response" | jq -r '.access_token')
    
    if [[ "$token" == "null" ]] || [[ -z "$token" ]]; then
        print_error "Failed to get access token for tenant $tenant_id"
        echo "$response" >&2
        return 1
    fi
    
    echo "$token"
}

################################################################################
# CONFIGURATION SECTION
# Update these variables for your environment
################################################################################

# ISV Tenant Configuration (Tenant A)
ISV_TENANT_ID="<ISV_TENANT_ID>"                    # e.g., "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
ISV_SUBSCRIPTION_ID="<ISV_SUBSCRIPTION_ID>"       # Subscription ID in ISV Tenant
ISV_RESOURCE_GROUP="<ISV_RESOURCE_GROUP>"        # Resource group name in ISV Tenant
ISV_VNET_NAME="<ISV_VNET_NAME>"             # VNet name in ISV Tenant
ISV_PEERING_NAME="peer-ISV-to-Customer"          # Name for peering connection

# SPN Credentials for ISV Tenant
ISV_CLIENT_ID="<ISV_CLIENT_ID>"             # App ID for Service Principal in ISV Tenant
ISV_CLIENT_SECRET="<ISV_CLIENT_SECRET>"         # Client Secret for Service Principal in ISV Tenant

# Customer Tenant Configuration (Tenant B)
CUSTOMER_TENANT_ID="<CUSTOMER_TENANT_ID>"                    # e.g., "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
CUSTOMER_SUBSCRIPTION_ID="<CUSTOMER_SUBSCRIPTION_ID>"       # Subscription ID in Customer Tenant
CUSTOMER_RESOURCE_GROUP="<CUSTOMER_RESOURCE_GROUP>"        # Resource group name in Customer Tenant
CUSTOMER_VNET_NAME="<CUSTOMER_VNET_NAME>"             # VNet name in Customer Tenant
CUSTOMER_PEERING_NAME="peer-Customer-to-ISV"          # Name for peering connection

# SPN Credentials for Customer Tenant
# NOTE: We use the SAME Service Principal as ISV Tenant, because the onboarding script
# registered the ISV's App inside the Customer Tenant.
CUSTOMER_CLIENT_ID="$ISV_CLIENT_ID"             # Using ISV App ID
CUSTOMER_CLIENT_SECRET="$ISV_CLIENT_SECRET"     # Using ISV App Secret

# Peering Options (set to true/false)
ALLOW_VNET_ACCESS="true"          # Allow VNet access (required for basic connectivity)
ALLOW_FORWARDED_TRAFFIC="true"   # Allow traffic forwarded by NVA
ALLOW_GATEWAY_TRANSIT_ISV="false"   # Allow gateway transit from ISV Tenant
USE_REMOTE_GATEWAYS_ISV="false"     # Use remote gateways in ISV Tenant
ALLOW_GATEWAY_TRANSIT_CUSTOMER="false"   # Allow gateway transit from Customer Tenant
USE_REMOTE_GATEWAYS_CUSTOMER="false"     # Use remote gateways in Customer Tenant

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

if [[ "$ISV_TENANT_ID" == "<ISV_TENANT_ID>" ]]; then
    print_error "Please update the configuration variables with your actual values."
    exit 1
fi

if [[ -z "$ISV_TENANT_ID" ]]; then
    print_error "ISV_TENANT_ID is not set. Please configure the script."
    exit 1
fi

if [[ -z "$ISV_CLIENT_ID" ]] || [[ -z "$ISV_CLIENT_SECRET" ]]; then
    print_error "ISV SPN credentials are not set. Please configure ISV_CLIENT_ID and ISV_CLIENT_SECRET."
    exit 1
fi

if [[ -z "$CUSTOMER_TENANT_ID" ]]; then
    print_error "CUSTOMER_TENANT_ID is not set. Please configure the script."
    exit 1
fi

if [[ -z "$CUSTOMER_CLIENT_ID" ]] || [[ -z "$CUSTOMER_CLIENT_SECRET" ]]; then
    print_error "Customer SPN credentials are not set. Please configure CUSTOMER_CLIENT_ID and CUSTOMER_CLIENT_SECRET."
    exit 1
fi

if [[ -z "$ISV_SUBSCRIPTION_ID" ]] || [[ -z "$ISV_RESOURCE_GROUP" ]] || [[ -z "$ISV_VNET_NAME" ]]; then
    print_error "ISV Tenant configuration is incomplete. Please set all required variables."
    exit 1
fi

if [[ -z "$CUSTOMER_SUBSCRIPTION_ID" ]] || [[ -z "$CUSTOMER_RESOURCE_GROUP" ]] || [[ -z "$CUSTOMER_VNET_NAME" ]]; then
    print_error "Customer Tenant configuration is incomplete. Please set all required variables."
    exit 1
fi

if [[ -z "$ISV_PEERING_NAME" ]]; then
    ISV_PEERING_NAME="peer-${ISV_VNET_NAME}-to-${CUSTOMER_VNET_NAME}"
    print_warning "ISV_PEERING_NAME not set, using default: $ISV_PEERING_NAME"
fi

if [[ -z "$CUSTOMER_PEERING_NAME" ]]; then
    CUSTOMER_PEERING_NAME="peer-${CUSTOMER_VNET_NAME}-to-${ISV_VNET_NAME}"
    print_warning "CUSTOMER_PEERING_NAME not set, using default: $CUSTOMER_PEERING_NAME"
fi

print_success "Configuration validated"
echo ""

################################################################################
# ISV TENANT - GATHER VNET INFORMATION
################################################################################

print_info "=========================================="
print_info "STEP 1: Gathering VNet information from ISV Tenant"
print_info "=========================================="
echo ""

print_info "Logging into ISV Tenant..."
az login --service-principal -u "$ISV_CLIENT_ID" -p "$ISV_CLIENT_SECRET" --tenant "$ISV_TENANT_ID"
print_success "Logged into ISV Tenant"

print_info "Setting subscription context to ISV Tenant..."
az account set --subscription "$ISV_SUBSCRIPTION_ID"
print_success "Subscription set to: $ISV_SUBSCRIPTION_ID"

print_info "Retrieving VNet information from ISV Tenant..."
ISV_VNET_INFO=$(az network vnet show \
    --resource-group "$ISV_RESOURCE_GROUP" \
    --name "$ISV_VNET_NAME" \
    --query '{id:id, addressSpace:addressSpace.addressPrefixes[0]}' \
    --output json)

if [[ $? -ne 0 ]]; then
    print_error "Failed to retrieve VNet information from ISV Tenant"
    exit 1
fi

ISV_VNET_ID=$(echo "$ISV_VNET_INFO" | jq -r '.id')
ISV_ADDRESS_SPACE=$(echo "$ISV_VNET_INFO" | jq -r '.addressSpace')

print_success "ISV VNet ID: $ISV_VNET_ID"
print_success "ISV Address Space: $ISV_ADDRESS_SPACE"
echo ""

################################################################################
# CUSTOMER TENANT - GATHER VNET INFORMATION
################################################################################

print_info "=========================================="
print_info "STEP 2: Gathering VNet information from Customer Tenant"
print_info "=========================================="
echo ""

print_info "Logging into Customer Tenant..."
az login --service-principal -u "$CUSTOMER_CLIENT_ID" -p "$CUSTOMER_CLIENT_SECRET" --tenant "$CUSTOMER_TENANT_ID" --allow-no-subscriptions
print_success "Logged into Customer Tenant"

print_info "Setting subscription context to Customer Tenant..."
az account set --subscription "$CUSTOMER_SUBSCRIPTION_ID" || print_warning "Could not set subscription context. Proceeding with REST API..."
print_success "Subscription set to: $CUSTOMER_SUBSCRIPTION_ID"

print_info "Retrieving VNet information from Customer Tenant..."
CUSTOMER_VNET_INFO=$(az network vnet show \
    --resource-group "$CUSTOMER_RESOURCE_GROUP" \
    --name "$CUSTOMER_VNET_NAME" \
    --query '{id:id, addressSpace:addressSpace.addressPrefixes[0]}' \
    --output json)

if [[ $? -ne 0 ]]; then
    print_error "Failed to retrieve VNet information from Customer Tenant"
    exit 1
fi

CUSTOMER_VNET_ID=$(echo "$CUSTOMER_VNET_INFO" | jq -r '.id')
CUSTOMER_ADDRESS_SPACE=$(echo "$CUSTOMER_VNET_INFO" | jq -r '.addressSpace')

print_success "Customer VNet ID: $CUSTOMER_VNET_ID"
print_success "Customer Address Space: $CUSTOMER_ADDRESS_SPACE"
echo ""

################################################################################
# VALIDATE ADDRESS SPACES
################################################################################

print_info "=========================================="
print_info "STEP 3: Validating Address Spaces"
print_info "=========================================="
echo ""

validate_address_space "$ISV_ADDRESS_SPACE"
validate_address_space "$CUSTOMER_ADDRESS_SPACE"

# Extract network prefixes for overlap check
ISV_PREFIX=$(echo "$ISV_ADDRESS_SPACE" | cut -d'/' -f1 | cut -d'.' -f1-2)
CUSTOMER_PREFIX=$(echo "$CUSTOMER_ADDRESS_SPACE" | cut -d'/' -f1 | cut -d'.' -f1-2)

if [[ "$ISV_PREFIX" == "$CUSTOMER_PREFIX" ]]; then
    print_warning "Potential address space overlap detected!"
    print_warning "ISV Tenant: $ISV_ADDRESS_SPACE"
    print_warning "Customer Tenant: $CUSTOMER_ADDRESS_SPACE"
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
echo "ISV Tenant:"
echo "  Tenant ID:        $ISV_TENANT_ID"
echo "  Subscription:     $ISV_SUBSCRIPTION_ID"
echo "  Resource Group:   $ISV_RESOURCE_GROUP"
echo "  VNet:             $ISV_VNET_NAME"
echo "  Address Space:    $ISV_ADDRESS_SPACE"
echo "  Peering Name:     $ISV_PEERING_NAME"
echo ""
echo "Customer Tenant:"
echo "  Tenant ID:        $CUSTOMER_TENANT_ID"
echo "  Subscription:     $CUSTOMER_SUBSCRIPTION_ID"
echo "  Resource Group:   $CUSTOMER_RESOURCE_GROUP"
echo "  VNet:             $CUSTOMER_VNET_NAME"
echo "  Address Space:    $CUSTOMER_ADDRESS_SPACE"
echo "  Peering Name:     $CUSTOMER_PEERING_NAME"
echo ""
echo "Peering Options:"
echo "  Allow VNet Access:          $ALLOW_VNET_ACCESS"
echo "  Allow Forwarded Traffic:    $ALLOW_FORWARDED_TRAFFIC"
echo "  Gateway Transit (ISV):      $ALLOW_GATEWAY_TRANSIT_ISV"
echo "  Use Remote Gateways (ISV):  $USE_REMOTE_GATEWAYS_ISV"
echo "  Gateway Transit (Customer): $ALLOW_GATEWAY_TRANSIT_CUSTOMER"
echo "  Use Remote Gateways (Cust): $USE_REMOTE_GATEWAYS_CUSTOMER"
echo ""

print_warning "Ready to create cross-tenant VNet peering. Continue? (y/n)"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    print_info "Exiting..."
    exit 0
fi
echo ""

################################################################################
# CREATE PEERING FROM ISV TENANT TO CUSTOMER TENANT
################################################################################

print_info "=========================================="
print_info "STEP 4: Creating peering from ISV Tenant to Customer Tenant"
print_info "=========================================="
echo ""

print_info "Logging into ISV Tenant..."
az login --service-principal -u "$ISV_CLIENT_ID" -p "$ISV_CLIENT_SECRET" --tenant "$ISV_TENANT_ID" > /dev/null 2>&1
az account set --subscription "$ISV_SUBSCRIPTION_ID"
print_success "Logged into ISV Tenant"

print_info "Creating peering: $ISV_PEERING_NAME"

# Build the command with options
# Using az rest to bypass cross-tenant authentication checks that fail with isolated SPNs
print_info "Using REST API to create peering (bypassing remote tenant check)..."

# Convert variables to JSON booleans
JSON_ALLOW_VNET_ACCESS=$(if [[ "$ALLOW_VNET_ACCESS" == "true" ]]; then echo "true"; else echo "false"; fi)
JSON_ALLOW_FORWARDED_TRAFFIC=$(if [[ "$ALLOW_FORWARDED_TRAFFIC" == "true" ]]; then echo "true"; else echo "false"; fi)
JSON_ALLOW_GATEWAY_TRANSIT_ISV=$(if [[ "$ALLOW_GATEWAY_TRANSIT_ISV" == "true" ]]; then echo "true"; else echo "false"; fi)
JSON_USE_REMOTE_GATEWAYS_ISV=$(if [[ "$USE_REMOTE_GATEWAYS_ISV" == "true" ]]; then echo "true"; else echo "false"; fi)

print_info "Generating auxiliary token for Customer Tenant (to prove access to remote VNet)..."
AUX_TOKEN_CUSTOMER=$(get_access_token "$CUSTOMER_TENANT_ID" "$ISV_CLIENT_ID" "$ISV_CLIENT_SECRET")
if [[ $? -ne 0 ]]; then exit 1; fi

PEERING_CMD_ISV="az rest --method put \
    --uri /subscriptions/$ISV_SUBSCRIPTION_ID/resourceGroups/$ISV_RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$ISV_VNET_NAME/virtualNetworkPeerings/$ISV_PEERING_NAME?api-version=2022-07-01 \
    --headers \"x-ms-authorization-auxiliary=Bearer $AUX_TOKEN_CUSTOMER\" \
    --body '{
        \"properties\": {
            \"remoteVirtualNetwork\": {
                \"id\": \"$CUSTOMER_VNET_ID\"
            },
            \"allowVirtualNetworkAccess\": $JSON_ALLOW_VNET_ACCESS,
            \"allowForwardedTraffic\": $JSON_ALLOW_FORWARDED_TRAFFIC,
            \"allowGatewayTransit\": $JSON_ALLOW_GATEWAY_TRANSIT_ISV,
            \"useRemoteGateways\": $JSON_USE_REMOTE_GATEWAYS_ISV
        }
    }'"

# Execute the command
if eval "$PEERING_CMD_ISV"; then
    print_success "Peering created successfully from ISV Tenant"
    
    # Get peering status
    PEERING_STATUS_ISV=$(az network vnet peering show \
        --name "$ISV_PEERING_NAME" \
        --resource-group "$ISV_RESOURCE_GROUP" \
        --vnet-name "$ISV_VNET_NAME" \
        --query '{peeringState:peeringState, syncLevel:peeringSyncLevel, provisioningState:provisioningState}' \
        --output json)
    
    echo "Status: $PEERING_STATUS_ISV"
else
    print_error "Failed to create peering from ISV Tenant"
    print_error "This may be expected if the remote tenant hasn't created their side yet"
fi
echo ""

################################################################################
# CREATE PEERING FROM CUSTOMER TENANT TO ISV TENANT
################################################################################

print_info "=========================================="
print_info "STEP 5: Creating peering from Customer Tenant to ISV Tenant"
print_info "=========================================="
echo ""

print_info "Logging into Customer Tenant..."
az login --service-principal -u "$CUSTOMER_CLIENT_ID" -p "$CUSTOMER_CLIENT_SECRET" --tenant "$CUSTOMER_TENANT_ID" --allow-no-subscriptions
print_success "Logged into Customer Tenant"

print_info "Setting subscription context to Customer Tenant..."
az account set --subscription "$CUSTOMER_SUBSCRIPTION_ID" || print_warning "Could not set subscription context. Proceeding with REST API..."
print_success "Subscription set to: $CUSTOMER_SUBSCRIPTION_ID"

print_info "Creating peering: $CUSTOMER_PEERING_NAME"

# Build the command with options
# Using az rest to bypass cross-tenant authentication checks that fail with isolated SPNs
print_info "Using REST API to create peering (bypassing remote tenant check)..."

# Convert variables to JSON booleans
JSON_ALLOW_VNET_ACCESS=$(if [[ "$ALLOW_VNET_ACCESS" == "true" ]]; then echo "true"; else echo "false"; fi)
JSON_ALLOW_FORWARDED_TRAFFIC=$(if [[ "$ALLOW_FORWARDED_TRAFFIC" == "true" ]]; then echo "true"; else echo "false"; fi)
JSON_ALLOW_GATEWAY_TRANSIT_CUSTOMER=$(if [[ "$ALLOW_GATEWAY_TRANSIT_CUSTOMER" == "true" ]]; then echo "true"; else echo "false"; fi)
JSON_USE_REMOTE_GATEWAYS_CUSTOMER=$(if [[ "$USE_REMOTE_GATEWAYS_CUSTOMER" == "true" ]]; then echo "true"; else echo "false"; fi)

print_info "Generating auxiliary token for ISV Tenant (to prove access to remote VNet)..."
AUX_TOKEN_ISV=$(get_access_token "$ISV_TENANT_ID" "$CUSTOMER_CLIENT_ID" "$CUSTOMER_CLIENT_SECRET")
if [[ $? -ne 0 ]]; then exit 1; fi

PEERING_CMD_CUSTOMER="az rest --method put \
    --uri /subscriptions/$CUSTOMER_SUBSCRIPTION_ID/resourceGroups/$CUSTOMER_RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$CUSTOMER_VNET_NAME/virtualNetworkPeerings/$CUSTOMER_PEERING_NAME?api-version=2022-07-01 \
    --headers \"x-ms-authorization-auxiliary=Bearer $AUX_TOKEN_ISV\" \
    --body '{
        \"properties\": {
            \"remoteVirtualNetwork\": {
                \"id\": \"$ISV_VNET_ID\"
            },
            \"allowVirtualNetworkAccess\": $JSON_ALLOW_VNET_ACCESS,
            \"allowForwardedTraffic\": $JSON_ALLOW_FORWARDED_TRAFFIC,
            \"allowGatewayTransit\": $JSON_ALLOW_GATEWAY_TRANSIT_CUSTOMER,
            \"useRemoteGateways\": $JSON_USE_REMOTE_GATEWAYS_CUSTOMER
        }
    }'"

# Execute the command
if eval "$PEERING_CMD_CUSTOMER"; then
    print_success "Peering created successfully from Customer Tenant"
    
    # Get peering status
    PEERING_STATUS_CUSTOMER=$(az network vnet peering show \
        --name "$CUSTOMER_PEERING_NAME" \
        --resource-group "$CUSTOMER_RESOURCE_GROUP" \
        --vnet-name "$CUSTOMER_VNET_NAME" \
        --query '{peeringState:peeringState, syncLevel:peeringSyncLevel, provisioningState:provisioningState}' \
        --output json)
    
    echo "Status: $PEERING_STATUS_CUSTOMER"
else
    print_error "Failed to create peering from Customer Tenant"
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

# Check ISV Tenant
print_info "Checking peering status in ISV Tenant..."
az login --service-principal -u "$ISV_CLIENT_ID" -p "$ISV_CLIENT_SECRET" --tenant "$ISV_TENANT_ID" > /dev/null 2>&1
az account set --subscription "$ISV_SUBSCRIPTION_ID"

FINAL_STATUS_ISV=$(az network vnet peering list \
    --resource-group "$ISV_RESOURCE_GROUP" \
    --vnet-name "$ISV_VNET_NAME" \
    --query "[?name=='$ISV_PEERING_NAME'].{Name:name, PeeringState:peeringState, SyncLevel:peeringSyncLevel, ProvisioningState:provisioningState}" \
    --output table)

echo ""
echo "ISV Tenant Peering Status:"
echo "$FINAL_STATUS_ISV"
echo ""

# Check Customer Tenant
print_info "Checking peering status in Customer Tenant..."
az login --service-principal -u "$CUSTOMER_CLIENT_ID" -p "$CUSTOMER_CLIENT_SECRET" --tenant "$CUSTOMER_TENANT_ID" > /dev/null 2>&1
az account set --subscription "$CUSTOMER_SUBSCRIPTION_ID"

FINAL_STATUS_CUSTOMER=$(az network vnet peering list \
    --resource-group "$CUSTOMER_RESOURCE_GROUP" \
    --vnet-name "$CUSTOMER_VNET_NAME" \
    --query "[?name=='$CUSTOMER_PEERING_NAME'].{Name:name, PeeringState:peeringState, SyncLevel:peeringSyncLevel, ProvisioningState:provisioningState}" \
    --output table)

echo ""
echo "Customer Tenant Peering Status:"
echo "$FINAL_STATUS_CUSTOMER"
echo ""

################################################################################
# COMPLETION
################################################################################

print_success "=========================================="
print_success "Cross-Tenant VNet Peering Setup Complete!"
print_success "=========================================="
echo ""
print_info "Peering Status Summary:"
print_info "  ISV Tenant: $ISV_PEERING_NAME"
print_info "  Customer Tenant: $CUSTOMER_PEERING_NAME"
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
