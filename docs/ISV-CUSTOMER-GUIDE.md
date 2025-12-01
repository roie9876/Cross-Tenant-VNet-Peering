# ISV Customer Deployment Guide

Quick reference for ISVs to guide customers through VNet peering setup.

## 📧 Email Template for Customers

```
Subject: VNet Peering Setup for [Your Product/Service Name]

Hi [Customer Name],

To connect your Azure environment to our [Product/Service], we need to establish a VNet peering connection.

This is a simple one-click deployment that you'll do in YOUR Azure environment (nothing deploys in our side yet).

STEP 1: Click this button to deploy in your Azure Portal
👉 https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Froie9876%2FCross-Tenant-VNet-Peering%2Fmain%2Ftemplates%2Fdeploy-vnet-peering.json

STEP 2: Fill in the parameters when prompted:
- Subscription: [Select your Azure subscription]
- Resource Group: [Select the resource group containing your VNet]
- Region: [Should auto-populate from your resource group]
- Local Vnet Name: [Your VNet name - e.g., "vnet-prod-eastus"]
- Remote Vnet Resource Id: /subscriptions/YOUR-ISV-SUB-ID/resourceGroups/YOUR-ISV-RG/providers/Microsoft.Network/virtualNetworks/YOUR-ISV-VNET
- Peering Name: peer-to-[your-company-name] (or any name you prefer)
- Allow Vnet Access: true (leave default)
- Other options: false (leave defaults unless we discuss otherwise)

STEP 3: Click "Review + Create" then "Create"

STEP 4: Reply to this email once deployed so we can complete our side

PREREQUISITES:
Before deploying, please ensure you have:
- The custom "vnet-peer" RBAC role assigned to your account
  (See setup guide: https://github.com/roie9876/Cross-Tenant-VNet-Peering/blob/main/docs/PREREQUISITES.md#custom-rbac-role-setup)
- Your VNet address space does NOT overlap with ours: [YOUR-ISV-ADDRESS-SPACE, e.g., 192.168.0.0/16]

Questions? Reply to this email.

Thanks,
[Your Name]
[Your Company]
```

## 🔗 Direct Links to Share

### Deploy Button (Markdown)
```markdown
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Froie9876%2FCross-Tenant-VNet-Peering%2Fmain%2Ftemplates%2Fdeploy-vnet-peering.json)
```

### Deploy Button (HTML for websites)
```html
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Froie9876%2FCross-Tenant-VNet-Peering%2Fmain%2Ftemplates%2Fdeploy-vnet-peering.json" target="_blank">
  <img src="https://aka.ms/deploytoazurebutton" alt="Deploy to Azure"/>
</a>
```

### Direct URL (plain text for emails)
```
https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Froie9876%2FCross-Tenant-VNet-Peering%2Fmain%2Ftemplates%2Fdeploy-vnet-peering.json
```

## 📋 Information to Provide Customers

### Required Information

**Your ISV VNet Resource ID:**
```
/subscriptions/YOUR-SUB-ID/resourceGroups/YOUR-RG/providers/Microsoft.Network/virtualNetworks/YOUR-VNET-NAME
```

**Your VNet Address Space (for overlap check):**
```
Example: 192.168.0.0/16
```

**Custom Role Definition:**
Share the `templates/vnet-peer-role.json` file or link to prerequisites documentation.

## 🔄 Complete Workflow

### Phase 1: Customer Preparation (Before Button Click)
1. **Customer creates custom RBAC role** (if not already exists)
   - Use `templates/vnet-peer-role.json`
   - Scope to their resource group
2. **Customer assigns role to themselves**
3. **Customer verifies address spaces don't overlap**

### Phase 2: Customer Deployment (Button Click)
1. Customer clicks Deploy to Azure button
2. Azure Portal opens in **customer's tenant**
3. Customer authenticates with **their credentials**
4. Customer fills parameters:
   - Their VNet name
   - Their resource group
   - Your ISV VNet resource ID (you provide)
5. Customer clicks Deploy
6. Peering created in **customer's tenant**, state: "Initiated"

### Phase 3: ISV Completion (Your Side)
1. Customer notifies you deployment is complete
2. You gather customer VNet resource ID from them:
   ```
   /subscriptions/CUSTOMER-SUB-ID/resourceGroups/CUSTOMER-RG/providers/Microsoft.Network/virtualNetworks/CUSTOMER-VNET-NAME
   ```
3. You deploy your side:
   ```bash
   az login --tenant YOUR-TENANT-ID
   az account set --subscription YOUR-SUBSCRIPTION-ID
   
   az deployment group create \
     --resource-group YOUR-RG \
     --template-file templates/deploy-vnet-peering.bicep \
     --parameters \
       localVnetName=YOUR-VNET-NAME \
       remoteVnetResourceId="/subscriptions/CUSTOMER-SUB-ID/resourceGroups/CUSTOMER-RG/providers/Microsoft.Network/virtualNetworks/CUSTOMER-VNET-NAME" \
       peeringName="peer-to-customer-COMPANY-NAME"
   ```

### Phase 4: Verification
1. Both sides show "Connected" status
2. Customer can test connectivity (if VMs deployed)
3. Done! 🎉

## ❓ Common Customer Questions

### Q: "Will this give you access to our Azure environment?"
**A:** No. VNet peering only allows **network-level connectivity** between specific VNets. It does NOT grant:
- Access to your Azure portal
- Ability to view/modify your resources
- Control over your subscription

It only allows IP-level communication between VNets (like VPN, but simpler).

### Q: "Can you deploy this for us?"
**A:** No, you must deploy it in your tenant. Azure security requires that each tenant owner explicitly creates their side of the peering. This is a security feature, not a limitation.

However, it's just one click and takes 2 minutes!

### Q: "What if our address spaces overlap?"
**A:** The deployment will fail automatically. You'll need to either:
- Change your VNet address space (if possible), or
- Use a different VNet, or
- Use VPN Gateway with NAT instead of peering

Contact us to discuss options.

### Q: "Why do we need a custom RBAC role?"
**A:** For security. The custom `vnet-peer` role has **only** the permissions needed for peering - nothing more. This follows the principle of least privilege. Without it, you'd need Owner or Contributor role, which is excessive.

### Q: "What if we don't have permission to create custom roles?"
**A:** Contact your Azure administrator. They can:
1. Create the custom role once (IT admin task)
2. Assign it to you (or a service principal)

Show them the `templates/vnet-peer-role.json` file - it's read-only for most things, only write access for peering itself.

### Q: "Can we use a Service Principal instead of a user account?"
**A:** Yes! See [docs/PREREQUISITES.md](PREREQUISITES.md#service-principal-setup) for details. Note that SPNs can deploy the initial peering, but automation workflows may need the hybrid approach.

### Q: "What happens after we deploy?"
**A:** Your side of the peering will show as "Initiated" until we deploy our side. Once both sides are created, both will show "Connected" and traffic can flow.

## 🛠️ Troubleshooting for Customers

### Issue: "I don't see the Deploy to Azure button"
**Solution:** The button is a link. In email, click the blue "Deploy to Azure" button image or use the direct URL.

### Issue: "Deployment failed - LinkedAuthorizationFailed"
**Solution:** You don't have the `vnet-peer` custom role assigned. Contact your Azure admin to assign it to your account.

### Issue: "Deployment failed - Address space overlap"
**Solution:** Your VNet address space overlaps with ours. Contact us to discuss alternatives.

### Issue: "Peering stuck in 'Initiated' state"
**Solution:** This is normal! It means you successfully created your side. Contact us to complete our side (if you already notified us, just wait - we're working on it).

### Issue: "I don't know my VNet resource ID"
**Solution:** Run this command in Azure Cloud Shell:
```bash
az network vnet show \
  --resource-group YOUR-RESOURCE-GROUP \
  --name YOUR-VNET-NAME \
  --query id -o tsv
```

## 📊 Customer Self-Service Portal (Future Enhancement)

Consider building a simple web portal where customers can:
1. Input their VNet details
2. Get a custom Deploy to Azure link with pre-filled parameters
3. Track peering status
4. Self-service troubleshooting

This would eliminate email back-and-forth for VNet resource IDs.

## 🔒 Security Best Practices

### For ISVs
1. **Never ask customers for**:
   - Azure portal credentials
   - Subscription admin access
   - Ability to deploy in their tenant on their behalf

2. **Always provide**:
   - Clear documentation
   - Your VNet resource ID
   - Your address space (for overlap check)
   - Expected peering name (helps with audit trails)

3. **Monitor your side**:
   - Set up alerts when new peerings are created
   - Log all peering operations
   - Regular audits of connected customers

### For Customers
1. **Verify the template source**:
   - GitHub repo is public and auditable
   - Template is read-only (you can review it before deploying)

2. **Use least-privilege role**:
   - Never use Owner/Contributor for peering
   - Use the custom `vnet-peer` role

3. **Document the connection**:
   - Record which ISV you're peering with
   - Document the business purpose
   - Regular review of active peerings

## 📞 Support

**For Customers:**
If you have issues with deployment, contact the ISV who sent you here.

**For ISVs:**
Review the full documentation:
- [Prerequisites](PREREQUISITES.md)
- [Deployment Guide](DEPLOYMENT.md)
- [Troubleshooting](Cross-Tenant-VNet-Peering-Guide.md#troubleshooting)

---

**Last Updated:** December 1, 2025
