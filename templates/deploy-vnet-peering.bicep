// ============================================================================
// Cross-Tenant VNet Peering - Bicep Template
// 
// This template creates VNet peering from the local VNet to a remote VNet
// in another Azure tenant.
//
// IMPORTANT: This template must be deployed in BOTH tenants:
// 1. Deploy in Tenant A (peering A -> B)
// 2. Deploy in Tenant B (peering B -> A)
// ============================================================================

@description('Name of the local VNet that will be peered')
param localVnetName string

@description('Full resource ID of the remote VNet in the other tenant. Format: /subscriptions/{sub-id}/resourceGroups/{rg-name}/providers/Microsoft.Network/virtualNetworks/{vnet-name}')
param remoteVnetResourceId string

@description('Name for this peering connection')
param peeringName string

@description('Allow virtual network access between the VNets')
param allowVnetAccess bool = true

@description('Allow forwarded traffic from the remote VNet')
param allowForwardedTraffic bool = false

@description('Allow gateway transit (this VNet has a VPN gateway)')
param allowGatewayTransit bool = false

@description('Use remote VNet gateway (remote VNet has a VPN gateway)')
param useRemoteGateways bool = false

// ============================================================================
// VALIDATION
// ============================================================================

// Validate remote VNet ID format
var remoteVnetIdParts = split(remoteVnetResourceId, '/')
var isValidRemoteVnetId = length(remoteVnetIdParts) == 9 && remoteVnetIdParts[6] == 'Microsoft.Network' && remoteVnetIdParts[7] == 'virtualNetworks'

// Extract remote subscription and VNet name for reference
var remoteSubscriptionId = isValidRemoteVnetId ? remoteVnetIdParts[2] : 'invalid'
var remoteVnetName = isValidRemoteVnetId ? remoteVnetIdParts[8] : 'invalid'

// Validation: Gateway transit settings must be mutually exclusive
var gatewayTransitValid = !(allowGatewayTransit && useRemoteGateways)

// ============================================================================
// RESOURCES
// ============================================================================

// Reference to existing local VNet
resource localVnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: localVnetName
}

// Create VNet Peering
resource vnetPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  name: peeringName
  parent: localVnet
  properties: {
    allowVirtualNetworkAccess: allowVnetAccess
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    useRemoteGateways: useRemoteGateways
    remoteVirtualNetwork: {
      id: remoteVnetResourceId
    }
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Name of the created peering')
output peeringName string = vnetPeering.name

@description('Peering state')
output peeringState string = vnetPeering.properties.peeringState

@description('Peering sync level')
output peeringSyncLevel string = vnetPeering.properties.peeringSyncLevel

@description('Provisioning state')
output provisioningState string = vnetPeering.properties.provisioningState

@description('Local VNet address space')
output localVnetAddressSpace array = localVnet.properties.addressSpace.addressPrefixes

@description('Remote VNet resource ID')
output remoteVnetId string = remoteVnetResourceId

@description('Peering configuration summary')
output peeringConfig object = {
  localVnet: localVnetName
  remoteVnet: remoteVnetName
  remoteSubscription: remoteSubscriptionId
  allowVnetAccess: allowVnetAccess
  allowForwardedTraffic: allowForwardedTraffic
  allowGatewayTransit: allowGatewayTransit
  useRemoteGateways: useRemoteGateways
}

// ============================================================================
// VALIDATION OUTPUTS (will fail deployment if invalid)
// ============================================================================

@description('Validation: Remote VNet ID format is valid')
output validationRemoteVnetId bool = isValidRemoteVnetId

@description('Validation: Gateway transit settings are valid')
output validationGatewayTransit bool = gatewayTransitValid
