# Documentation

This directory contains comprehensive documentation for cross-tenant VNet peering.

## 📚 Documentation Files

### Getting Started

| Document | Description | Audience |
|----------|-------------|----------|
| [PREREQUISITES.md](PREREQUISITES.md) | Setup requirements, tools, and preparation steps | Everyone |
| [Cross-Tenant-VNet-Peering-Guide.md](Cross-Tenant-VNet-Peering-Guide.md) | Complete manual implementation guide | Technical implementers |

### Deployment Methods

| Document | Description | Audience |
|----------|-------------|----------|
| [DEPLOYMENT.md](DEPLOYMENT.md) | ARM/Bicep template deployment guide | ISV, Enterprise, GUI users |
| [../scripts/README.md](../scripts/README.md) | Bash script automation guide | DevOps, CLI users |

### Reference

| Document | Description | Audience |
|----------|-------------|----------|
| [EXAMPLES.md](EXAMPLES.md) | Real-world scenarios and use cases | All users |

## 🎯 Reading Guide

### For First-Time Users

1. **Start here:** [PREREQUISITES.md](PREREQUISITES.md)
   - Understand what you need
   - Set up your environment
   - Create RBAC roles

2. **Choose your deployment method:**
   - **GUI users:** [DEPLOYMENT.md](DEPLOYMENT.md) - ARM/Bicep templates
   - **CLI users:** [../scripts/README.md](../scripts/README.md) - Bash scripts

3. **Review examples:** [EXAMPLES.md](EXAMPLES.md)
   - Find a scenario similar to yours
   - Learn from real-world configurations

4. **Deep dive (if needed):** [Cross-Tenant-VNet-Peering-Guide.md](Cross-Tenant-VNet-Peering-Guide.md)
   - Understand the concepts
   - Manual step-by-step implementation
   - Troubleshooting guide

### For ISV/SaaS Providers

1. **Understand the problem:** [Cross-Tenant-VNet-Peering-Guide.md](Cross-Tenant-VNet-Peering-Guide.md)
2. **Set up templates:** [DEPLOYMENT.md](DEPLOYMENT.md)
3. **Create Deploy to Azure button:** [DEPLOYMENT.md](DEPLOYMENT.md#deploy-to-azure-button)
4. **Review ISV patterns:** [EXAMPLES.md](EXAMPLES.md)

### For Enterprise Architects

1. **Architecture overview:** [Cross-Tenant-VNet-Peering-Guide.md](Cross-Tenant-VNet-Peering-Guide.md#architecture)
2. **Security considerations:** [Cross-Tenant-VNet-Peering-Guide.md](Cross-Tenant-VNet-Peering-Guide.md#security-best-practices)
3. **Use case scenarios:** [EXAMPLES.md](EXAMPLES.md)
4. **Hub-and-spoke patterns:** [EXAMPLES.md](EXAMPLES.md#scenario-2-hub-and-spoke-with-vpn-gateway)

### For DevOps Engineers

1. **Prerequisites:** [PREREQUISITES.md](PREREQUISITES.md)
2. **Automation scripts:** [../scripts/README.md](../scripts/README.md)
3. **CI/CD integration:** [DEPLOYMENT.md](DEPLOYMENT.md#automation)
4. **Troubleshooting:** [Cross-Tenant-VNet-Peering-Guide.md](Cross-Tenant-VNet-Peering-Guide.md#troubleshooting)

## 📖 Document Summaries

### PREREQUISITES.md
Everything you need before starting:
- Azure CLI installation
- Custom RBAC role setup
- User account vs Service Principal
- Pre-flight verification commands
- Common issues and solutions

**Read first!**

### Cross-Tenant-VNet-Peering-Guide.md
The complete manual guide covering:
- What is cross-tenant VNet peering
- Architecture diagrams
- Custom RBAC role definition
- Step-by-step manual implementation
- Verification procedures
- Troubleshooting
- Automation considerations
- Service Principal limitations

**Use when:** You want to understand everything or do manual setup

### DEPLOYMENT.md
ARM/Bicep template deployment:
- Deploy to Azure button setup
- Azure CLI deployment
- Azure Portal deployment
- Built-in validation features
- What-if previews
- ISV deployment workflow
- Parameter configuration
- Verification steps

**Use when:** You want GUI-based or production-ready deployments

### EXAMPLES.md
Real-world scenarios:
- Basic cross-tenant peering
- Hub-and-spoke with VPN gateway
- Multi-region peering
- Network Virtual Appliance (NVA) integration
- Testing connectivity
- Cost considerations
- Monitoring and alerts

**Use when:** You need practical examples or want to see different configurations

## 🔍 Quick Reference

### Finding Information

**How do I...?**

| Question | Document | Section |
|----------|----------|---------|
| Install Azure CLI | PREREQUISITES.md | Environment Prerequisites |
| Create custom RBAC role | PREREQUISITES.md | Custom RBAC Role Setup |
| Deploy with ARM template | DEPLOYMENT.md | Quick Start |
| Use bash script | ../scripts/README.md | Usage |
| Connect hub-and-spoke | EXAMPLES.md | Scenario 2 |
| Fix address overlap | Cross-Tenant-VNet-Peering-Guide.md | Troubleshooting |
| Use NVA with peering | EXAMPLES.md | Scenario 4 |
| Create Deploy button | DEPLOYMENT.md | Deploy to Azure Button |
| Validate before deploy | DEPLOYMENT.md | Validation Features |
| Test connectivity | EXAMPLES.md | Testing Connectivity |

### Common Tasks

**I want to:**

| Task | Document |
|------|----------|
| Set up my environment | [PREREQUISITES.md](PREREQUISITES.md) |
| Deploy for the first time | [DEPLOYMENT.md](DEPLOYMENT.md) or [../scripts/README.md](../scripts/README.md) |
| Automate deployments | [DEPLOYMENT.md](DEPLOYMENT.md) |
| Connect customers (ISV) | [DEPLOYMENT.md](DEPLOYMENT.md#isv-deployment-workflow) |
| Troubleshoot issues | [Cross-Tenant-VNet-Peering-Guide.md](Cross-Tenant-VNet-Peering-Guide.md#troubleshooting) |
| See examples | [EXAMPLES.md](EXAMPLES.md) |
| Understand concepts | [Cross-Tenant-VNet-Peering-Guide.md](Cross-Tenant-VNet-Peering-Guide.md) |

## 🆘 Getting Help

1. **Check documentation** in this directory
2. **Review troubleshooting** in Cross-Tenant-VNet-Peering-Guide.md
3. **Search existing issues** on GitHub
4. **Create a new issue** using the appropriate template

## 🤝 Contributing to Documentation

When updating documentation:

1. Keep it clear and concise
2. Use examples where appropriate
3. Update the table of contents
4. Test all commands and code samples
5. Use consistent formatting
6. Link between related documents
7. Keep sensitive information out (use placeholders)

See [../CONTRIBUTING.md](../CONTRIBUTING.md) for more details.

## 📋 Documentation Checklist

Before publishing changes:

- [ ] All code examples tested
- [ ] No sensitive information (IDs, names, emails)
- [ ] Links between documents work
- [ ] Table of contents updated
- [ ] Consistent terminology
- [ ] Spell-checked
- [ ] Images/diagrams optimized
- [ ] Markdown properly formatted

## 📞 Support

For questions or issues:
- 📖 Read the documentation
- 🔍 Search existing GitHub issues
- 💬 Create a new issue with the `question` label
- 🤝 Submit improvements via pull request
