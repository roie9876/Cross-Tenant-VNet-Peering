# Prerequisites for Cross-Tenant VNet Peering

This document outlines all prerequisites and preparation steps required before running the `create-cross-tenant-vnet-peering.sh` script.

## Table of Contents
1. [Environment Prerequisites](#environment-prerequisites)
2. [Azure Prerequisites](#azure-prerequisites)
3. [Custom RBAC Role Setup](#custom-rbac-role-setup)
4. [User Account or Service Principal](#user-account-or-service-principal)
5. [Pre-Script Preparation Checklist](#pre-script-preparation-checklist)

---

## Environment Prerequisites

### 1. Install Azure CLI

**macOS:**
```bash
brew install azure-cli
```

**Linux (Ubuntu/Debian):**
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

**Windows:**
Download and install from: https://aka.ms/installazurecliwindows

**Verify Installation:**
```bash
az --version
```

### 2. Install jq (Optional but Recommended)

The script uses `jq` for JSON parsing to provide cleaner output.

**macOS:**
```bash
brew install jq
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get install jq
```

**Windows:**
Download from: https://stedolan.github.io/jq/download/

### 3. Terminal Access

- **macOS/Linux:** Use Terminal or any bash-compatible shell
- **Windows:** Use WSL (Windows Subsystem for Linux), Git Bash, or Azure Cloud Shell

---

## Azure Prerequisites

### 1. Two Azure Tenants with Active Subscriptions

You need:
- **Tenant A:** Tenant ID, Subscription ID, and access credentials
- **Tenant B:** Tenant ID, Subscription ID, and access credentials

**To find your Tenant ID:**
```bash
az login
az account show --query tenantId -o tsv
```

**To list your subscriptions:**
```bash
az account list --query "[].{Name:name, SubscriptionId:id, TenantId:tenantId}" --output table
```

### 2. Existing Virtual Networks

Both VNets must exist before creating the peering. If they don't exist, create them:

**Tenant A VNet:**
```bash
az network vnet create \
  --resource-group <RESOURCE_GROUP_A> \
  --name <VNET_NAME_A> \
  --address-prefix 192.168.0.0/16 \
  --subnet-name default \
  --subnet-prefix 192.168.1.0/24
```

**Tenant B VNet:**
```bash
az network vnet create \
  --resource-group <RESOURCE_GROUP_B> \
  --name <VNET_NAME_B> \
  --address-prefix 10.0.0.0/16 \
  --subnet-name default \
  --subnet-prefix 10.0.1.0/24
```

### 3. Non-Overlapping Address Spaces

**Critical Requirement:** The VNets must have non-overlapping IP address ranges.

**Example of Valid Configuration:**
- Tenant A VNet: `192.168.0.0/16`
- Tenant B VNet: `10.0.0.0/16`

**Example of Invalid Configuration (WILL FAIL):**
- Tenant A VNet: `10.0.0.0/16`
- Tenant B VNet: `10.1.0.0/16` ❌ (both in 10.x.x.x range)

**Check VNet address spaces:**
```bash
# Tenant A
az network vnet show --resource-group <RG_A> --name <VNET_A> --query addressSpace

# Tenant B
az network vnet show --resource-group <RG_B> --name <VNET_B> --query addressSpace
```

---

## Custom RBAC Role Setup

The script requires a custom RBAC role called `vnet-peer` with least-privilege permissions for VNet peering operations.

### Step 1: Create the Role Definition File

Save the following JSON to a file named `vnet-peer-role.json`:

```json
{
  "properties": {
    "roleName": "vnet-peer",
    "description": "Allow VNet peering, sync and UDR changes on the scoped VNets.",
    "assignableScopes": [
      "/subscriptions/{SUBSCRIPTION_ID}/resourceGroups/{RESOURCE_GROUP_NAME}"
    ],
    "permissions": [
      {
        "actions": [
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
        "notActions": [],
        "dataActions": [],
        "notDataActions": []
      }
    ]
  }
}
```

### Step 2: Create the Role in Tenant A

```bash
# Login to Tenant A
az login --tenant <TENANT_A_ID>
az account set --subscription <SUBSCRIPTION_A_ID>

# Update the assignableScopes in vnet-peer-role.json
# Replace {SUBSCRIPTION_ID} with your Subscription A ID
# Replace {RESOURCE_GROUP_NAME} with your Resource Group A name

# Create the custom role
az role definition create --role-definition vnet-peer-role.json
```

**Expected Output:**
```json
{
  "assignableScopes": [
    "/subscriptions/xxxxxxxx-.../resourceGroups/your-rg"
  ],
  "description": "Allow VNet peering, sync and UDR changes on the scoped VNets.",
  "id": "/subscriptions/xxxxxxxx-.../providers/Microsoft.Authorization/roleDefinitions/...",
  "name": "...",
  "permissions": [...],
  "roleName": "vnet-peer",
  "roleType": "CustomRole"
}
```

### Step 3: Create the Role in Tenant B

```bash
# Login to Tenant B
az login --tenant <TENANT_B_ID>
az account set --subscription <SUBSCRIPTION_B_ID>

# Update the assignableScopes in vnet-peer-role.json
# Replace {SUBSCRIPTION_ID} with your Subscription B ID
# Replace {RESOURCE_GROUP_NAME} with your Resource Group B name

# Create the custom role
az role definition create --role-definition vnet-peer-role.json
```

---

## User Account or Service Principal

You need authentication credentials that have the `vnet-peer` role assigned in **BOTH** tenants.

### Option 1: User Account (Recommended for Manual Execution)

**Requirements:**
- User account (e.g., user@domain.com) that exists as a guest user in both tenants
- The user must be able to authenticate to both tenants
- The user must have the custom `vnet-peer` role assigned in both tenants

**Assign the vnet-peer role to a user:**

**In Tenant A:**
```bash
az login --tenant <TENANT_A_ID>
az account set --subscription <SUBSCRIPTION_A_ID>

az role assignment create \
  --assignee <USER_EMAIL_OR_OBJECT_ID> \
  --role "vnet-peer" \
  --scope "/subscriptions/<SUBSCRIPTION_A_ID>/resourceGroups/<RESOURCE_GROUP_A>"
```

**In Tenant B:**
```bash
az login --tenant <TENANT_B_ID>
az account set --subscription <SUBSCRIPTION_B_ID>

az role assignment create \
  --assignee <USER_EMAIL_OR_OBJECT_ID> \
  --role "vnet-peer" \
  --scope "/subscriptions/<SUBSCRIPTION_B_ID>/resourceGroups/<RESOURCE_GROUP_B>"
```

**Verify role assignments:**
```bash
# In Tenant A
az role assignment list \
  --assignee <USER_EMAIL> \
  --scope "/subscriptions/<SUBSCRIPTION_A_ID>/resourceGroups/<RESOURCE_GROUP_A>" \
  --query "[?roleDefinitionName=='vnet-peer']" \
  --output table

# In Tenant B
az role assignment list \
  --assignee <USER_EMAIL> \
  --scope "/subscriptions/<SUBSCRIPTION_B_ID>/resourceGroups/<RESOURCE_GROUP_B>" \
  --query "[?roleDefinitionName=='vnet-peer']" \
  --output table
```

### Option 2: Service Principal (For Automation)

**⚠️ Important Limitation:** 

Service Principals **CANNOT** create the initial cross-tenant VNet peering due to Azure's authorization requirements. However, they can:
- ✅ Manage existing peerings (update, delete, sync)
- ✅ Create and manage route tables (UDRs)
- ✅ Update subnet configurations

**For initial peering creation, you MUST use Option 1 (User Account).**

If you still need an SPN for post-deployment management:

**Create Service Principal in Tenant A:**
```bash
az login --tenant <TENANT_A_ID>
az account set --subscription <SUBSCRIPTION_A_ID>

# Create SPN
az ad sp create-for-rbac --name "vnet-peering-automation" --skip-assignment

# Output will include:
# {
#   "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
#   "password": "your-secret-password",
#   "tenant": "tenant-a-id"
# }

# Assign the vnet-peer role
az role assignment create \
  --assignee <APP_ID> \
  --role "vnet-peer" \
  --scope "/subscriptions/<SUBSCRIPTION_A_ID>/resourceGroups/<RESOURCE_GROUP_A>"
```

**Register SPN in Tenant B (if using multi-tenant approach):**

This requires admin consent in Tenant B and is complex. For cross-tenant peering, **stick with User Account option**.

---

## Pre-Script Preparation Checklist

Before running the script, ensure you have collected the following information:

### Tenant A Information
- [ ] Tenant ID
- [ ] Subscription ID
- [ ] Resource Group Name
- [ ] VNet Name
- [ ] VNet Address Space (verify no overlap)
- [ ] User has `vnet-peer` role assigned

### Tenant B Information
- [ ] Tenant ID
- [ ] Subscription ID
- [ ] Resource Group Name
- [ ] VNet Name
- [ ] VNet Address Space (verify no overlap)
- [ ] User has `vnet-peer` role assigned

### Script Configuration
- [ ] Azure CLI installed and working
- [ ] `jq` installed (optional)
- [ ] Script downloaded and configured with your values
- [ ] Script has execute permissions: `chmod +x create-cross-tenant-vnet-peering.sh`

### Verification Commands

**Test authentication to both tenants:**
```bash
# Test Tenant A
az login --tenant <TENANT_A_ID>
az account set --subscription <SUBSCRIPTION_A_ID>
az account show

# Test Tenant B
az login --tenant <TENANT_B_ID>
az account set --subscription <SUBSCRIPTION_B_ID>
az account show
```

**Verify VNets exist:**
```bash
# Tenant A
az network vnet show --resource-group <RG_A> --name <VNET_A> --query name

# Tenant B
az network vnet show --resource-group <RG_B> --name <VNET_B> --query name
```

**Verify role assignments:**
```bash
# Tenant A
az role assignment list \
  --assignee <YOUR_EMAIL> \
  --scope "/subscriptions/<SUB_A>/resourceGroups/<RG_A>" \
  --query "[].{Role:roleDefinitionName, Scope:scope}" \
  --output table

# Tenant B
az role assignment list \
  --assignee <YOUR_EMAIL> \
  --scope "/subscriptions/<SUB_B>/resourceGroups/<RG_B>" \
  --query "[].{Role:roleDefinitionName, Scope:scope}" \
  --output table
```

---

## Configuration Steps

### 1. Edit the Script

Open `create-cross-tenant-vnet-peering.sh` and update the configuration section:

```bash
# Tenant A Configuration
TENANT_A_ID="your-tenant-a-id"
TENANT_A_SUBSCRIPTION_ID="your-subscription-a-id"
TENANT_A_RESOURCE_GROUP="your-resource-group-a"
TENANT_A_VNET_NAME="your-vnet-a-name"
TENANT_A_PEERING_NAME="peer-tenantA-to-tenantB"

# Tenant B Configuration
TENANT_B_ID="your-tenant-b-id"
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

### 2. Make the Script Executable

```bash
chmod +x create-cross-tenant-vnet-peering.sh
```

### 3. Run the Script

```bash
./create-cross-tenant-vnet-peering.sh
```

The script will:
1. Validate all prerequisites
2. Gather VNet information from both tenants
3. Validate address spaces
4. Display a summary and ask for confirmation
5. Create peering from Tenant A to Tenant B
6. Create peering from Tenant B to Tenant A
7. Verify the peering status

---

## Common Issues and Solutions

### Issue 1: "User not authorized to perform action"

**Solution:** Verify that the `vnet-peer` custom role is assigned to your user account in both tenants.

```bash
az role assignment list --assignee <YOUR_EMAIL> --all
```

### Issue 2: "Address space overlap"

**Solution:** Ensure VNets have completely non-overlapping address spaces. You may need to modify the VNet address space before creating peering.

### Issue 3: "Peering state shows 'Initiated' instead of 'Connected'"

**Solution:** This means only one side of the peering has been created. Ensure the script completes both Tenant A and Tenant B peering creation.

### Issue 4: "Cannot find subscription"

**Solution:** Make sure you're logged into the correct tenant before setting the subscription:
```bash
az login --tenant <CORRECT_TENANT_ID>
az account set --subscription <SUBSCRIPTION_ID>
```

### Issue 5: MFA/Authentication Issues

**Solution:** The script uses `--use-device-code` for authentication, which opens a browser for MFA. Ensure you complete the authentication flow when prompted.

---

## Security Best Practices

1. **Least Privilege:** Use the custom `vnet-peer` role instead of Owner or Contributor
2. **Scope Limitation:** Assign roles at the resource group level, not subscription level
3. **Audit Logging:** Enable Azure Activity Logs to monitor peering operations
4. **Regular Review:** Periodically review role assignments and remove unnecessary access
5. **Secret Management:** If using Service Principals, store credentials securely (Azure Key Vault)

---

## Additional Resources

- [Azure VNet Peering Documentation](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview)
- [Azure Custom RBAC Roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/custom-roles)
- [Azure CLI Documentation](https://learn.microsoft.com/en-us/cli/azure/)
- [Cross-Tenant VNet Peering Guide](./Cross-Tenant-VNet-Peering-Guide.md)

---

## Quick Start Example

Here's a complete example workflow:

```bash
# 1. Install Azure CLI (macOS)
brew install azure-cli
brew install jq

# 2. Create custom role definition
cat > vnet-peer-role.json <<EOF
{
  "properties": {
    "roleName": "vnet-peer",
    "description": "Allow VNet peering, sync and UDR changes on the scoped VNets.",
    "assignableScopes": [
      "/subscriptions/YOUR_SUB_A_ID/resourceGroups/YOUR_RG_A"
    ],
    "permissions": [
      {
        "actions": [
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
        "notActions": [],
        "dataActions": [],
        "notDataActions": []
      }
    ]
  }
}
EOF

# 3. Create role in Tenant A
az login --tenant TENANT_A_ID
az role definition create --role-definition vnet-peer-role.json
az role assignment create --assignee your@email.com --role "vnet-peer" \
  --scope "/subscriptions/SUB_A_ID/resourceGroups/RG_A"

# 4. Create role in Tenant B (update assignableScopes first)
az login --tenant TENANT_B_ID
# Update vnet-peer-role.json with Tenant B subscription and RG
az role definition create --role-definition vnet-peer-role.json
az role assignment create --assignee your@email.com --role "vnet-peer" \
  --scope "/subscriptions/SUB_B_ID/resourceGroups/RG_B"

# 5. Configure and run the script
chmod +x create-cross-tenant-vnet-peering.sh
./create-cross-tenant-vnet-peering.sh
```

---

**You're now ready to run the cross-tenant VNet peering script!**
