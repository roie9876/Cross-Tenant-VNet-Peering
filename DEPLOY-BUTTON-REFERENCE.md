# Quick Reference: Deploy to Azure Button

## 🔗 The Button

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Froie9876%2FCross-Tenant-VNet-Peering%2Fmain%2Ftemplates%2Fdeploy-vnet-peering.json)

## 📋 Copy-Paste for Emails

**Markdown (for GitHub/docs):**
```markdown
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Froie9876%2FCross-Tenant-VNet-Peering%2Fmain%2Ftemplates%2Fdeploy-vnet-peering.json)
```

**Plain URL (for emails):**
```
https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Froie9876%2FCross-Tenant-VNet-Peering%2Fmain%2Ftemplates%2Fdeploy-vnet-peering.json
```

**HTML (for websites):**
```html
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Froie9876%2FCross-Tenant-VNet-Peering%2Fmain%2Ftemplates%2Fdeploy-vnet-peering.json">
  <img src="https://aka.ms/deploytoazurebutton" alt="Deploy to Azure"/>
</a>
```

## ✅ What It Does

- Opens Azure Portal **in customer's tenant** (not yours!)
- Customer authenticates with **their credentials** (not yours!)
- Customer deploys **in their subscription** (not yours!)
- Creates peering **in customer's VNet** only
- **No access to your environment** - completely safe

## 📧 Email Template

```
Hi [Customer],

To establish VNet peering with our service:

1. Click this link: [PASTE URL ABOVE]
2. Login to YOUR Azure Portal (your account)
3. Fill in:
   - Your VNet Name
   - Your Resource Group
   - Our VNet Resource ID: [YOUR-ISV-VNET-RESOURCE-ID]
4. Click Deploy

That's it! Let us know when done.
```

## 🔒 Security

**Customer concerns:**
- ❌ Does NOT give ISV access to customer's Azure
- ❌ Does NOT deploy anything in ISV environment
- ❌ Does NOT use ISV credentials
- ✅ Customer controls the entire deployment
- ✅ Customer can review template before deploying
- ✅ Customer can delete peering anytime

## 📝 Customer Checklist

Before clicking:
- [ ] Custom RBAC role `vnet-peer` assigned
- [ ] Know your VNet name
- [ ] Know your Resource Group
- [ ] Have ISV's VNet Resource ID
- [ ] Verified no address space overlap

## 🎯 Next Steps

1. **Push to GitHub** (make repo public)
2. **Test the button** - click it yourself to see customer experience
3. **Share with customers** - use email template
4. **Complete your side** - deploy peering after customer notifies you

---

**Full Documentation:** [docs/ISV-CUSTOMER-GUIDE.md](ISV-CUSTOMER-GUIDE.md)
