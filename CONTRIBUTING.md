# Contributing to Cross-Tenant VNet Peering

Thank you for your interest in contributing to this project! We welcome contributions from the community.

## How to Contribute

### Reporting Issues

If you find a bug or have a suggestion for improvement:

1. Check if the issue already exists in the [Issues](../../issues) section
2. If not, create a new issue with:
   - A clear, descriptive title
   - Detailed description of the problem or suggestion
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Your environment (Azure CLI version, OS, etc.)

### Submitting Changes

1. **Fork the Repository**
   ```bash
   git clone https://github.com/YOUR-USERNAME/cross-tenant-vnet-peering.git
   cd cross-tenant-vnet-peering
   ```

2. **Create a Branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/issue-description
   ```

3. **Make Your Changes**
   - Follow the existing code style
   - Test your changes thoroughly
   - Update documentation as needed
   - Ensure scripts work on macOS, Linux, and Windows (WSL)

4. **Test Your Changes**
   - Verify scripts execute without errors
   - Test with real Azure environments if possible
   - Validate all placeholders are properly documented

5. **Commit Your Changes**
   ```bash
   git add .
   git commit -m "Brief description of your changes"
   ```

6. **Push to Your Fork**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Create a Pull Request**
   - Go to the original repository
   - Click "New Pull Request"
   - Select your fork and branch
   - Provide a clear description of your changes
   - Reference any related issues

## Code Guidelines

### Shell Scripts
- Use bash for shell scripts
- Include error handling (`set -e`)
- Add comments for complex logic
- Use meaningful variable names
- Test on multiple shells (bash, zsh)

### Documentation
- Use clear, concise language
- Include examples where applicable
- Keep placeholders consistent (e.g., `{TENANT_A_ID}`)
- Update table of contents when adding sections
- Verify markdown rendering

### Security
- **Never commit sensitive information:**
  - Subscription IDs
  - Tenant IDs
  - Resource names from real environments
  - User emails or object IDs
  - Passwords or secrets
- Always use placeholders in examples
- Review changes before committing

## What We're Looking For

We welcome contributions in these areas:

- **Bug fixes** - Fix issues in existing scripts or documentation
- **Feature enhancements** - Add new functionality (e.g., PowerShell version)
- **Documentation improvements** - Clarify existing docs or add new examples
- **Testing** - Add test cases or validation scripts
- **Platform support** - Improve Windows/PowerShell compatibility
- **Error handling** - Better error messages and validation

## Questions?

If you have questions about contributing:

1. Check the [README.md](README.md) and [PREREQUISITES.md](PREREQUISITES.md)
2. Review existing issues and pull requests
3. Create a new issue with the "question" label

## Code of Conduct

This project follows a simple code of conduct:

- **Be respectful** - Treat everyone with respect
- **Be constructive** - Provide helpful feedback
- **Be collaborative** - Work together to improve the project
- **Be patient** - Remember this is a community effort

Thank you for contributing! 🎉
