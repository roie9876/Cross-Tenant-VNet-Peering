# Cross-Tenant VNet Peering Automation

This repository contains an automated Azure CLI script for creating VNet peering between two Azure tenants using custom RBAC roles with least-privilege access.

## 📋 Overview

Cross-tenant VNet peering allows Virtual Networks in different Azure AD tenants to communicate with each other. This automation:

- ✅ Creates bidirectional VNet peering between two Azure tenants
- ✅ Uses custom RBAC roles with minimal required permissions
- ✅ Validates address space overlap
- ✅ Provides colored output and progress indicators
- ✅ Automatically verifies peering status
- ✅ Supports advanced peering options (gateway transit, forwarded traffic)

## 🚀 Quick Start

### For Customers: One-Click Deployment

If your ISV/partner sent you here, click the button below to deploy the VNet peering **in your Azure environment**:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Froie9876%2FCross-Tenant-VNet-Peering%2Fmain%2Ftemplates%2Fdeploy-vnet-peering.json)

**How it works:**
1. Click button → Opens Azure Portal authenticated as **you** (the customer)
2. Fill in **your VNet name** and **resource group**
3. Paste the **ISV's VNet resource ID** (they provide this)
4. Click Deploy → Creates peering **in your tenant only**

**You'll need:** `vnet-peer` custom role assigned (see [Prerequisites](docs/PREREQUISITES.md))

---

### For ISVs/Implementers: Full Setup

### 1. Review Prerequisites
Before implementation, read **[docs/PREREQUISITES.md](docs/PREREQUISITES.md)** to understand:
- Required tools and installations
- Azure environment requirements
- Custom RBAC role setup
- User account or Service Principal configuration

### 2. Set Up Custom RBAC Roles

Create the `vnet-peer` custom role in **both** tenants:

```bash
# Tenant A
az login --tenant <TENANT_A_ID>
az account set --subscription <SUBSCRIPTION_A_ID>

# Edit templates/vnet-peer-role.json and update assignableScopes
az role definition create --role-definition templates/vnet-peer-role.json

az role assignment create \
  --assignee <YOUR_EMAIL> \
  --role "vnet-peer" \
  --scope "/subscriptions/<SUBSCRIPTION_A_ID>/resourceGroups/<RESOURCE_GROUP_A>"

# Tenant B (repeat with Tenant B values)
az login --tenant <TENANT_B_ID>
az account set --subscription <SUBSCRIPTION_B_ID>

# Update templates/vnet-peer-role.json with Tenant B subscription and resource group
az role definition create --role-definition templates/vnet-peer-role.json

az role assignment create \
  --assignee <YOUR_EMAIL> \
  --role "vnet-peer" \
  --scope "/subscriptions/<SUBSCRIPTION_B_ID>/resourceGroups/<RESOURCE_GROUP_B>"
```

### 3. Configure the Script

Edit `scripts/create-cross-tenant-vnet-peering.sh` and update the configuration section:

```bash
# Tenant A Configuration
TENANT_A_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
TENANT_A_SUBSCRIPTION_ID="your-subscription-a-id"
TENANT_A_RESOURCE_GROUP="your-resource-group-a"
TENANT_A_VNET_NAME="your-vnet-a-name"
TENANT_A_PEERING_NAME="peer-tenantA-to-tenantB"

# Tenant B Configuration
TENANT_B_ID="yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
TENANT_B_SUBSCRIPTION_ID="your-subscription-b-id"
TENANT_B_RESOURCE_GROUP="your-resource-group-b"
TENANT_B_VNET_NAME="your-vnet-b-name"
TENANT_B_PEERING_NAME="peer-tenantB-to-tenantA"

# Peering Options
ALLOW_VNET_ACCESS="true"
ALLOW_FORWARDED_TRAFFIC="false"
ALLOW_GATEWAY_TRANSIT_A="false"
USE_REMOTE_GATEWAYS_A="false"
ALLOW_GATEWAY_TRANSIT_B="false"
USE_REMOTE_GATEWAYS_B="false"
```

### 4. Run the Script

```bash
# Make the script executable
chmod +x scripts/create-cross-tenant-vnet-peering.sh

# Run the script
./scripts/create-cross-tenant-vnet-peering.sh
```

The script will:
1. Validate prerequisites and configuration
2. Gather VNet information from both tenants
3. Check for address space overlap
4. Display a summary and request confirmation
5. Create peering connections in both directions
6. Verify the final peering status

## 📁 Repository Structure

```
Cross-Tenant-VNet-Peering/
├── docs/                           # Documentation
│   ├── Cross-Tenant-VNet-Peering-Guide.md    # Complete implementation guide
│   ├── PREREQUISITES.md            # Setup requirements and preparation
│   ├── DEPLOYMENT.md               # ARM/Bicep deployment guide
│   └── EXAMPLES.md                 # Usage scenarios and examples
├── templates/                      # ARM/Bicep templates
│   ├── deploy-vnet-peering.bicep   # Bicep template
│   ├── deploy-vnet-peering.json    # Compiled ARM template
│   ├── deploy-vnet-peering.parameters.json   # Parameters file
│   ├── createUiDefinition.json     # Azure Portal UI definition
│   └── vnet-peer-role.json         # Custom RBAC role definition
├── scripts/                        # Automation scripts
│   ├── create-cross-tenant-vnet-peering.sh   # Main bash script
│   └── config-template.sh          # Configuration template
├── .github/                        # GitHub configuration
│   ├── workflows/                  # CI/CD workflows
│   ├── ISSUE_TEMPLATE/            # Issue templates
│   └── PULL_REQUEST_TEMPLATE.md   # PR template
├── README.md                       # This file - quick start guide
├── LICENSE                         # MIT License
├── CONTRIBUTING.md                 # Contribution guidelines
├── SECURITY.md                     # Security policy
└── CHANGELOG.md                    # Version history

## 🔑 Key Features

### Security Best Practices
- **Least Privilege Access:** Uses custom RBAC role with only required permissions
- **Resource Group Scoped:** Roles limited to specific resource groups, not entire subscriptions
- **No Owner/Contributor Required:** Eliminates need for excessive permissions

### Automation Features
- **Pre-flight Checks:** Validates Azure CLI installation, configuration, and prerequisites
- **Address Space Validation:** Prevents peering with overlapping IP ranges
- **Interactive Confirmation:** Shows summary before making changes
- **Status Verification:** Automatically checks peering state after creation
- **Colored Output:** Easy-to-read progress indicators and status messages

### Advanced Options
- Gateway transit for VPN connectivity
- Forwarded traffic for Network Virtual Appliances (NVA)
- Configurable peering names
- Support for complex networking scenarios

## 📖 Documentation

### Quick Reference
- **🚀 Deploy Button Guide:** [DEPLOY-BUTTON-REFERENCE.md](DEPLOY-BUTTON-REFERENCE.md) - Quick reference for sharing with customers
- **👥 ISV Customer Guide:** [docs/ISV-CUSTOMER-GUIDE.md](docs/ISV-CUSTOMER-GUIDE.md) - Complete ISV workflow and email templates
- **📋 Prerequisites:** [docs/PREREQUISITES.md](docs/PREREQUISITES.md)
- **Deployment Guide:** [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)
- **Full Guide:** [docs/Cross-Tenant-VNet-Peering-Guide.md](docs/Cross-Tenant-VNet-Peering-Guide.md)
- **Examples:** [docs/EXAMPLES.md](docs/EXAMPLES.md)

### Important Considerations

#### ⚠️ Service Principal Limitation
**Service Principals CANNOT create the initial cross-tenant VNet peering** due to Azure's authorization model. You must use a **User Account** that has access to both tenants.

Service Principals can be used for:
- ✅ Managing existing peerings (update, delete, sync)
- ✅ Creating and managing route tables (UDRs)
- ✅ Updating subnet configurations

#### Address Space Requirements
VNets must have **non-overlapping** IP address ranges:

✅ **Valid:**
```
Tenant A: 192.168.0.0/16
Tenant B: 10.0.0.0/16
```

❌ **Invalid:**
```
Tenant A: 10.0.0.0/16
Tenant B: 10.1.0.0/16  (both in 10.x.x.x range)
```

#### Bidirectional Peering
Cross-tenant peering requires **both sides** to be created separately:
1. Peering from Tenant A to Tenant B
2. Peering from Tenant B to Tenant A

Both must exist for the connection to be established.

## 🔍 Verification

After running the script, verify the peering is working:

### Check Peering Status

```bash
# Tenant A
az network vnet peering list \
  --resource-group <RG_A> \
  --vnet-name <VNET_A> \
  --output table

# Tenant B
az network vnet peering list \
  --resource-group <RG_B> \
  --vnet-name <VNET_B> \
  --output table
```

**Expected Output:**
- PeeringState: `Connected`
- SyncLevel: `FullyInSync`
- ProvisioningState: `Succeeded`

### Test Connectivity

Deploy test VMs in each VNet and verify network connectivity:

```bash
# From VM in Tenant A
ping <IP_ADDRESS_IN_TENANT_B>

# From VM in Tenant B
ping <IP_ADDRESS_IN_TENANT_A>
```

## 🛠️ Troubleshooting

### Common Issues

#### Peering State: "Initiated"
**Cause:** Only one side of the peering has been created.
**Solution:** Ensure both Tenant A and Tenant B peering connections are created.

#### "User not authorized"
**Cause:** Missing `vnet-peer` role assignment.
**Solution:** Verify role assignments with:
```bash
az role assignment list --assignee <YOUR_EMAIL> --all
```

#### Address Space Overlap
**Cause:** VNets have overlapping IP ranges.
**Solution:** Modify VNet address spaces before creating peering.

#### MFA/Authentication Issues
**Cause:** Token expired or MFA required.
**Solution:** The script uses device code authentication. Complete the browser-based authentication when prompted.

For more troubleshooting steps, see [docs/Cross-Tenant-VNet-Peering-Guide.md](docs/Cross-Tenant-VNet-Peering-Guide.md#troubleshooting).

## 📊 Custom RBAC Role Permissions

The `vnet-peer` role includes these permissions:

| Permission | Purpose |
|------------|---------|
| `Microsoft.Network/virtualNetworks/*` | Read and write VNet configurations |
| `Microsoft.Network/virtualNetworks/virtualNetworkPeerings/*` | Manage peering connections |
| `Microsoft.Network/virtualNetworks/peer/action` | **Critical:** Authorize cross-tenant peering |
| `Microsoft.Network/routeTables/*` | Manage User Defined Routes (UDR) |
| `Microsoft.Network/networkSecurityGroups/read` | Read NSG configurations |
| `Microsoft.Network/networkSecurityGroups/join/action` | Associate NSG with subnets |

This is significantly more restrictive than Owner or Contributor roles.

## 🔗 Architecture

```
Tenant A (Your Organization)           Tenant B (Partner Organization)
Subscription: xxx-xxx-xxx              Subscription: yyy-yyy-yyy
├── Resource Group: rg-tenant-a        ├── Resource Group: rg-tenant-b
    └── VNet: vnet-tenant-a                └── VNet: vnet-tenant-b
        Address: 192.168.0.0/16                Address: 10.0.0.0/16
        │                                      │
        └──────── Peering Connection ─────────┘
               (Bidirectional)
```

## 🔐 Security Considerations

1. **Least Privilege:** Always use custom RBAC roles instead of Owner/Contributor
2. **Scope Limitation:** Assign roles at resource group level, not subscription level
3. **Audit Logs:** Enable Azure Activity Logs to monitor peering operations
4. **Network Security Groups:** Apply NSGs to subnets to control traffic flow
5. **Regular Review:** Periodically review role assignments and remove unnecessary access

## 📚 Additional Resources

- [Azure VNet Peering Documentation](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview)
- [Azure Custom RBAC Roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/custom-roles)
- [Azure CLI Reference](https://learn.microsoft.com/en-us/cli/azure/network/vnet/peering)
- [Cross-Tenant Scenarios](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview#cross-subscription-and-cross-tenant-peering)

## 🤝 Contributing

Found an issue or have a suggestion? Please:
1. Review the existing documentation
2. Test your changes thoroughly
3. Update documentation as needed

## 📝 License

This project is provided as-is for educational and operational purposes.

## 🎯 Choose Your Deployment Method

### Option 1: ARM/Bicep Templates (Recommended for ISV)
**Best for:** Professional deployments, customer-facing solutions, GUI-based setup

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for:
- Deploy to Azure button
- Azure Portal deployment
- Built-in validation
- What-if previews

### Option 2: Bash Script (Recommended for DevOps)
**Best for:** Automation, CI/CD pipelines, scripted workflows

See [scripts/README.md](scripts/README.md) for setup instructions

## ✅ Checklist Before Deploying

- [ ] Azure CLI installed and configured
- [ ] Both VNets exist with non-overlapping address spaces
- [ ] Custom `vnet-peer` role created in both tenants
- [ ] User account has `vnet-peer` role assigned in both tenants
- [ ] Configuration values prepared
- [ ] You have access to authenticate to both tenants
- [ ] You have reviewed [docs/PREREQUISITES.md](docs/PREREQUISITES.md)

**Ready? Choose your deployment method and establish your cross-tenant VNet peering! 🚀**
