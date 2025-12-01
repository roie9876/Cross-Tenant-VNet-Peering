# ARM/Bicep Templates

This directory contains Azure Resource Manager (ARM) and Bicep templates for deploying cross-tenant VNet peering.

## 📁 Files

### Templates

| File | Description |
|------|-------------|
| `deploy-vnet-peering.bicep` | Bicep template (source) - human-readable IaC |
| `deploy-vnet-peering.json` | ARM template (compiled) - for Azure deployment |
| `vnet-peer-role.json` | Custom RBAC role definition |

### Configuration

| File | Description |
|------|-------------|
| `deploy-vnet-peering.parameters.json` | Example parameters file |
| `createUiDefinition.json` | Azure Portal UI definition for custom deployment experience |

## 🚀 Quick Start

### Option 1: Azure Portal (Easiest)

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Create a resource** → **Template deployment**
3. Click **Build your own template in the editor**
4. Copy/paste contents of `deploy-vnet-peering.json`
5. Fill in parameters
6. Deploy

### Option 2: Azure CLI

```bash
# Login and set context
az login --tenant {TENANT_ID}
az account set --subscription {SUBSCRIPTION_ID}

# Validate the deployment
az deployment group validate \
  --resource-group {RESOURCE_GROUP} \
  --template-file deploy-vnet-peering.bicep \
  --parameters deploy-vnet-peering.parameters.json

# Deploy
az deployment group create \
  --resource-group {RESOURCE_GROUP} \
  --template-file deploy-vnet-peering.bicep \
  --parameters deploy-vnet-peering.parameters.json \
  --name vnet-peering-deployment
```

### Option 3: Deploy to Azure Button

For ISV scenarios, host these files on GitHub and use:

```markdown
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/YOUR_RAW_JSON_URL)
```

## 📋 Parameters

Required parameters in `deploy-vnet-peering.parameters.json`:

```json
{
  "localVnetName": {
    "value": "vnet-tenant-a"
  },
  "remoteVnetResourceId": {
    "value": "/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.Network/virtualNetworks/{vnet-name}"
  },
  "peeringName": {
    "value": "peer-tenantA-to-tenantB"
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
```

## ✅ Built-in Validation

Azure automatically validates:

- ✅ **Address space overlap** - Deployment fails if VNets overlap
- ✅ **Permissions** - Checks for `peer/action` permission
- ✅ **Resource existence** - Verifies local VNet exists
- ✅ **Parameter format** - Validates resource ID format
- ✅ **Gateway transit logic** - Ensures mutual exclusivity

### Preview Changes (What-If)

```bash
az deployment group what-if \
  --resource-group {RESOURCE_GROUP} \
  --template-file deploy-vnet-peering.bicep \
  --parameters deploy-vnet-peering.parameters.json
```

This shows **exactly what will change** without deploying!

## 🔧 Customization

### Modify Bicep Template

1. Edit `deploy-vnet-peering.bicep`
2. Rebuild ARM template:
   ```bash
   az bicep build --file deploy-vnet-peering.bicep --outfile deploy-vnet-peering.json
   ```

### Create Custom UI

Edit `createUiDefinition.json` to customize the Azure Portal deployment experience:
- Add validation rules
- Modify form layout
- Add help text
- Change default values

Test your UI:
```bash
# Test in sandbox
az portal create-ui-definition show \
  --file createUiDefinition.json
```

## 📦 RBAC Role Setup

Before deploying, create the custom RBAC role in both tenants:

```bash
# Login to tenant
az login --tenant {TENANT_ID}
az account set --subscription {SUBSCRIPTION_ID}

# Edit vnet-peer-role.json and update assignableScopes
# Then create the role
az role definition create --role-definition vnet-peer-role.json

# Assign to user/service principal
az role assignment create \
  --assignee {USER_EMAIL_OR_OBJECT_ID} \
  --role "vnet-peer" \
  --scope "/subscriptions/{SUB_ID}/resourceGroups/{RG}"
```

## 🎯 ISV Deployment Pattern

For connecting customers to your ISV product:

### Step 1: You Deploy (ISV Side)
```bash
# Your production environment
az deployment group create \
  --resource-group rg-isv-product \
  --template-file deploy-vnet-peering.bicep \
  --parameters localVnetName="vnet-isv" \
               remoteVnetResourceId="/subscriptions/CUSTOMER-SUB/.../vnet-customer" \
               peeringName="peer-isv-to-customer-acme"
```

### Step 2: Customer Deploys (Their Side)

Provide them with:
1. **Pre-filled parameters file** with your VNet resource ID
2. **Deploy to Azure button** (easiest)
3. **Portal deployment instructions**

```json
{
  "localVnetName": {
    "value": "CUSTOMER_FILLS_THIS"
  },
  "remoteVnetResourceId": {
    "value": "/subscriptions/YOUR-ISV-SUB/resourceGroups/rg-isv/providers/Microsoft.Network/virtualNetworks/vnet-isv-product"
  },
  "peeringName": {
    "value": "peer-to-isv-product"
  }
}
```

## 🔍 Verification

After deployment, verify peering status:

```bash
az network vnet peering show \
  --resource-group {RESOURCE_GROUP} \
  --vnet-name {VNET_NAME} \
  --name {PEERING_NAME} \
  --query '{State:peeringState, SyncLevel:peeringSyncLevel}'
```

**Expected:**
```json
{
  "State": "Connected",
  "SyncLevel": "FullyInSync"
}
```

## 📚 Additional Documentation

- **Complete Deployment Guide:** [../docs/DEPLOYMENT.md](../docs/DEPLOYMENT.md)
- **Prerequisites:** [../docs/PREREQUISITES.md](../docs/PREREQUISITES.md)
- **Examples & Scenarios:** [../docs/EXAMPLES.md](../docs/EXAMPLES.md)
- **Troubleshooting:** [../docs/Cross-Tenant-VNet-Peering-Guide.md](../docs/Cross-Tenant-VNet-Peering-Guide.md#troubleshooting)

## 🔐 Security

- Always use parameters files (never hardcode values)
- Validate deployments before applying
- Use what-if to preview changes
- Add sensitive parameter files to `.gitignore`
- Review [../SECURITY.md](../SECURITY.md) for best practices

## 🤝 Contributing

When modifying templates:
- Update both Bicep and ARM versions
- Test with `az deployment group validate`
- Update parameter examples
- Document new parameters
- Update `createUiDefinition.json` if needed

See [../CONTRIBUTING.md](../CONTRIBUTING.md) for more details.
