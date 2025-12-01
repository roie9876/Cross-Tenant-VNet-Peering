# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-01

### Added
- Initial release of Cross-Tenant VNet Peering automation
- Main automation script (`create-cross-tenant-vnet-peering.sh`)
- Comprehensive prerequisites documentation (`PREREQUISITES.md`)
- Custom RBAC role definition (`vnet-peer-role.json`)
- Complete implementation guide (`Cross-Tenant-VNet-Peering-Guide.md`)
- Repository README with quick start guide
- MIT License
- Security policy and best practices
- Contributing guidelines
- .gitignore for sensitive information

### Features
- ✅ Automated bidirectional VNet peering creation
- ✅ Custom RBAC role with least-privilege permissions
- ✅ Address space validation and overlap detection
- ✅ Interactive device code authentication
- ✅ Colored output for better readability
- ✅ Pre-flight validation checks
- ✅ Automatic peering status verification
- ✅ Support for advanced peering options (gateway transit, forwarded traffic)
- ✅ Comprehensive error handling and user guidance

### Documentation
- Complete step-by-step implementation guide
- Prerequisites and preparation checklist
- Troubleshooting section with common issues
- Security best practices
- Custom RBAC role permission breakdown
- Architecture diagrams
- Service Principal limitations and workarounds

### Security
- Least-privilege custom RBAC role (no Owner/Contributor required)
- Resource group scoped permissions
- Sensitive information removed from all examples
- Security policy documentation
- Secure configuration practices

## [Unreleased]

### Planned Features
- PowerShell version of automation script
- Azure DevOps pipeline templates
- GitHub Actions workflow examples
- Terraform module for VNet peering
- Enhanced validation and testing
- Multi-region peering support
- Peering deletion script

---

## Release Notes

### v1.0.0 Release Notes

This initial release provides a complete, production-ready solution for automating cross-tenant VNet peering in Azure using custom RBAC roles.

**Key Highlights:**
- **Security First:** Uses least-privilege custom RBAC role instead of Owner/Contributor
- **Well Documented:** Comprehensive guides covering prerequisites, implementation, and troubleshooting
- **Production Ready:** Tested and validated in real Azure environments
- **User Friendly:** Interactive script with colored output and validation
- **Open Source:** MIT licensed, community contributions welcome

**What's Included:**
1. Automated bash script for peering creation
2. Custom RBAC role definition with minimal permissions
3. Complete prerequisites and setup guide
4. Detailed implementation guide with examples
5. Security policy and best practices
6. Contributing guidelines

**Important Notes:**
- Service Principals cannot create initial cross-tenant peering (Azure limitation)
- User accounts with guest access to both tenants are required
- VNets must have non-overlapping address spaces
- Custom RBAC role must be created in both tenants

**Getting Started:**
1. Review PREREQUISITES.md
2. Set up custom RBAC roles in both tenants
3. Configure the script with your values
4. Run the script and follow prompts

For questions or issues, please open a GitHub issue.

---

[1.0.0]: https://github.com/YOUR-USERNAME/cross-tenant-vnet-peering/releases/tag/v1.0.0
