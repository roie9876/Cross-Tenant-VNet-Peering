# Automation Scripts

This directory contains bash scripts for automating cross-tenant VNet peering.

## Files

### `create-cross-tenant-vnet-peering.sh`
Main automation script that creates VNet peering between two Azure tenants.

**Features:**
- Interactive authentication to both tenants
- Automatic VNet information gathering
- Address space overlap validation
- Colored output and progress indicators
- Peering status verification

**Usage:**
```bash
# 1. Configure the script with your values (edit the CONFIGURATION section)
vi create-cross-tenant-vnet-peering.sh

# 2. Make it executable
chmod +x create-cross-tenant-vnet-peering.sh

# 3. Run the script
./create-cross-tenant-vnet-peering.sh
```

### `config-template.sh`
Template for externalizing configuration values.

**Usage:**
```bash
# 1. Copy to a private config file
cp config-template.sh config-private.sh

# 2. Edit with your actual values
vi config-private.sh

# 3. Source in your scripts (add to .gitignore!)
source config-private.sh
```

**Note:** `config-private.sh` is in `.gitignore` to prevent committing sensitive data.

## Prerequisites

Before running these scripts:

1. **Install required tools:**
   - Azure CLI (`az`)
   - `jq` (optional but recommended)

2. **Set up RBAC roles:**
   - Create custom `vnet-peer` role in both tenants
   - Assign role to your user account

3. **Prepare your environment:**
   - Ensure both VNets exist
   - Verify non-overlapping address spaces
   - Have tenant IDs and subscription IDs ready

For detailed prerequisites, see: [../docs/PREREQUISITES.md](../docs/PREREQUISITES.md)

## Configuration

Edit the **CONFIGURATION SECTION** in `create-cross-tenant-vnet-peering.sh`:

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

## Script Flow

The script performs these steps:

1. **Pre-flight Checks**
   - Validates Azure CLI installation
   - Checks configuration completeness
   - Verifies required tools

2. **Tenant A - Gather Information**
   - Authenticates to Tenant A
   - Retrieves VNet details
   - Captures VNet resource ID and address space

3. **Tenant B - Gather Information**
   - Authenticates to Tenant B
   - Retrieves VNet details
   - Captures VNet resource ID and address space

4. **Validate Address Spaces**
   - Checks for potential overlaps
   - Prompts for confirmation if overlap detected

5. **Display Summary**
   - Shows complete configuration
   - Requests user confirmation

6. **Create Peering - Tenant A to B**
   - Authenticates to Tenant A
   - Creates peering connection
   - Displays initial status

7. **Create Peering - Tenant B to A**
   - Authenticates to Tenant B
   - Creates peering connection
   - Displays initial status

8. **Verify Peering Status**
   - Waits for synchronization
   - Checks status in both tenants
   - Displays final results

## Output Example

```
[INFO] Starting Cross-Tenant VNet Peering Script...
[SUCCESS] Azure CLI is installed
[INFO] Validating configuration...
[SUCCESS] Configuration validated

==========================================
STEP 1: Gathering VNet information from Tenant A
==========================================

[INFO] Logging into Tenant A...
[SUCCESS] Logged into Tenant A
[INFO] Retrieving VNet information from Tenant A...
[SUCCESS] Tenant A VNet ID: /subscriptions/.../virtualNetworks/vnet-a
[SUCCESS] Tenant A Address Space: 192.168.0.0/16

...

[SUCCESS] ==========================================
[SUCCESS] Cross-Tenant VNet Peering Setup Complete!
[SUCCESS] ==========================================
```

## Troubleshooting

### Script Fails: "Azure CLI is not installed"
**Solution:** Install Azure CLI:
```bash
# macOS
brew install azure-cli

# Linux
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### Script Fails: "Configuration is incomplete"
**Solution:** Ensure all required variables are set in the script.

### Authentication Issues
**Solution:** The script uses device code authentication. Complete the browser flow when prompted.

### "User not authorized"
**Solution:** Verify you have the `vnet-peer` custom RBAC role in both tenants:
```bash
az role assignment list --assignee YOUR_EMAIL --all
```

## Security Notes

- Never commit `config-private.sh` to git
- Don't share scripts with hardcoded credentials
- Use the config template approach for team sharing
- Review the script before running in production

## Alternative: ARM/Bicep Templates

For a GUI-based deployment suitable for customers, see [../templates/](../templates/) and [../docs/DEPLOYMENT.md](../docs/DEPLOYMENT.md).

ARM/Bicep templates provide:
- No CLI knowledge required
- Built-in Azure validation
- Better for ISV/customer scenarios
- Deploy to Azure button support

## Support

For issues or questions:
- Review [../docs/Cross-Tenant-VNet-Peering-Guide.md](../docs/Cross-Tenant-VNet-Peering-Guide.md)
- Check [../docs/PREREQUISITES.md](../docs/PREREQUISITES.md)
- Open a GitHub issue
