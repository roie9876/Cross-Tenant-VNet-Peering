# Cross-Tenant VNet Peering Examples

This directory contains example configurations and scenarios for cross-tenant VNet peering.

## Example Scenarios

### Scenario 1: Basic Cross-Tenant Peering

**Use Case:** Connect two VNets in different Azure tenants for basic communication.

**Configuration:**
```bash
# Tenant A
TENANT_A_ID="tenant-a-guid"
TENANT_A_SUBSCRIPTION_ID="subscription-a-guid"
TENANT_A_RESOURCE_GROUP="rg-production-a"
TENANT_A_VNET_NAME="vnet-prod-a"
TENANT_A_PEERING_NAME="peer-prod-a-to-partner-b"

# Tenant B
TENANT_B_ID="tenant-b-guid"
TENANT_B_SUBSCRIPTION_ID="subscription-b-guid"
TENANT_B_RESOURCE_GROUP="rg-partner-b"
TENANT_B_VNET_NAME="vnet-partner-b"
TENANT_B_PEERING_NAME="peer-partner-b-to-prod-a"

# Options
ALLOW_VNET_ACCESS="true"
ALLOW_FORWARDED_TRAFFIC="false"
ALLOW_GATEWAY_TRANSIT_A="false"
USE_REMOTE_GATEWAYS_A="false"
ALLOW_GATEWAY_TRANSIT_B="false"
USE_REMOTE_GATEWAYS_B="false"
```

**Address Spaces:**
- Tenant A: `192.168.0.0/16`
- Tenant B: `10.0.0.0/16`

---

### Scenario 2: Hub-and-Spoke with VPN Gateway

**Use Case:** Tenant A has a VPN gateway, Tenant B uses it for on-premises connectivity.

**Configuration:**
```bash
# Tenant A (Hub with VPN Gateway)
TENANT_A_ID="tenant-a-guid"
TENANT_A_SUBSCRIPTION_ID="subscription-a-guid"
TENANT_A_RESOURCE_GROUP="rg-hub"
TENANT_A_VNET_NAME="vnet-hub"
TENANT_A_PEERING_NAME="peer-hub-to-spoke"

# Tenant B (Spoke)
TENANT_B_ID="tenant-b-guid"
TENANT_B_SUBSCRIPTION_ID="subscription-b-guid"
TENANT_B_RESOURCE_GROUP="rg-spoke"
TENANT_B_VNET_NAME="vnet-spoke"
TENANT_B_PEERING_NAME="peer-spoke-to-hub"

# Options
ALLOW_VNET_ACCESS="true"
ALLOW_FORWARDED_TRAFFIC="true"           # Required for gateway transit
ALLOW_GATEWAY_TRANSIT_A="true"           # Tenant A allows gateway transit
USE_REMOTE_GATEWAYS_A="false"
ALLOW_GATEWAY_TRANSIT_B="false"
USE_REMOTE_GATEWAYS_B="true"             # Tenant B uses Tenant A's gateway
```

**Address Spaces:**
- Tenant A (Hub): `10.0.0.0/16`
- Tenant B (Spoke): `10.1.0.0/16`
- On-premises: `172.16.0.0/16`

**Prerequisites:**
- VPN Gateway must exist in Tenant A before creating peering
- Gateway SKU must support transit (Basic SKU does not)

---

### Scenario 3: Multi-Region Peering

**Use Case:** Connect VNets across different Azure regions.

**Configuration:**
```bash
# Tenant A - East US
TENANT_A_ID="tenant-a-guid"
TENANT_A_SUBSCRIPTION_ID="subscription-a-guid"
TENANT_A_RESOURCE_GROUP="rg-eastus"
TENANT_A_VNET_NAME="vnet-eastus"
TENANT_A_PEERING_NAME="peer-eastus-to-westus"

# Tenant B - West US
TENANT_B_ID="tenant-b-guid"
TENANT_B_SUBSCRIPTION_ID="subscription-b-guid"
TENANT_B_RESOURCE_GROUP="rg-westus"
TENANT_B_VNET_NAME="vnet-westus"
TENANT_B_PEERING_NAME="peer-westus-to-eastus"

# Options
ALLOW_VNET_ACCESS="true"
ALLOW_FORWARDED_TRAFFIC="false"
ALLOW_GATEWAY_TRANSIT_A="false"
USE_REMOTE_GATEWAYS_A="false"
ALLOW_GATEWAY_TRANSIT_B="false"
USE_REMOTE_GATEWAYS_B="false"
```

**Address Spaces:**
- Tenant A (East US): `10.10.0.0/16`
- Tenant B (West US): `10.20.0.0/16`

**Notes:**
- Global VNet peering may incur additional data transfer costs
- Ensure both regions support global VNet peering

---

### Scenario 4: Peering with NVA (Network Virtual Appliance)

**Use Case:** Route traffic through a firewall/NVA for inspection.

**Configuration:**
```bash
# Tenant A (with NVA)
TENANT_A_ID="tenant-a-guid"
TENANT_A_SUBSCRIPTION_ID="subscription-a-guid"
TENANT_A_RESOURCE_GROUP="rg-security"
TENANT_A_VNET_NAME="vnet-security"
TENANT_A_PEERING_NAME="peer-security-to-workload"

# Tenant B
TENANT_B_ID="tenant-b-guid"
TENANT_B_SUBSCRIPTION_ID="subscription-b-guid"
TENANT_B_RESOURCE_GROUP="rg-workload"
TENANT_B_VNET_NAME="vnet-workload"
TENANT_B_PEERING_NAME="peer-workload-to-security"

# Options
ALLOW_VNET_ACCESS="true"
ALLOW_FORWARDED_TRAFFIC="true"           # Required for NVA forwarding
ALLOW_GATEWAY_TRANSIT_A="false"
USE_REMOTE_GATEWAYS_A="false"
ALLOW_GATEWAY_TRANSIT_B="false"
USE_REMOTE_GATEWAYS_B="false"
```

**Address Spaces:**
- Tenant A (Security): `10.100.0.0/16`
- Tenant B (Workload): `10.200.0.0/16`

**Additional Setup Required:**

1. **Enable IP Forwarding on NVA:**
   ```bash
   az network nic update \
     --resource-group rg-security \
     --name nva-nic \
     --ip-forwarding true
   ```

2. **Create User Defined Routes (UDR):**
   ```bash
   # In Tenant B - route traffic to NVA in Tenant A
   az network route-table create \
     --resource-group rg-workload \
     --name rt-to-nva

   az network route-table route create \
     --resource-group rg-workload \
     --route-table-name rt-to-nva \
     --name route-to-tenant-a \
     --address-prefix 10.100.0.0/16 \
     --next-hop-type VirtualAppliance \
     --next-hop-ip-address 10.100.1.4  # NVA IP

   az network vnet subnet update \
     --resource-group rg-workload \
     --vnet-name vnet-workload \
     --name default \
     --route-table rt-to-nva
   ```

---

## Testing Connectivity

After creating peering, test connectivity between VNets:

### Deploy Test VMs

```bash
# Tenant A - Deploy test VM
az vm create \
  --resource-group {RESOURCE_GROUP_A} \
  --name vm-test-a \
  --image Ubuntu2204 \
  --vnet-name {VNET_A_NAME} \
  --subnet default \
  --admin-username azureuser \
  --generate-ssh-keys

# Tenant B - Deploy test VM
az vm create \
  --resource-group {RESOURCE_GROUP_B} \
  --name vm-test-b \
  --image Ubuntu2204 \
  --vnet-name {VNET_B_NAME} \
  --subnet default \
  --admin-username azureuser \
  --generate-ssh-keys
```

### Test Connectivity

```bash
# From VM in Tenant A, ping VM in Tenant B
ping <TENANT_B_VM_PRIVATE_IP>

# Test SSH
ssh azureuser@<TENANT_B_VM_PRIVATE_IP>

# Test specific port (e.g., web server)
curl http://<TENANT_B_VM_PRIVATE_IP>:80
```

### Troubleshooting Connectivity

If ping fails:

1. **Check peering status:**
   ```bash
   az network vnet peering show \
     --resource-group {RG} \
     --vnet-name {VNET} \
     --name {PEERING_NAME} \
     --query '{state:peeringState, sync:peeringSyncLevel}'
   ```

2. **Check NSG rules:**
   ```bash
   az network nsg rule list \
     --resource-group {RG} \
     --nsg-name {NSG_NAME} \
     --output table
   ```

3. **Check effective routes:**
   ```bash
   az network nic show-effective-route-table \
     --resource-group {RG} \
     --name {NIC_NAME} \
     --output table
   ```

4. **Use Connection Troubleshoot:**
   ```bash
   az network watcher test-connectivity \
     --resource-group {RG} \
     --source-resource {VM_A_ID} \
     --dest-resource {VM_B_ID} \
     --protocol Tcp \
     --dest-port 22
   ```

---

## Cost Considerations

### Data Transfer Costs

VNet peering incurs data transfer charges:

- **Intra-region peering:** Ingress and egress charges apply
- **Global peering:** Higher data transfer costs
- **Zone-redundant peering:** Additional costs for zone-redundant configurations

### Cost Optimization Tips

1. **Use private endpoints** for Azure services when possible
2. **Implement traffic filtering** with NSGs to reduce unnecessary traffic
3. **Monitor data transfer** with Azure Cost Management
4. **Consider ExpressRoute** for high-volume, predictable traffic patterns

### Estimate Costs

Use the [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/) to estimate VNet peering costs based on your expected data transfer volume.

---

## Monitoring and Alerts

### Set up monitoring for peering

```bash
# Create alert for peering disconnection
az monitor metrics alert create \
  --name "VNet Peering Disconnected" \
  --resource-group {RG} \
  --scopes {VNET_RESOURCE_ID} \
  --condition "avg PeeringState == 0" \
  --description "Alert when VNet peering is disconnected"
```

### View peering metrics

```bash
# View peering metrics
az monitor metrics list \
  --resource {VNET_RESOURCE_ID} \
  --metric "PeeringSyncLevel" \
  --start-time 2025-12-01T00:00:00Z \
  --end-time 2025-12-01T23:59:59Z
```

---

## Additional Resources

- [Azure VNet Peering Pricing](https://azure.microsoft.com/en-us/pricing/details/virtual-network/)
- [VNet Peering Constraints](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview#constraints)
- [Gateway Transit Requirements](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-peering-gateway-transit)
