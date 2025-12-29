# Cross-Tenant VNet Peering Automation (Azure CLI)

This repository automates cross-tenant VNet peering using Azure CLI and least-privilege RBAC. The focus is CLI-only: no portal/ARM/Bicep workflow.

## What This Repo Does

- Creates bidirectional VNet peering across two Azure tenants.
- Uses a custom `vnet-peer` role scoped to resource groups.
- Supports both a user-based flow and an SPN-first flow.
- The user-based script validates address space overlap and peering status.

## High-Level Flow (SPN-First)

**Actors**
- ISV Admin: Owner/Contributor + User Access Administrator + App Admin in ISV tenant
- Customer Admin: Owner/Contributor + User Access Administrator + App Admin in customer tenant
- ISV SPN: service principal created by ISV Admin
- Customer SPN: service principal created by Customer Admin

**Steps**
1) ISV Admin runs `scripts/isv-setup.sh` to create RG/VNet (optional), custom role, ISV SPN + secret.
2) Customer Admin runs `scripts/customer-setup.sh` to create RG/VNet (optional), custom role, Customer SPN + secret.
3) Each admin re-runs their setup script with the other side’s App ID to register the external SPN and assign roles.
4) ISV runs `scripts/isv-peering.sh` using the ISV SPN to create peerings to customer VNets.
5) Customer runs `scripts/customer-peering.sh` using the Customer SPN to create peerings to ISV VNets.

## Shared Configuration (No Re-typing)

All scripts load values from:
- `scripts/isv.env.sh` for ISV-side scripts
- `scripts/customer.env.sh` for customer-side scripts

Fill those files once and reuse across all steps.
These files are gitignored to keep secrets out of source control.

Example (ISV side):
```bash
ISV_TENANT_ID="..."
ISV_SUBSCRIPTION_ID="..."
ISV_RESOURCE_GROUP="rg-isv-hub"
ISV_VNET_NAME="vnet-isv-hub"
CUSTOMER_SUBSCRIPTION_ID="..."
CUSTOMER_RESOURCE_GROUP="rg-customer-spoke"
CUSTOMER_VNETS="vnet-customer-spoke"
```

## Deployment Options (CLI Only)

### Option 1: User-Based Script (Interactive)
Use `scripts/create-cross-tenant-vnet-peering.sh` if you want a single script that logs into both tenants with a user account and creates peerings.
The user must have `vnet-peer` role (or equivalent) in each tenant’s RG; Owner/Contributor is not required unless creating roles or resources outside peering.

### Option 2: SPN-First Automation (Recommended for CI/CD)
Use the SPN-first scripts if you want automation with service principals:
- `scripts/isv-setup.sh` (ISV app/SPN + role + optional RG/VNet)
- `scripts/customer-setup.sh` (Customer app/SPN + role + optional RG/VNet, supports multiple RG scopes)
- `scripts/isv-register-customer-spn.sh` (Register customer SPN in ISV tenant, assign role)
- `scripts/customer-register-isv-spn.sh` (Register ISV SPN in customer tenant, assign role)
- `scripts/isv-peering.sh` (ISV creates peering to customer VNets)
- `scripts/customer-peering.sh` (Customer creates peering to ISV VNets)
- `scripts/isv-cleanup.sh` (ISV cleanup of roles, SPN, and optional RG/VNet)
- `scripts/customer-cleanup.sh` (Customer cleanup of roles, SPN, and optional RG/VNet)
- `scripts/isv-peering-delete.sh` (Delete ISV-side peerings)
- `scripts/customer-peering-delete.sh` (Delete customer-side peerings)

## Quick Start (SPN-First)

1) ISV admin runs:
- Fill `scripts/isv.env.sh` (leave `ISV_APP_ID` and `ISV_APP_SECRET` empty)
- Run `scripts/isv-setup.sh` to create the ISV app/SPN
- Copy the output values and paste them into `scripts/isv.env.sh`

2) Customer admin runs:
- Fill `scripts/customer.env.sh` (leave `CUSTOMER_APP_ID` and `CUSTOMER_APP_SECRET` empty)
- Run `scripts/customer-setup.sh` to create the customer app/SPN
- Copy the output values and paste them into `scripts/customer.env.sh`

3) Cross-tenant registration:
- Run `scripts/isv-register-customer-spn.sh` as **ISV tenant admin** (Owner/Contributor + User Access Administrator + App Admin) in the **ISV tenant**.
- Run `scripts/customer-register-isv-spn.sh` as **customer tenant admin** (Owner/Contributor + User Access Administrator + App Admin) in the **customer tenant**.

4) Create peerings:
- Run `scripts/isv-peering.sh`
- Run `scripts/customer-peering.sh`

Example multi-VNet input format for peering scripts (simple):
```
CUSTOMER_VNETS="vnet-cust-1,vnet-cust-2"
ISV_VNETS="vnet-isv-hub"
```
Advanced format (when VNets are in different RGs or subscriptions):
```
CUSTOMER_VNETS="sub-b-1111:rg-cust-1/vnet-cust-1,sub-b-2222:rg-cust-2/vnet-cust-2"
ISV_VNETS="sub-a-1111:rg-isv-hub/vnet-isv-hub"
```

## Prerequisites

- Azure CLI installed
- Two tenants with active subscriptions
- VNets already exist (or let the setup scripts create them)
- Non-overlapping address spaces
- Admin permissions in each tenant to create app registrations, SPNs, and role assignments

See `docs/PREREQUISITES.md` for details.

## Repository Structure

```
Cross-Tenant-VNet-Peering/
├── docs/                           # Documentation
│   ├── Cross-Tenant-VNet-Peering-Guide.md    # Complete manual implementation guide
│   ├── PREREQUISITES.md            # Setup requirements and preparation
│   └── EXAMPLES.md                 # Usage scenarios and examples
├── scripts/                        # Automation scripts (CLI only)
│   ├── create-cross-tenant-vnet-peering.sh   # User-based flow (interactive)
│   ├── isv.env.sh                  # ISV config (local, not committed)
│   ├── customer.env.sh             # Customer config (local, not committed)
│   ├── isv-setup.sh                # ISV setup (SPN-first)
│   ├── customer-setup.sh           # Customer setup (SPN-first)
│   ├── isv-register-customer-spn.sh # ISV registration-only
│   ├── customer-register-isv-spn.sh # Customer registration-only
│   ├── isv-peering.sh              # ISV peering (SPN-first)
│   ├── customer-peering.sh         # Customer peering (SPN-first)
│   └── config-template.sh          # Optional config template
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
├── README.md
└── SECURITY.md
```

## Verification

Check peering status after deployment:

```bash
# ISV
az network vnet peering list --resource-group <RG_A> --vnet-name <VNET_A> -o table

# Customer
az network vnet peering list --resource-group <RG_B> --vnet-name <VNET_B> -o table
```

Expected:
- `PeeringState` = `Connected`
- `SyncLevel` = `FullyInSync`

## Support

- `docs/PREREQUISITES.md`
- `docs/Cross-Tenant-VNet-Peering-Guide.md`
- `docs/EXAMPLES.md`

## License

MIT
