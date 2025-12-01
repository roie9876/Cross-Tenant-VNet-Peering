# ARM/Bicep Template Deployment Guide

This guide shows how to deploy cross-tenant VNet peering using ARM/Bicep templates instead of bash scripts.

## 📋 Overview

**Why use templates instead of scripts?**
- ✅ **GUI-based deployment** in Azure Portal (no CLI needed)
- ✅ **Built-in validation** - Azure checks everything before deploying
- ✅ **What-if preview** - see changes before applying
- ✅ **Professional** - better for enterprise customers
- ✅ **Audit trail** - deployment history in Azure
- ✅ **Repeatable** - can be versioned and automated

## 🚀 Quick Start

### Option 1: Deploy to Azure Button (Easiest for ISV/Customer Scenarios)

**Click the button below to deploy in YOUR environment:**

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Froie9876%2FCross-Tenant-VNet-Peering%2Fmain%2Ftemplates%2Fdeploy-vnet-peering.json)

**How it works:**
1. **Customer clicks the button** → Opens Azure Portal **in their tenant/subscription**
2. **Customer authenticates** → Logs into **their own Azure account**
3. **Customer fills parameters** → Specifies their VNet and your ISV VNet resource ID
4. **Customer deploys** → Creates peering **in their environment only**

**Important:** 
- ✅ Customer deploys in **their tenant** - not yours
- ✅ Customer needs the **full resource ID** of your ISV VNet (you provide this)
- ✅ No personal email addresses involved
- ✅ You must deploy the other side of the peering separately in your ISV tenant

### Option 2: Azure CLI Deployment

```bash
# Login to your tenant
az login --tenant {TENANT_ID}
az account set --subscription {SUBSCRIPTION_ID}

# Validate the deployment (dry-run)
az deployment group validate \
  --resource-group {RESOURCE_GROUP} \
  --template-file deploy-vnet-peering.bicep \
  --parameters deploy-vnet-peering.parameters.json

# Preview changes (what-if)
az deployment group what-if \
  --resource-group {RESOURCE_GROUP} \
  --template-file deploy-vnet-peering.bicep \
  --parameters deploy-vnet-peering.parameters.json

# Deploy the peering
az deployment group create \
  --resource-group {RESOURCE_GROUP} \
  --template-file deploy-vnet-peering.bicep \
  --parameters deploy-vnet-peering.parameters.json \
  --name "vnet-peering-deployment-$(date +%Y%m%d-%H%M%S)"
```

### Option 3: Azure Portal Deployment

1. Go to **Azure Portal** → **Create a resource**
2. Search for **"Template deployment (deploy using custom template)"**
3. Click **"Build your own template in the editor"**
4. Paste the contents of `deploy-vnet-peering.json`
5. Click **Save**
6. Fill in the parameters
7. Click **Review + Create**

## 🔧 Configuration

### Required Parameters

Edit `deploy-vnet-peering.parameters.json`:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "localVnetName": {
      "value": "YOUR-LOCAL-VNET-NAME"
    },
    "remoteVnetResourceId": {
      "value": "/subscriptions/{REMOTE-SUB-ID}/resourceGroups/{REMOTE-RG}/providers/Microsoft.Network/virtualNetworks/{REMOTE-VNET-NAME}"
    },
    "peeringName": {
      "value": "peer-local-to-remote"
    },
    "allowVnetAccess": {
      "value": true
    },
    "allowForwardedTraffic": {
      "value": false
    },
    "allowGatewayTransit": {
      "value": false
    },
    "useRemoteGateways": {
      "value": false
    }
  }
}
```

### Parameter Descriptions

| Parameter | Required | Description | Example |
|-----------|----------|-------------|---------|
| `localVnetName` | Yes | Name of the VNet in this tenant | `vnet-prod-eastus` |
| `remoteVnetResourceId` | Yes | Full resource ID of remote VNet | `/subscriptions/.../virtualNetworks/vnet-remote` |
| `peeringName` | Yes | Name for this peering connection | `peer-prod-to-partner` |
| `allowVnetAccess` | No | Allow basic connectivity | `true` (default) |
| `allowForwardedTraffic` | No | Allow NVA forwarded traffic | `false` (default) |
| `allowGatewayTransit` | No | This VNet has a gateway | `false` (default) |
| `useRemoteGateways` | No | Use remote VNet's gateway | `false` (default) |

## ❓ Common Questions

### Q: Why do customers need a custom RBAC role?
**A:** The custom `vnet-peer` role provides **least-privilege access**. Without it, customers would need:
- ❌ Owner role (full control of resource group)
- ❌ Contributor role (can create/delete all resources)
- ✅ With custom role: Only peering permissions (secure!)

### Q: Can the Bicep template create the role automatically?
**A:** No, because:
- Role creation requires **subscription-level permissions**
- Peering deployment is **resource group-level**
- Separating concerns: Admin creates role once, users deploy peering many times
- Security: Role creation should be controlled by admins

### Q: Do customers need admin privileges to deploy?
**A:** No! That's the point:
- ❌ Customer does NOT need Owner/Contributor
- ✅ Customer only needs `vnet-peer` custom role (minimal permissions)
- ✅ Regular users can deploy once role is assigned

### Q: Does clicking the button deploy both sides?
**A:** No, cross-tenant peering requires **two separate deployments**:
1. **Customer deploys their side** (using Deploy to Azure button)
2. **ISV deploys their side** (using template, script, or Portal)
3. Both must exist for peering to be "Connected"

This is an **Azure platform requirement**, not a limitation of this solution.

---

## 🏢 ISV Deployment Workflow

### Typical ISV → Customer Flow

**Step 0: One-Time Setup (Customer's Azure Admin)**
```bash
# Admin creates custom role (ONCE per subscription)
az role definition create --role-definition vnet-peer-role.json

# Admin assigns role to user(s) who will deploy peering
az role assignment create \
  --assignee deployer@customer.com \
  --role "vnet-peer" \
  --scope "/subscriptions/{SUB}/resourceGroups/{RG}"

# Now regular users can deploy without admin privileges!
```

**Step 1: ISV (You) provides information to customer**
```
Subject: VNet Peering Setup for [Your Product]

To connect to our service, please deploy this peering in your Azure environment:

1. Click: [Deploy to Azure Button]
2. Fill in these parameters:
   - Your VNet name: [customer fills this]
   - Your Resource Group: [customer fills this]
   - Our VNet Resource ID: /subscriptions/YOUR-SUB-ID/resourceGroups/YOUR-RG/providers/Microsoft.Network/virtualNetworks/YOUR-VNET
   - Peering Name: peer-to-isv-product (or customer chooses)

3. Click "Review + Create"

Once deployed, notify us and we'll complete our side of the connection.
```

**Step 2: Customer clicks button**
- Opens Azure Portal authenticated as **the customer**
- In **customer's tenant/subscription**
- Pre-filled template, customer just adds their details

**Step 3: Customer deploys**
- Creates peering in **customer's VNet** pointing to **your ISV VNet**
- Peering state: "Initiated" (waiting for your side)

**Step 4: ISV (You) completes your side**
```bash
az login --tenant YOUR-ISV-TENANT-ID
az account set --subscription YOUR-ISV-SUBSCRIPTION-ID

az deployment group create \
  --resource-group YOUR-ISV-RG \
  --template-file templates/deploy-vnet-peering.bicep \
  --parameters localVnetName=YOUR-VNET-NAME \
               remoteVnetResourceId="/subscriptions/CUSTOMER-SUB/resourceGroups/CUSTOMER-RG/providers/Microsoft.Network/virtualNetworks/CUSTOMER-VNET" \
               peeringName=peer-to-customer-xyz
```

**Step 5: Both sides show "Connected"**
- Customer peering: Connected ✅
- ISV peering: Connected ✅
- Traffic can flow!

## ✅ Validation Features

### Automatic Validation

Azure performs these checks **before deployment**:

1. **Permissions Check**
   - Verifies you have `Microsoft.Network/virtualNetworks/peer/action` permission
   - Checks if custom RBAC role `vnet-peer` is assigned

2. **Resource Existence**
   - Validates local VNet exists
   - Checks remote VNet resource ID format

3. **Address Space Overlap Detection**
   - **Azure automatically checks** if address spaces overlap
   - Deployment **fails** if overlapping ranges detected

4. **Gateway Transit Validation**
   - Ensures `allowGatewayTransit` and `useRemoteGateways` are not both true
   - Validates gateway exists if `useRemoteGateways` is true

### Manual Validation Commands

#### Check for Address Space Overlap

```bash
# Get local VNet address space
LOCAL_ADDR=$(az network vnet show \
  --name {LOCAL_VNET} \
  --resource-group {LOCAL_RG} \
  --query 'addressSpace.addressPrefixes[0]' -o tsv)

echo "Local VNet: $LOCAL_ADDR"

# You'll need to check remote VNet manually or ask customer
echo "Remote VNet: {CUSTOMER_PROVIDES_THIS}"

# Compare manually:
# Local: 192.168.0.0/16  Remote: 10.0.0.0/16  ✅ OK
# Local: 10.0.0.0/16     Remote: 10.1.0.0/16  ❌ OVERLAP
```

#### Use What-If Deployment

**What-if shows you exactly what will change** without actually deploying:

```bash
az deployment group what-if \
  --resource-group {RESOURCE_GROUP} \
  --template-file deploy-vnet-peering.bicep \
  --parameters deploy-vnet-peering.parameters.json
```

**Example Output:**
```
Resource changes: 1 to create

  + Microsoft.Network/virtualNetworks/virtualNetworkPeerings/peer-a-to-b
    
    Properties:
      allowVirtualNetworkAccess: true
      allowForwardedTraffic: false
      remoteVirtualNetwork.id: "/subscriptions/.../virtualNetworks/vnet-remote"
      peeringState: "Initiated" (will become "Connected" when both sides exist)
```

#### Validate Deployment

**Validate checks if deployment would succeed** without actually deploying:

```bash
az deployment group validate \
  --resource-group {RESOURCE_GROUP} \
  --template-file deploy-vnet-peering.bicep \
  --parameters deploy-vnet-peering.parameters.json
```

**Success:**
```json
{
  "properties": {
    "provisioningState": "Succeeded"
  }
}
```

**Failure (example - address overlap):**
```json
{
  "error": {
    "code": "AddressSpaceOverlap",
    "message": "Virtual network address space overlaps with remote virtual network"
  }
}
```

## 📝 ISV Deployment Workflow

### For ISV (Your Side - Tenant A)

1. **Get customer's VNet information:**
   ```bash
   # Ask customer to provide:
   # - Remote VNet Resource ID
   # - Remote VNet Address Space (for your validation)
   ```

2. **Update parameters file:**
   ```json
   {
     "localVnetName": {
       "value": "vnet-isv-product"
     },
     "remoteVnetResourceId": {
       "value": "/subscriptions/CUSTOMER-SUB-ID/resourceGroups/customer-rg/providers/Microsoft.Network/virtualNetworks/customer-vnet"
     },
     "peeringName": {
       "value": "peer-isv-to-customer-{CUSTOMER_NAME}"
     }
   }
   ```

3. **Validate first:**
   ```bash
   az deployment group validate \
     --resource-group rg-isv-product \
     --template-file deploy-vnet-peering.bicep \
     --parameters deploy-vnet-peering.parameters.json
   ```

4. **Deploy:**
   ```bash
   az deployment group create \
     --resource-group rg-isv-product \
     --template-file deploy-vnet-peering.bicep \
     --parameters deploy-vnet-peering.parameters.json
   ```

### For Customer (Tenant B)

**Option A: Give them a custom Deploy to Azure button**

Create a URL with pre-filled parameters:

```
https://portal.azure.com/#create/Microsoft.Template/uri/YOUR-TEMPLATE-URL/createUIDefinitionUri/YOUR-UI-DEFINITION-URL
```

**Option B: Provide them a parameter file**

Give customer a pre-filled `customer-deploy.parameters.json`:

```json
{
  "localVnetName": {
    "value": "CUSTOMER-FILLS-THIS"
  },
  "remoteVnetResourceId": {
    "value": "/subscriptions/YOUR-ISV-SUB/resourceGroups/rg-isv/providers/Microsoft.Network/virtualNetworks/vnet-isv-product"
  },
  "peeringName": {
    "value": "peer-to-isv-product"
  },
  "allowVnetAccess": {
    "value": true
  }
}
```

Customer runs:
```bash
az deployment group create \
  --resource-group {THEIR_RG} \
  --template-file deploy-vnet-peering.bicep \
  --parameters customer-deploy.parameters.json
```

## 🔍 Verification

### Check Deployment Status

```bash
# List recent deployments
az deployment group list \
  --resource-group {RESOURCE_GROUP} \
  --query '[].{Name:name, State:properties.provisioningState, Timestamp:properties.timestamp}' \
  --output table

# Get specific deployment details
az deployment group show \
  --resource-group {RESOURCE_GROUP} \
  --name {DEPLOYMENT_NAME} \
  --query 'properties.outputs'
```

### Verify Peering Status

```bash
# Check peering state
az network vnet peering show \
  --resource-group {RESOURCE_GROUP} \
  --vnet-name {VNET_NAME} \
  --name {PEERING_NAME} \
  --query '{State:peeringState, SyncLevel:peeringSyncLevel, ProvisioningState:provisioningState}'
```

**Expected Output (after both sides deployed):**
```json
{
  "State": "Connected",
  "SyncLevel": "FullyInSync",
  "ProvisioningState": "Succeeded"
}
```

## 🛠️ Troubleshooting

### Deployment Fails: "Address space overlaps"

**Error:**
```
Code: AddressSpaceOverlap
Message: Virtual network address space overlaps with remote virtual network
```

**Solution:**
1. Check local VNet address space:
   ```bash
   az network vnet show --name {VNET} --resource-group {RG} --query 'addressSpace.addressPrefixes'
   ```
2. Get remote VNet address space from customer
3. Ensure they're non-overlapping (different IP ranges)

### Deployment Fails: "Insufficient permissions"

**Error:**
```
Code: AuthorizationFailed
Message: The client does not have authorization to perform action 'Microsoft.Network/virtualNetworks/peer/action'
```

**Solution:**
Ensure you have the `vnet-peer` custom RBAC role assigned:
```bash
az role assignment create \
  --assignee {YOUR_USER_OR_SPN} \
  --role "vnet-peer" \
  --scope "/subscriptions/{SUB_ID}/resourceGroups/{RG}"
```

### Peering State Shows "Initiated"

**Symptom:** Peering state is "Initiated" instead of "Connected"

**Cause:** Only one side of the peering has been created

**Solution:** Deploy the template in the **other tenant** as well. Both sides need to create their peering.

### Remote VNet Not Found

**Error:**
```
Code: RemoteVnetNotFound
Message: Remote virtual network resource not found
```

**Cause:** 
- Remote VNet resource ID is incorrect
- Remote VNet doesn't exist

**Solution:**
1. Verify remote VNet exists
2. Double-check resource ID format:
   ```
   /subscriptions/{sub-id}/resourceGroups/{rg-name}/providers/Microsoft.Network/virtualNetworks/{vnet-name}
   ```

## 📊 Cost Considerations

### What-If Cost Estimate

```bash
# Preview changes and potential costs
az deployment group what-if \
  --resource-group {RESOURCE_GROUP} \
  --template-file deploy-vnet-peering.bicep \
  --parameters deploy-vnet-peering.parameters.json
```

**Note:** VNet peering charges apply based on data transfer:
- Intra-region: ~$0.01 per GB
- Inter-region (global): ~$0.035 per GB

## 🔐 Security Best Practices

1. **Use Parameter Files**
   - Don't hardcode values in templates
   - Keep customer-specific parameters separate
   - Add parameter files to `.gitignore`

2. **Validate Before Deploying**
   - Always run `validate` command first
   - Use `what-if` to preview changes
   - Review outputs before confirming

3. **Use Managed Identity (if possible)**
   - For automated deployments, use Managed Identity
   - Avoid storing Service Principal credentials

4. **Audit Deployments**
   - Review deployment history regularly
   - Enable Azure Activity Logs
   - Set up alerts for deployment failures

## 📚 Additional Resources

- [Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [ARM Template Reference - VNet Peering](https://docs.microsoft.com/en-us/azure/templates/microsoft.network/virtualnetworks/virtualnetworkpeerings)
- [Deploy to Azure Button Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-to-azure-button)
- [What-If Deployment](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-what-if)

## 🎯 Next Steps

1. **Test the template** in your dev environment
2. **Create a Deploy to Azure button** for customers
3. **Document customer onboarding process**
4. **Set up monitoring** for peering connections
5. **Automate with Azure DevOps/GitHub Actions** (optional)
