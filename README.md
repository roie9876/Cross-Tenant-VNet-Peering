# Cross-Tenant VNet Peering Automation (Azure CLI)

This repository automates cross-tenant VNet peering using Azure CLI and least-privilege RBAC. The focus is CLI-only: no portal/ARM/Bicep workflow.

## What This Repo Does

- Creates bidirectional VNet peering across two Azure tenants.
- Uses a custom `vnet-peer` role scoped to resource groups.
- Supports a single-SPN automation flow (ISV-owned SPN).
- The user-based script validates address space overlap and peering status.

## Quick Visual Flow (SPN Automation)

```
ISV Tenant                            Customer Tenant
-----------                           ----------------
1) isv-setup.sh
   - creates ISV SPN
   - assigns vnet-peer on ISV RG
   - writes ISV_APP_ID/SECRET
                  |
                  | 2) customer-setup.sh
                  |    - registers ISV SPN in customer tenant
                  |    - assigns vnet-peer on customer RG
                  v
3) isv-peering.sh  --> creates ISV-side peering
4) customer-peering.sh --> creates customer-side peering

Result: two peerings, status = Connected
```

**Actors**
- ISV Admin: Owner/Contributor + User Access Administrator + App Admin in ISV tenant
- Customer Admin: Owner/Contributor + User Access Administrator + App Admin in customer tenant
- ISV SPN: service principal created by ISV Admin (multi-tenant)

**Steps**
1) ISV Admin runs `scripts/isv-setup.sh` to create RG/VNet (optional), custom role, ISV SPN + secret.
2) Customer Admin runs `scripts/customer-setup.sh` to create RG/VNet (optional), custom role, and register the ISV SPN in the customer tenant.
3) ISV runs `scripts/isv-peering.sh` and `scripts/customer-peering.sh` using the ISV SPN.

## Shared Configuration (No Re-typing)

All scripts load values from:
- `scripts/isv.env.sh` for ISV-side scripts
- `scripts/customer.env.sh` for customer-side scripts

Fill those files once and reuse across all steps.
These files are gitignored to keep secrets out of source control.
If both env files live in the same repo, the setup scripts auto-write the App IDs to the other file so you can avoid copy/paste.

### Template: `scripts/isv.env.sh`
```bash
#!/bin/bash
# ISV environment configuration (keep secrets out of git).

# Tenant/subscription
ISV_TENANT_ID="..."
ISV_SUBSCRIPTION_ID="..."
ISV_LOCATION="eastus"

# RG/VNet options
CREATE_NEW_RG_VNET="true"
ISV_RESOURCE_GROUP="rg-isv-hub"
ISV_VNET_NAME="vnet-isv-hub"
ISV_VNET_ADDRESS_SPACE="10.0.0.0/16"
ISV_SUBNET_NAME="default"
ISV_SUBNET_PREFIX="10.0.1.0/24"

# SPN creation
ISV_APP_DISPLAY_NAME="isv-vnet-peering-spn"

# After setup, filled automatically
ISV_APP_ID=""
ISV_APP_SECRET=""

# Customer VNets to peer with (use numbered entries)
CUSTOMER_TENANT_ID="..."
CUSTOMER_SUBSCRIPTION_ID="..."
CUSTOMER_RESOURCE_GROUP="rg-customer-spoke"
CUSTOMER_VNET_NAME_1="vnet-customer-spoke-1"
CUSTOMER_VNET_NAME_2="vnet-customer-spoke-2"
CUSTOMER_VNET_NAME_3=""
```

### Template: `scripts/customer.env.sh`
```bash
#!/bin/bash
# Customer environment configuration (keep secrets out of git).

# Tenant/subscription
CUSTOMER_TENANT_ID="..."
CUSTOMER_SUBSCRIPTION_ID="..."
CUSTOMER_LOCATION="eastus"

# RG/VNet options
CREATE_NEW_RG_VNET="true"
CUSTOMER_RESOURCE_GROUP="rg-customer-spoke"

# VNet 1
CUSTOMER_VNET_NAME_1="vnet-customer-spoke-1"
CUSTOMER_VNET_ADDRESS_SPACE_1="10.100.0.0/16"
CUSTOMER_SUBNET_NAME_1="default"
CUSTOMER_SUBNET_PREFIX_1="10.100.1.0/24"

# VNet 2 (optional)
CUSTOMER_VNET_NAME_2="vnet-customer-spoke-2"
CUSTOMER_VNET_ADDRESS_SPACE_2="10.200.0.0/16"
CUSTOMER_SUBNET_NAME_2="default"
CUSTOMER_SUBNET_PREFIX_2="10.200.1.0/24"

# VNet 3 (optional)
CUSTOMER_VNET_NAME_3=""
CUSTOMER_VNET_ADDRESS_SPACE_3=""
CUSTOMER_SUBNET_NAME_3=""
CUSTOMER_SUBNET_PREFIX_3=""

# ISV app registration (auto-set if both env files are in the same repo)
ISV_APP_ID=""
ISV_APP_SECRET=""
ISV_TENANT_ID="..."

# ISV VNets to peer with (simple format: vnet1,vnet2)
ISV_SUBSCRIPTION_ID="..."
ISV_RESOURCE_GROUP="rg-isv-hub"
ISV_VNETS="vnet-isv-hub"

# Optional UDR for customer-to-customer traffic (via ISV LB)
CUSTOMER_UDR_ENABLE="false"
CUSTOMER_UDR_NEXT_HOP_IP=""

# Role assignment scopes (RG level), comma-separated list of RG names.
CUSTOMER_ROLE_SCOPES="rg-customer-spoke"
```

## Deployment Options (CLI Only)

### Option 1: ISV-Owned SPN Automation (No Customer Secret)
Use one ISV multi-tenant SPN to create both sides of the peering. The customer only grants admin consent and assigns the role.
- `scripts/isv-setup.sh` (ISV app/SPN + role + optional RG/VNet)
- `scripts/customer-setup.sh` (customer RG/VNet + role + registers ISV SPN)
- `scripts/isv-peering.sh` (ISV creates peering to customer VNets)
- `scripts/customer-peering.sh` (ISV creates customer-side peering using the ISV SPN)
- `scripts/isv-cleanup.sh` and `scripts/customer-cleanup.sh` (cleanup)

### Option 2: User-Based Script (Interactive)
Use `scripts/create-cross-tenant-vnet-peering.sh` if you want a single script that logs into both tenants with a user account and creates peerings.
The user must have `vnet-peer` role (or equivalent) in each tenant’s RG; Owner/Contributor is not required unless creating roles or resources outside peering.

## Quick Start (SPN Automation)

1) ISV admin runs:
- Fill `scripts/isv.env.sh` (leave `ISV_APP_ID` and `ISV_APP_SECRET` empty)
- Run `scripts/isv-setup.sh` to create the ISV app/SPN
- The script auto-updates `scripts/isv.env.sh` and, if present, `scripts/customer.env.sh` with `ISV_APP_ID`

2) Customer admin runs:
- Fill `scripts/customer.env.sh`
  - Add one or more `CUSTOMER_VNET_NAME_1`, `CUSTOMER_VNET_NAME_2`, etc. with address space/subnet values
  - Ensure `ISV_APP_ID` is present (auto-set if both env files are in the same repo)
- Run `scripts/customer-setup.sh` to create RG/VNets, the role, and register the ISV SPN

3) ISV admin runs:
- `scripts/isv-peering.sh`
- `scripts/customer-peering.sh` (uses the ISV SPN to create customer-side peering)

Example customer VNet inputs (numbered, in `scripts/customer.env.sh`):
```
CUSTOMER_VNET_NAME_1="vnet-cust-1"
CUSTOMER_VNET_ADDRESS_SPACE_1="10.100.0.0/16"
CUSTOMER_SUBNET_NAME_1="default"
CUSTOMER_SUBNET_PREFIX_1="10.100.1.0/24"

CUSTOMER_VNET_NAME_2="vnet-cust-2"
CUSTOMER_VNET_ADDRESS_SPACE_2="10.101.0.0/16"
CUSTOMER_SUBNET_NAME_2="default"
CUSTOMER_SUBNET_PREFIX_2="10.101.1.0/24"
```
Optional customer UDR (set in `scripts/customer.env.sh`).
When enabled, routes are created for OTHER customer VNets listed by `CUSTOMER_VNET_NAME_*`
(no default 0.0.0.0/0).
```
CUSTOMER_UDR_ENABLE="true"
CUSTOMER_UDR_NEXT_HOP_IP="10.0.1.4"
CUSTOMER_VNET_NAME_1="vnet-a"
CUSTOMER_VNET_NAME_2="vnet-b"
CUSTOMER_VNET_NAME_3="vnet-c"
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
│   ├── isv.env.sh                  # ISV config (local, not committed)
│   ├── customer.env.sh             # Customer config (local, not committed)
│   ├── isv-setup.sh                # ISV setup (SPN-first)
│   ├── customer-setup.sh           # Customer setup (SPN-first)
│   ├── isv-register-customer-spn.sh # Legacy (not used in ISV-only flow)
│   ├── customer-register-isv-spn.sh # Legacy (not used in ISV-only flow)
│   ├── isv-peering.sh              # ISV peering (SPN-first)
│   ├── customer-peering.sh         # Customer peering (SPN-first)
│   ├── isv-peering-delete.sh       # Delete ISV-side peerings
│   ├── customer-peering-delete.sh  # Delete customer-side peerings
│   ├── isv-cleanup.sh              # ISV cleanup (roles/SPN/RG)
│   ├── customer-cleanup.sh         # Customer cleanup (roles/SPN/RG)
│   ├── create-cross-tenant-vnet-peering.sh   # User-based flow (interactive)
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
