# Getting Started with IntuneInsanity

This guide will walk you through setting up and using IntuneInsanity to clone Intune policies between tenants.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Azure AD App Registration Setup](#azure-ad-app-registration-setup)
3. [Module Installation](#module-installation)
4. [Basic Usage](#basic-usage)
5. [Common Scenarios](#common-scenarios)

## Prerequisites

Before using IntuneInsanity, ensure you have:

1. **PowerShell 5.1 or later** installed on your system
2. **Administrative access** to both source and target Azure AD tenants
3. **Appropriate permissions** to create app registrations and manage Intune policies
4. **Internet connectivity** to access Microsoft Graph API

## Azure AD App Registration Setup

You need to create an Azure AD app registration in both your source and target tenants.

### Step-by-Step Instructions

#### For Each Tenant (Source and Target):

1. **Navigate to Azure Portal**
   - Go to https://portal.azure.com
   - Sign in with an account that has Global Administrator or Application Administrator rights

2. **Create App Registration**
   - Navigate to: **Azure Active Directory** → **App registrations**
   - Click **+ New registration**
   - Enter a name: `IntuneInsanity-Migration`
   - For "Supported account types", select **Accounts in this organizational directory only**
   - Click **Register**

3. **Note the Application Details**
   - After registration, you'll see the **Overview** page
   - Copy and save the following:
     - **Application (client) ID**
     - **Directory (tenant) ID**

4. **Create a Client Secret**
   - In the app registration, navigate to **Certificates & secrets**
   - Click **+ New client secret**
   - Add a description: `IntuneInsanity Secret`
   - Choose an expiration period (recommended: 12-24 months)
   - Click **Add**
   - **IMPORTANT**: Copy the secret **Value** immediately - you won't be able to see it again!

5. **Configure API Permissions**
   - Navigate to **API permissions**
   - Click **+ Add a permission**
   - Select **Microsoft Graph**
   - Select **Application permissions** (not Delegated)
   - Search for and add the following permissions:
     - `DeviceManagementConfiguration.ReadWrite.All`
     - `DeviceManagementApps.ReadWrite.All`
     - `DeviceManagementManagedDevices.ReadWrite.All`
   - Click **Add permissions**

6. **Grant Admin Consent**
   - Still in the **API permissions** section
   - Click **Grant admin consent for [Your Organization]**
   - Click **Yes** to confirm
   - Verify that all permissions show a green checkmark under "Status"

### Security Best Practices

- Use separate app registrations for source (read) and target (write) tenants
- Consider using Azure Key Vault to store client secrets
- Set appropriate secret expiration dates and rotate regularly
- Use Azure AD Conditional Access policies to restrict app access
- Monitor app sign-in logs in Azure AD

## Module Installation

### Option 1: Clone from GitHub

```powershell
# Clone the repository
git clone https://github.com/donnietaylor/IntuneInsanity.git

# Navigate to the module directory
cd IntuneInsanity

# Import the module
Import-Module .\IntuneInsanity.psd1
```

### Option 2: Manual Download

1. Download the repository as a ZIP file
2. Extract to a directory (e.g., `C:\Modules\IntuneInsanity`)
3. Import the module:

```powershell
Import-Module C:\Modules\IntuneInsanity\IntuneInsanity.psd1
```

### Verify Installation

```powershell
# Check if module is loaded
Get-Module IntuneInsanity

# List available commands
Get-Command -Module IntuneInsanity
```

## Basic Usage

### 1. Set Up Credentials

For security, store your credentials in variables:

```powershell
# Source Tenant
$sourceTenantId = "your-source-tenant-id"
$sourceClientId = "your-source-client-id"
$sourceSecret = "your-source-secret"

# Target Tenant
$targetTenantId = "your-target-tenant-id"
$targetClientId = "your-target-client-id"
$targetSecret = "your-target-secret"
```

### 2. Connect to Tenants

```powershell
# Connect to source tenant
Connect-IntuneInsanity -TenantId $sourceTenantId `
                        -ClientId $sourceClientId `
                        -ClientSecret $sourceSecret `
                        -TenantType Source

# Connect to target tenant
Connect-IntuneInsanity -TenantId $targetTenantId `
                        -ClientId $targetClientId `
                        -ClientSecret $targetSecret `
                        -TenantType Target
```

### 3. List Available Policies

```powershell
# Get all policies from source
$policies = Get-IntunePolicy -PolicyType All -TenantType Source

# Display policy information
$policies | Select-Object displayName, id, PolicyType | Format-Table

# Filter for specific policy types
$configPolicies = $policies | Where-Object { $_.PolicyType -eq 'DeviceConfiguration' }
```

### 4. Clone a Single Policy

```powershell
# Get the policy ID (from previous step)
$policyId = $policies[0].id

# Clone the policy
Copy-IntunePolicy -PolicyId $policyId `
                  -PolicyType DeviceConfiguration `
                  -NewPolicyName "Cloned Policy - Test"
```

### 5. Disconnect When Done

```powershell
Disconnect-IntuneInsanity -TenantType All
```

## Common Scenarios

### Scenario 1: Test Migration (Single Policy)

Perfect for testing before bulk migration:

```powershell
# Import module
Import-Module .\IntuneInsanity.psd1

# Connect to both tenants
Connect-IntuneInsanity -TenantId $sourceTenantId -ClientId $sourceClientId -ClientSecret $sourceSecret -TenantType Source
Connect-IntuneInsanity -TenantId $targetTenantId -ClientId $targetClientId -ClientSecret $targetSecret -TenantType Target

# Get one policy for testing
$testPolicy = Get-IntunePolicy -PolicyType DeviceConfiguration -TenantType Source | Select-Object -First 1

# Clone it
Copy-IntunePolicy -PolicyId $testPolicy.id -PolicyType $testPolicy.PolicyType

# Verify in target tenant
$verifyPolicy = Get-IntunePolicy -PolicyType DeviceConfiguration -TenantType Target | Where-Object { $_.displayName -like "*Cloned*" }
$verifyPolicy | Format-List

# Disconnect
Disconnect-IntuneInsanity -TenantType All
```

### Scenario 2: Bulk Migration

Migrate all configuration policies at once:

```powershell
# Import module
Import-Module .\IntuneInsanity.psd1

# Connect to both tenants
Connect-IntuneInsanity -TenantId $sourceTenantId -ClientId $sourceClientId -ClientSecret $sourceSecret -TenantType Source
Connect-IntuneInsanity -TenantId $targetTenantId -ClientId $targetClientId -ClientSecret $targetSecret -TenantType Target

# Get all device configuration policies
$policies = Get-IntunePolicy -PolicyType DeviceConfiguration -TenantType Source

# Clone each policy
foreach ($policy in $policies) {
    Write-Host "Cloning: $($policy.displayName)"
    Copy-IntunePolicy -PolicyId $policy.id -PolicyType $policy.PolicyType
    Start-Sleep -Seconds 2  # Rate limiting
}

# Disconnect
Disconnect-IntuneInsanity -TenantType All
```

### Scenario 3: Backup Before Migration

Always create a backup before major changes:

```powershell
# Import module
Import-Module .\IntuneInsanity.psd1

# Connect to source tenant
Connect-IntuneInsanity -TenantId $sourceTenantId -ClientId $sourceClientId -ClientSecret $sourceSecret -TenantType Source

# Create timestamped backup
$backupPath = "C:\IntuneBackup\$(Get-Date -Format 'yyyy-MM-dd_HHmmss')"
Export-IntunePolicy -PolicyType All -OutputPath $backupPath -TenantType Source

Write-Host "Backup completed to: $backupPath"

# Disconnect
Disconnect-IntuneInsanity -TenantType Source
```

## Troubleshooting

### Common Issues

**Issue**: "Failed to obtain access token"
- **Solution**: Verify Tenant ID, Client ID, and Client Secret are correct
- **Solution**: Ensure API permissions are granted and admin consent is provided
- **Solution**: Check if the client secret has expired

**Issue**: "Not connected to tenant"
- **Solution**: Run `Connect-IntuneInsanity` before other commands
- **Solution**: Verify you connected to the correct tenant type (Source/Target)

**Issue**: Policy creation fails
- **Solution**: Some policy types may have tenant-specific settings
- **Solution**: Review the error message for specific property issues
- **Solution**: Try exporting the policy to JSON and manually adjusting before import

**Issue**: Rate limiting errors
- **Solution**: Add `Start-Sleep -Seconds 2` between operations
- **Solution**: Process policies in smaller batches

## Next Steps

- Review the [Examples](./Examples/) directory for more scenarios
- Check the main [README.md](./README.md) for complete command reference
- Test in a non-production environment first
- Set up monitoring and logging for production migrations

## Support

For issues, questions, or contributions:
- GitHub Issues: https://github.com/donnietaylor/IntuneInsanity/issues
- Documentation: https://github.com/donnietaylor/IntuneInsanity

## Additional Resources

- [Microsoft Graph API Documentation](https://docs.microsoft.com/en-us/graph/api/resources/intune-graph-overview)
- [Azure AD App Registration Guide](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)
- [Intune Configuration Policies](https://docs.microsoft.com/en-us/mem/intune/configuration/)
