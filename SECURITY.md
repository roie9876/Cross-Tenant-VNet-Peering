# Security Policy

## Reporting Security Issues

If you discover a security vulnerability in this project, please report it responsibly.

### Please DO NOT:
- Open a public GitHub issue
- Share the vulnerability publicly before it's been addressed

### Please DO:
1. Email the maintainers privately (create an issue requesting contact information)
2. Provide detailed information about the vulnerability:
   - Description of the issue
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

We will respond to security reports within 48 hours and work with you to address the issue.

## Security Best Practices

When using this repository:

### 1. Protect Sensitive Information

**Never commit:**
- Azure Subscription IDs
- Azure Tenant IDs
- Resource Group names from production environments
- VNet names from real deployments
- User emails or Object IDs
- Service Principal credentials
- Access keys or secrets
- Any production configuration values

### 2. Use Least Privilege

- Always use the custom `vnet-peer` role instead of Owner or Contributor
- Scope role assignments to resource groups, not subscriptions
- Regularly review and audit role assignments
- Remove role assignments when no longer needed

### 3. Credential Management

- Use Azure CLI device code authentication for interactive sessions
- Store Service Principal credentials in Azure Key Vault
- Never hardcode credentials in scripts
- Use environment variables or Azure Managed Identity when possible
- Rotate credentials regularly

### 4. Script Execution

- Review scripts before executing them
- Understand what each command does
- Run scripts in non-production environments first
- Use version control to track changes
- Validate all input parameters

### 5. Network Security

- Apply Network Security Groups (NSGs) to subnets
- Use Azure Firewall for centralized network security
- Implement User Defined Routes (UDRs) for traffic control
- Enable Azure DDoS Protection
- Monitor network traffic with Azure Network Watcher

### 6. Audit and Monitoring

- Enable Azure Activity Logs
- Monitor peering operations and changes
- Set up alerts for unauthorized changes
- Review access logs regularly
- Use Azure Security Center recommendations

## Secure Configuration

### Example: Secure Script Configuration

Instead of hardcoding values in scripts:

**❌ Bad:**
```bash
TENANT_A_ID="12345678-1234-1234-1234-123456789012"
SUBSCRIPTION_A="87654321-4321-4321-4321-210987654321"
```

**✅ Good:**
```bash
# Load from secure configuration file (not in git)
if [ -f "config-private.sh" ]; then
    source config-private.sh
else
    echo "Error: config-private.sh not found"
    echo "Copy config-template.sh to config-private.sh and fill in your values"
    exit 1
fi
```

### Example: Service Principal Credentials

**❌ Bad:**
```bash
az login --service-principal \
  --username "12345678-abcd-1234-abcd-123456789012" \
  --password "my-secret-password" \
  --tenant "tenant-id"
```

**✅ Good:**
```bash
# Use Azure Key Vault
SPN_PASSWORD=$(az keyvault secret show \
  --vault-name "my-keyvault" \
  --name "spn-password" \
  --query value -o tsv)

az login --service-principal \
  --username "$SPN_APP_ID" \
  --password "$SPN_PASSWORD" \
  --tenant "$TENANT_ID"
```

Or use Managed Identity:
```bash
# Azure VM with Managed Identity enabled
az login --identity
```

## Security Checklist

Before making your repository public or sharing scripts:

- [ ] Remove all real Subscription IDs
- [ ] Remove all real Tenant IDs
- [ ] Remove all real resource names
- [ ] Remove all user emails or object IDs
- [ ] Remove any Service Principal credentials
- [ ] Remove any connection strings or access keys
- [ ] Replace with generic placeholders (e.g., `{SUBSCRIPTION_ID}`)
- [ ] Verify .gitignore includes sensitive file patterns
- [ ] Review commit history for accidentally committed secrets
- [ ] Test scripts with placeholder values to ensure they prompt for input

## Compliance

This project helps implement Azure networking with security best practices:

- **Least Privilege Access** - Custom RBAC roles with minimal permissions
- **Separation of Duties** - Resource group scoped permissions
- **Audit Trail** - All operations logged in Azure Activity Logs
- **Zero Trust** - Network segmentation through VNet peering

Ensure your implementation complies with:
- Your organization's security policies
- Industry regulations (GDPR, HIPAA, SOC2, etc.)
- Azure security baseline recommendations
- Microsoft Cloud Security Benchmark

## Additional Resources

- [Azure Security Best Practices](https://docs.microsoft.com/en-us/azure/security/fundamentals/best-practices-and-patterns)
- [Azure RBAC Best Practices](https://docs.microsoft.com/en-us/azure/role-based-access-control/best-practices)
- [Azure Network Security](https://docs.microsoft.com/en-us/azure/security/fundamentals/network-best-practices)
- [Secure DevOps for Azure](https://docs.microsoft.com/en-us/azure/devops/organizations/security/security-best-practices)

## Version History

- **v1.0** (December 2025) - Initial security policy

---

**Remember: Security is everyone's responsibility. When in doubt, ask for a security review.**
