# Deployment Methods Comparison

## Side-by-Side Comparison

| Feature | 🔘 ARM/Bicep Templates | ⚙️ Bash Script |
|---------|----------------------|---------------|
| **User Interface** | Azure Portal (GUI) | Command Line (CLI) |
| **Customer-Friendly** | ✅ Yes - One-click button | ❌ Requires technical knowledge |
| **Azure CLI Required** | ❌ No | ✅ Yes |
| **Setup Complexity** | ⭐ Easy | ⭐⭐ Medium |
| **Deployment Speed** | Fast (GUI clicks) | Fast (automated) |
| **Both Sides at Once** | ❌ No - each tenant deploys separately | ✅ Yes - single script deploys both |
| **What-If Preview** | ✅ Yes (built-in) | ⚠️ Manual validation |
| **Audit Trail** | ✅ Deployment history in Portal | ⚠️ Command output only |
| **CI/CD Integration** | ✅ Possible (ARM deployment tasks) | ✅ Easy (bash script) |
| **Validation** | ✅ Automatic (Azure validates) | ✅ Pre-flight checks in script |
| **ISV Use Case** | ⭐⭐⭐ Perfect - customers love it | ⭐ Possible but less friendly |
| **DevOps Use Case** | ⭐⭐ Good | ⭐⭐⭐ Perfect - full automation |
| **Documentation** | [DEPLOYMENT.md](docs/DEPLOYMENT.md) | [scripts/README.md](scripts/README.md) |

## Workflow Comparison

### Method 1: ARM/Bicep Templates (Customer-Centric)

```
ISV                                    Customer
│                                      │
├─ 1. Share Deploy to Azure button ──►├─ 2. Click button
│                                      │
│                                      ├─ 3. Azure Portal opens
│                                      │    (customer authenticated)
│                                      │
│                                      ├─ 4. Fill parameters
│                                      │    - Their VNet
│                                      │    - Their RG
│                                      │    - ISV VNet ID (provided)
│                                      │
│                                      ├─ 5. Click Deploy
│                                      │
│◄── 6. Customer notifies ISV ────────┤
│                                      │
├─ 7. ISV deploys their side          │
│    (using template or script)        │
│                                      │
├─ 8. Both sides Connected ✅ ────────┤
```

### Method 2: Bash Script (DevOps-Centric)

```
DevOps Engineer
│
├─ 1. Edit configuration file
│    - Tenant A details
│    - Tenant B details
│    - Peering options
│
├─ 2. Run script
│    ./create-cross-tenant-vnet-peering.sh
│
├─ 3. Script authenticates to Tenant A
│    (interactive login)
│
├─ 4. Script gathers Tenant A VNet info
│
├─ 5. Script authenticates to Tenant B
│    (interactive login)
│
├─ 6. Script gathers Tenant B VNet info
│
├─ 7. Script validates address spaces
│
├─ 8. Script shows summary
│    (awaits confirmation)
│
├─ 9. Script creates peering in Tenant A
│
├─ 10. Script creates peering in Tenant B
│
├─ 11. Script verifies status
│
└─ 12. Done! Both sides Connected ✅
```

## When to Use Each Method

### ✅ Use ARM/Bicep Templates (Method 1) for:

1. **ISV → Customer Scenarios**
   - You're a SaaS provider connecting customer VNets
   - Customers are non-technical business users
   - Need professional, documented process
   - Customers want approval workflows

2. **Enterprise Deployments**
   - Multiple approvers required
   - Compliance and audit requirements
   - Change management processes
   - Portal-based deployments preferred

3. **One-Side-At-A-Time Deployments**
   - Different people manage each tenant
   - Deployments happen at different times
   - Clear separation of responsibilities

**Example:** ISV "Contoso Analytics" connecting to customer "Fabrikam Corp"
- Contoso shares Deploy button with Fabrikam
- Fabrikam IT clicks button, deploys their side
- Contoso deploys their side separately
- Clean, professional process

### ✅ Use Bash Script (Method 2) for:

1. **DevOps Automation**
   - You control both tenants
   - Part of larger automation
   - CI/CD pipeline integration
   - Terraform/Ansible workflows

2. **Batch Operations**
   - Connecting multiple VNets
   - Standardized deployments
   - Repeatable processes
   - Script-driven workflows

3. **Internal IT Operations**
   - Same organization, different tenants
   - Technical team comfortable with CLI
   - Want full automation
   - Need to integrate with other scripts

**Example:** Enterprise "Contoso Corp" connecting subsidiaries
- DevOps team controls both Tenant A and Tenant B
- Run single script to connect all VNets
- Automated, fast, repeatable

## Hybrid Approach (Best of Both Worlds)

Many organizations use **both methods**:

```
ISV Side (You)                         Customer Side (Them)
│                                      │
│ Use Bash Script ⚙️                  │ Use Deploy Button 🔘
│ - Fast automation                    │ - Easy GUI
│ - Your DevOps team                   │ - Business users
│ - Consistent process                 │ - No CLI needed
│                                      │
└──────── Both Connected ✅ ───────────┘
```

**Why this works:**
- ✅ You (ISV) have technical team → use automation
- ✅ Customer has business users → use GUI button
- ✅ Professional experience for customers
- ✅ Fast, automated for your team

## Real-World Examples

### Example 1: ISV SaaS Product
**Scenario:** Analytics platform connecting to customer data sources

**Solution:** ARM/Bicep Templates (Method 1)
- Send Deploy to Azure button to customers
- Customer clicks, deploys in 2 minutes
- Professional onboarding experience
- No support burden from CLI issues

### Example 2: Enterprise Multi-Region Setup
**Scenario:** Large enterprise connecting 10 regional VNets to hub

**Solution:** Bash Script (Method 2)
- Single configuration file with all VNets
- Run script once, all connections created
- Automated, consistent, fast
- Easy to update/modify

### Example 3: Managed Service Provider
**Scenario:** MSP connecting customer VNets to centralized services

**Solution:** Both Methods (Hybrid)
- **Customer deploys their side:** Deploy button (easy for them)
- **MSP deploys their side:** Bash script (automated for MSP)
- Best experience for both parties

## Technical Differences

### Authentication

**ARM/Bicep Templates:**
- Customer authenticates via Azure Portal
- Azure AD interactive login
- MFA supported natively
- Browser-based

**Bash Script:**
- Uses `az login` for each tenant
- Interactive or device code flow
- MFA supported via Azure CLI
- Terminal-based

### Validation

**ARM/Bicep Templates:**
- Azure validates template syntax
- Azure checks parameters
- Azure validates permissions
- Azure checks address overlap
- Built-in what-if preview

**Bash Script:**
- Pre-flight checks (CLI installed, logged in)
- Address space overlap detection
- Configuration validation
- Manual confirmation prompt
- Post-deployment verification

### Error Handling

**ARM/Bicep Templates:**
- Detailed Azure error messages
- Deployment fails safely (nothing created)
- Retry easily via Portal
- Full error logs in Activity Log

**Bash Script:**
- Detailed error messages with colors
- Fails at any step (safe rollback)
- Clear instructions for fixes
- Output saved to terminal

## Migration Path

### Starting with Bash Script → Moving to Templates

1. **Phase 1:** Use bash script for proof-of-concept
2. **Phase 2:** Convert to Bicep once proven
3. **Phase 3:** Add Deploy to Azure button
4. **Phase 4:** Transition customers to button

**Why?** Start fast with script, then provide professional experience.

### Starting with Templates → Adding Script

1. **Phase 1:** Use templates for customer deployments
2. **Phase 2:** Create bash script for your internal side
3. **Phase 3:** Automate your ISV environment
4. **Phase 4:** Keep template for customers

**Why?** Professional customer experience from day one, automate your side later.

## Summary

| Choose | If You Need |
|--------|-------------|
| **🔘 ARM/Bicep Templates** | Professional, customer-friendly, GUI-based deployment |
| **⚙️ Bash Script** | Fast automation, DevOps integration, full control |
| **Both (Hybrid)** | Customer-friendly GUI + ISV automation |

**Bottom Line:**
- ISVs → Start with Templates (Method 1)
- DevOps → Start with Script (Method 2)
- Enterprise → Use both where appropriate

---

**Need Help Choosing?**
- Review [docs/PREREQUISITES.md](docs/PREREQUISITES.md) for requirements
- See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for template details
- See [scripts/README.md](scripts/README.md) for script details
