# Cross-Tenant VNet Peering Automation

This repository provides **two deployment methods** for creating VNet peering between Azure tenants using custom RBAC roles with least-privilege access.

## 🎯 Choose Your Deployment Method

| Method | Best For | Complexity | Customer-Friendly |
|--------|----------|------------|-------------------|
| **🔘 ARM/Bicep Templates** | ISVs, Enterprise, GUI users | ⭐ Easy | ✅ Yes - One-click button |
| **⚙️ Bash Script** | DevOps, Automation, CI/CD | ⭐⭐ Medium | ❌ Requires CLI knowledge |

### 🔘 Option 1: ARM/Bicep Templates (Recommended for ISVs)

**Perfect for:**
- ISVs connecting customers to their service
- Customers who prefer Azure Portal (no CLI)
- Enterprise deployments requiring approval workflows
- Documented, auditable deployments

**Advantages:**
- ✅ One-click "Deploy to Azure" button
- ✅ GUI-based deployment in Azure Portal
- ✅ Built-in validation before deployment
- ✅ What-if preview (see changes before applying)
- ✅ Professional customer experience
- ✅ Deployment history and audit trail

**See:** [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for full guide

### ⚙️ Option 2: Bash Script (For DevOps/Automation)

**Perfect for:**
- DevOps teams automating deployments
- CI/CD pipelines
- Internal IT operations
- Users comfortable with Azure CLI

**Advantages:**
- ✅ Fully automated - no manual steps
- ✅ Pre-flight validation checks
- ✅ Colored output and progress indicators
- ✅ Address space overlap detection
- ✅ Automatic status verification
- ✅ Easy to integrate in automation workflows

**See:** [scripts/README.md](scripts/README.md) for full guide

---

## 📋 Common Features (Both Methods)

- ✅ **Least Privilege Access:** Custom RBAC role with minimal permissions
- ✅ **Bidirectional Peering:** Creates both sides automatically
- ✅ **Address Space Validation:** Prevents overlapping IP ranges
- ✅ **Cross-Tenant Support:** Works across different Azure AD tenants
- ✅ **Advanced Options:** Gateway transit, forwarded traffic, etc.

## 🚀 Quick Start

### Method 1: Deploy to Azure Button (Bicep/ARM Template)

**For Customers:** Click the button to deploy in your Azure Portal

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Froie9876%2FCross-Tenant-VNet-Peering%2Fmain%2Ftemplates%2Fdeploy-vnet-peering.json)

**What happens:**
1. Opens Azure Portal (you authenticate with your account)
2. Fill parameters: your VNet, resource group, remote VNet resource ID
3. Click Deploy → Peering created **in your tenant only**

⚠️ **Important:** 
- **Prerequisites:** You need `vnet-peer` custom role assigned (one-time setup by your admin)
- **Two-sided deployment:** This creates YOUR side only. ISV must deploy their side separately.
- **No admin needed:** You don't need Owner/Contributor, just the custom role!

❓ **New to this?** Read [Why Custom Role and Two-Sided Deployment?](docs/WHY-CUSTOM-ROLE-AND-TWO-SIDED.md)

**For ISVs:** Share this button with customers. See [docs/ISV-CUSTOMER-GUIDE.md](docs/ISV-CUSTOMER-GUIDE.md) for email templates and workflow.

**Full Guide:** [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)

---

### Method 2: Bash Script (Automated CLI)

**For DevOps/Automation Teams**

#### 1. Review Prerequisites
Read **[docs/PREREQUISITES.md](docs/PREREQUISITES.md)** to understand:
- Required tools and installations
- Azure environment requirements
- Custom RBAC role setup
- User account or Service Principal configuration

#### 2. Set Up Custom RBAC Roles

Create the `vnet-peer` custom role in **both** tenants (required for both methods):

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

#### 3. Configure the Bash Script

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

#### 4. Run the Bash Script

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

**Full Guide:** [scripts/README.md](scripts/README.md)

---

## 🤔 Which Method Should I Use?

**📊 See detailed comparison:** [DEPLOYMENT-METHODS-COMPARISON.md](DEPLOYMENT-METHODS-COMPARISON.md)

### Use ARM/Bicep Templates (Method 1) if:
- ✅ You're an ISV connecting customers to your service
- ✅ Your customers prefer GUI over CLI
- ✅ You want professional "Deploy to Azure" button experience
- ✅ You need deployment approval workflows
- ✅ You want built-in what-if validation
- ✅ Customers will deploy their side independently

### Use Bash Script (Method 2) if:
- ✅ You're a DevOps engineer automating deployments
- ✅ You control both Azure tenants
- ✅ You want to integrate into CI/CD pipelines
- ✅ You prefer command-line automation
- ✅ You want a single script to deploy both sides
- ✅ You're comfortable with Azure CLI

### Can I use both?
**Yes!** Many ISVs use:
- **Templates for customers** (easy button-click deployment)
- **Bash script for their own side** (automated ISV environment setup)

This is actually the recommended hybrid approach.

## 📁 Repository Structure

```
Cross-Tenant-VNet-Peering/
├── docs/                           # 📚 Documentation
│   ├── README.md                   # Documentation guide and navigation
│   ├── Cross-Tenant-VNet-Peering-Guide.md    # Complete manual implementation guide
│   ├── PREREQUISITES.md            # Setup requirements and preparation
│   ├── DEPLOYMENT.md               # 🔘 ARM/Bicep template deployment guide
│   ├── ISV-CUSTOMER-GUIDE.md       # ISV workflow and customer email templates
│   └── EXAMPLES.md                 # Usage scenarios and examples
├── templates/                      # 🔘 ARM/Bicep templates (Method 1)
│   ├── README.md                   # Templates documentation
│   ├── deploy-vnet-peering.bicep   # Bicep template source
│   ├── deploy-vnet-peering.json    # Compiled ARM template (for Deploy to Azure button)
│   ├── deploy-vnet-peering.parameters.json   # Parameters file example
│   ├── createUiDefinition.json     # Azure Portal UI definition
│   └── vnet-peer-role.json         # Custom RBAC role definition
├── scripts/                        # ⚙️ Automation scripts (Method 2)
│   ├── README.md                   # Scripts documentation
│   ├── create-cross-tenant-vnet-peering.sh   # Main bash script
│   └── config-template.sh          # Configuration template
├── .github/                        # GitHub configuration
│   ├── workflows/                  # CI/CD workflows
│   ├── ISSUE_TEMPLATE/            # Issue templates
│   └── PULL_REQUEST_TEMPLATE.md   # PR template
├── DEPLOY-BUTTON-REFERENCE.md      # 🚀 Quick reference for Deploy to Azure button
├── README.md                       # This file - main entry point
├── LICENSE                         # MIT License
├── CONTRIBUTING.md                 # Contribution guidelines
├── SECURITY.md                     # Security policy
├── CHANGELOG.md                    # Version history
└── .gitignore                      # Excluded files
└── CHANGELOG.md                    # Version history

## 🔑 Key Features

### Security Best Practices (Both Methods)
- **Least Privilege Access:** Uses custom RBAC role with only required permissions
- **Resource Group Scoped:** Roles limited to specific resource groups, not entire subscriptions
- **No Owner/Contributor Required:** Eliminates need for excessive permissions
- **Audit Trail:** All deployments logged in Azure Activity Log

### Method 1: ARM/Bicep Templates Features
- **One-Click Deployment:** Deploy to Azure button for customers
- **GUI-Based:** No CLI installation required
- **Built-in Validation:** Azure validates before deploying
- **What-If Preview:** See changes before applying
- **Portal UI Definition:** Custom form with help text and validation
- **Deployment History:** Full audit trail in Azure Portal

### Method 2: Bash Script Features
- **Full Automation:** Single command deploys both sides
- **Pre-flight Checks:** Validates Azure CLI, config, prerequisites
- **Address Space Validation:** Prevents overlapping IP ranges
- **Interactive Confirmation:** Shows summary before changes
- **Status Verification:** Automatically checks peering state
- **Colored Output:** Easy-to-read progress indicators
- **CI/CD Ready:** Easy to integrate into pipelines

### Advanced Options (Both Methods)
- Gateway transit for VPN connectivity
- Forwarded traffic for Network Virtual Appliances (NVA)
- Configurable peering names
- Support for hub-and-spoke, multi-region scenarios

## 📖 Documentation

### Deployment Methods Documentation

| Document | For Method | Description |
|----------|-----------|-------------|
| [📋 PREREQUISITES.md](docs/PREREQUISITES.md) | **Both** | Setup requirements, RBAC roles, preparation steps |
| [🔘 DEPLOYMENT.md](docs/DEPLOYMENT.md) | **Method 1** | ARM/Bicep template deployment guide |
| [⚙️ scripts/README.md](scripts/README.md) | **Method 2** | Bash script usage and automation guide |
| [🚀 DEPLOY-BUTTON-REFERENCE.md](DEPLOY-BUTTON-REFERENCE.md) | **Method 1** | Quick reference for Deploy to Azure button |
| [👥 ISV-CUSTOMER-GUIDE.md](docs/ISV-CUSTOMER-GUIDE.md) | **Method 1** | ISV workflow and customer email templates |

### Additional Documentation

| Document | Description |
|----------|-------------|
| [📚 docs/README.md](docs/README.md) | Documentation navigation guide |
| [❓ WHY-CUSTOM-ROLE-AND-TWO-SIDED.md](docs/WHY-CUSTOM-ROLE-AND-TWO-SIDED.md) | **Why custom role? Why two deployments? Explained!** |
| [📖 Cross-Tenant-VNet-Peering-Guide.md](docs/Cross-Tenant-VNet-Peering-Guide.md) | Complete manual implementation guide |
| [💡 EXAMPLES.md](docs/EXAMPLES.md) | Real-world usage scenarios |

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
