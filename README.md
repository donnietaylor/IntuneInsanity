# IntuneInsanity

A PowerShell module to clone Microsoft Intune policies from one tenant to another. This module simplifies the process of migrating, backing up, and replicating Intune device configurations, compliance policies, and app protection policies across different Azure AD tenants.

## Features

- **Tenant-to-Tenant Policy Migration**: Clone policies directly from source to target tenant
- **Policy Export/Import**: Backup policies to JSON files and restore them later
- **Multiple Policy Types Supported**:
  - Device Configuration Policies
  - Device Compliance Policies
  - App Protection Policies
- **Flexible Authentication**: Uses Azure AD App Registration with client credentials flow
- **Comprehensive Error Handling**: Detailed error messages and logging

## Prerequisites

1. **Azure AD App Registrations**: You need app registrations in both source and target tenants with the following Microsoft Graph API permissions:
   - `DeviceManagementConfiguration.ReadWrite.All`
   - `DeviceManagementApps.ReadWrite.All`
   - `DeviceManagementManagedDevices.ReadWrite.All`

2. **PowerShell 5.1 or later**

## Installation

### Manual Installation

1. Clone or download this repository
2. Import the module:

```powershell
Import-Module .\IntuneInsanity.psd1
```

## Quick Start

### 1. Connect to Source and Target Tenants

```powershell
# Connect to source tenant
Connect-IntuneInsanity -TenantId "source-tenant-id" `
                        -ClientId "source-app-id" `
                        -ClientSecret "source-secret" `
                        -TenantType Source

# Connect to target tenant
Connect-IntuneInsanity -TenantId "target-tenant-id" `
                        -ClientId "target-app-id" `
                        -ClientSecret "target-secret" `
                        -TenantType Target
```

### 2. List Policies from Source Tenant

```powershell
# Get all policies
$policies = Get-IntunePolicy -PolicyType All -TenantType Source

# Get only device configuration policies
$configPolicies = Get-IntunePolicy -PolicyType DeviceConfiguration -TenantType Source

# Display policy information
$policies | Select-Object displayName, id, PolicyType | Format-Table
```

### 3. Clone a Policy to Target Tenant

```powershell
# Copy a specific policy
Copy-IntunePolicy -PolicyId "policy-id-here" `
                  -PolicyType DeviceConfiguration `
                  -NewPolicyName "My Cloned Policy"
```

### 4. Export Policies for Backup

```powershell
# Export all policies to JSON files
Export-IntunePolicy -PolicyType All `
                    -OutputPath "C:\IntuneBackup" `
                    -TenantType Source
```

### 5. Import Policies from Backup

```powershell
# Import policies from JSON files
Import-IntunePolicy -InputPath "C:\IntuneBackup" `
                    -TenantType Target
```

## Usage Examples

### Example 1: Clone All Configuration Policies

```powershell
# Connect to both tenants
Connect-IntuneInsanity -TenantId $sourceTenantId -ClientId $sourceClientId -ClientSecret $sourceSecret -TenantType Source
Connect-IntuneInsanity -TenantId $targetTenantId -ClientId $targetClientId -ClientSecret $targetSecret -TenantType Target

# Get all device configuration policies
$policies = Get-IntunePolicy -PolicyType DeviceConfiguration -TenantType Source

# Clone each policy
foreach ($policy in $policies) {
    Write-Host "Cloning: $($policy.displayName)"
    Copy-IntunePolicy -PolicyId $policy.id -PolicyType DeviceConfiguration
}
```

### Example 2: Backup and Restore

```powershell
# Backup from source tenant
Connect-IntuneInsanity -TenantId $sourceTenantId -ClientId $sourceClientId -ClientSecret $sourceSecret -TenantType Source
Export-IntunePolicy -PolicyType All -OutputPath "C:\IntuneBackup" -TenantType Source

# Later: Restore to target tenant
Connect-IntuneInsanity -TenantId $targetTenantId -ClientId $targetClientId -ClientSecret $targetSecret -TenantType Target
Import-IntunePolicy -InputPath "C:\IntuneBackup" -TenantType Target
```

### Example 3: Selective Policy Migration

```powershell
# Connect to both tenants
Connect-IntuneInsanity -TenantId $sourceTenantId -ClientId $sourceClientId -ClientSecret $sourceSecret -TenantType Source
Connect-IntuneInsanity -TenantId $targetTenantId -ClientId $targetClientId -ClientSecret $targetSecret -TenantType Target

# Get all policies and filter
$policies = Get-IntunePolicy -PolicyType All -TenantType Source
$selectedPolicies = $policies | Where-Object { $_.displayName -like "*Windows*" }

# Clone selected policies
foreach ($policy in $selectedPolicies) {
    Copy-IntunePolicy -PolicyId $policy.id -PolicyType $policy.PolicyType
}
```

## Commands Reference

### Connect-IntuneInsanity
Establishes authentication to Microsoft Intune for source or target tenant.

**Parameters:**
- `TenantId` (Required): Azure AD Tenant ID
- `ClientId` (Required): Application (Client) ID
- `ClientSecret` (Required): Client Secret
- `TenantType` (Required): 'Source' or 'Target'

### Disconnect-IntuneInsanity
Clears stored authentication tokens.

**Parameters:**
- `TenantType` (Optional): 'Source', 'Target', or 'All' (default: All)

### Get-IntunePolicy
Retrieves policies from the connected tenant.

**Parameters:**
- `PolicyType` (Optional): 'DeviceConfiguration', 'DeviceCompliance', 'AppProtection', or 'All' (default: All)
- `TenantType` (Required): 'Source' or 'Target'
- `PolicyId` (Optional): Specific policy ID to retrieve

### Copy-IntunePolicy
Clones a policy from source to target tenant.

**Parameters:**
- `PolicyId` (Required): ID of the policy to copy
- `PolicyType` (Required): Type of policy
- `NewPolicyName` (Optional): New name for the cloned policy

### Export-IntunePolicy
Exports policies to JSON files.

**Parameters:**
- `PolicyType` (Optional): Type of policies to export (default: All)
- `OutputPath` (Required): Directory path for JSON files
- `TenantType` (Required): 'Source' or 'Target'

### Import-IntunePolicy
Imports policies from JSON files.

**Parameters:**
- `InputPath` (Required): Directory or file path containing JSON policies
- `TenantType` (Required): 'Source' or 'Target'

## Setting Up Azure AD App Registration

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** > **App registrations**
3. Click **New registration**
4. Provide a name (e.g., "IntuneInsanity")
5. Under **API permissions**, add the following Microsoft Graph Application permissions:
   - `DeviceManagementConfiguration.ReadWrite.All`
   - `DeviceManagementApps.ReadWrite.All`
   - `DeviceManagementManagedDevices.ReadWrite.All`
6. Grant admin consent for your organization
7. Under **Certificates & secrets**, create a new client secret
8. Save the Application (client) ID and client secret value

Repeat this process for both source and target tenants.

## Security Considerations

- Store client secrets securely (use Azure Key Vault or secure credential management)
- Use least-privilege permissions when possible
- Review policies before importing to avoid unintended configurations
- Test in a non-production environment first
- Audit policy changes in both tenants

## Troubleshooting

### "Not connected to tenant" Error
Ensure you've run `Connect-IntuneInsanity` for the appropriate tenant type before running other commands.

### "Failed to obtain access token" Error
- Verify your Tenant ID, Client ID, and Client Secret are correct
- Ensure the app registration has the required API permissions
- Confirm admin consent has been granted

### Policy Creation Fails
- Check that the target tenant supports the policy type
- Some policies may have tenant-specific configurations that need adjustment
- Review the error message for specific property issues

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

This project is licensed under the MIT License.

## Disclaimer

This module is provided as-is. Always test in a non-production environment before using in production. The author is not responsible for any unintended changes to your Intune policies or configurations.