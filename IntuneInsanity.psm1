#Requires -Version 5.1

# Module-level variables
$Script:IntuneConnection = @{
    SourceTenant = $null
    TargetTenant = $null
    SourceToken = $null
    TargetToken = $null
}

#region Authentication Functions

<#
.SYNOPSIS
    Connects to Intune for source and/or target tenant.

.DESCRIPTION
    Establishes authentication to Microsoft Intune using Microsoft Graph API.
    Supports both source and target tenant connections for policy migration.

.PARAMETER TenantId
    The Azure AD Tenant ID to connect to.

.PARAMETER ClientId
    The Application (Client) ID of the Azure AD app registration.

.PARAMETER ClientSecret
    The client secret for the Azure AD app registration.

.PARAMETER TenantType
    Specifies whether this is a Source or Target tenant connection.

.PARAMETER Scopes
    The Microsoft Graph API scopes required. Defaults to DeviceManagementConfiguration.ReadWrite.All

.EXAMPLE
    Connect-IntuneInsanity -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -ClientId "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy" -ClientSecret "your-secret" -TenantType Source

.EXAMPLE
    Connect-IntuneInsanity -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -ClientId "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy" -ClientSecret "your-secret" -TenantType Target

.NOTES
    Requires an Azure AD app registration with appropriate Microsoft Graph API permissions:
    - DeviceManagementConfiguration.ReadWrite.All
    - DeviceManagementApps.ReadWrite.All
    - DeviceManagementManagedDevices.ReadWrite.All
#>
function Connect-IntuneInsanity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$ClientId,

        [Parameter(Mandatory = $true)]
        [string]$ClientSecret,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Source', 'Target')]
        [string]$TenantType,

        [Parameter(Mandatory = $false)]
        [string[]]$Scopes = @(
            'https://graph.microsoft.com/.default'
        )
    )

    begin {
        Write-Verbose "Connecting to Intune - Tenant Type: $TenantType"
    }

    process {
        try {
            # Construct the token request
            $tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
            
            $body = @{
                client_id     = $ClientId
                scope         = $Scopes -join ' '
                client_secret = $ClientSecret
                grant_type    = 'client_credentials'
            }

            # Request access token
            $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body $body -ContentType 'application/x-www-form-urlencoded'
            
            if ($tokenResponse.access_token) {
                if ($TenantType -eq 'Source') {
                    $Script:IntuneConnection.SourceTenant = $TenantId
                    $Script:IntuneConnection.SourceToken = $tokenResponse.access_token
                    Write-Host "Successfully connected to Source tenant: $TenantId" -ForegroundColor Green
                }
                else {
                    $Script:IntuneConnection.TargetTenant = $TenantId
                    $Script:IntuneConnection.TargetToken = $tokenResponse.access_token
                    Write-Host "Successfully connected to Target tenant: $TenantId" -ForegroundColor Green
                }

                return $true
            }
            else {
                throw "Failed to obtain access token"
            }
        }
        catch {
            Write-Error "Failed to connect to Intune: $_"
            return $false
        }
    }
}

<#
.SYNOPSIS
    Disconnects from Intune tenants.

.DESCRIPTION
    Clears the stored authentication tokens and tenant information.

.PARAMETER TenantType
    Specifies whether to disconnect from Source, Target, or All tenants.

.EXAMPLE
    Disconnect-IntuneInsanity -TenantType All
#>
function Disconnect-IntuneInsanity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Source', 'Target', 'All')]
        [string]$TenantType = 'All'
    )

    if ($TenantType -eq 'All' -or $TenantType -eq 'Source') {
        $Script:IntuneConnection.SourceTenant = $null
        $Script:IntuneConnection.SourceToken = $null
        Write-Host "Disconnected from Source tenant" -ForegroundColor Yellow
    }

    if ($TenantType -eq 'All' -or $TenantType -eq 'Target') {
        $Script:IntuneConnection.TargetTenant = $null
        $Script:IntuneConnection.TargetToken = $null
        Write-Host "Disconnected from Target tenant" -ForegroundColor Yellow
    }
}

#endregion

#region Policy Retrieval Functions

<#
.SYNOPSIS
    Retrieves Intune policies from the connected tenant.

.DESCRIPTION
    Gets configuration policies, compliance policies, and app protection policies from Microsoft Intune.

.PARAMETER PolicyType
    The type of policy to retrieve. Options: DeviceConfiguration, DeviceCompliance, AppProtection, All

.PARAMETER TenantType
    Specifies whether to retrieve from Source or Target tenant.

.PARAMETER PolicyId
    Optional. Specific policy ID to retrieve. If not specified, retrieves all policies of the specified type.

.EXAMPLE
    Get-IntunePolicy -PolicyType DeviceConfiguration -TenantType Source

.EXAMPLE
    Get-IntunePolicy -PolicyType All -TenantType Source
#>
function Get-IntunePolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('DeviceConfiguration', 'DeviceCompliance', 'AppProtection', 'All')]
        [string]$PolicyType = 'All',

        [Parameter(Mandatory = $true)]
        [ValidateSet('Source', 'Target')]
        [string]$TenantType,

        [Parameter(Mandatory = $false)]
        [string]$PolicyId
    )

    begin {
        # Verify connection
        $token = if ($TenantType -eq 'Source') { $Script:IntuneConnection.SourceToken } else { $Script:IntuneConnection.TargetToken }
        
        if (-not $token) {
            throw "Not connected to $TenantType tenant. Please run Connect-IntuneInsanity first."
        }

        $headers = @{
            'Authorization' = "Bearer $token"
            'Content-Type'  = 'application/json'
        }

        $graphBaseUrl = 'https://graph.microsoft.com/v1.0/deviceManagement'
    }

    process {
        try {
            $policies = @()

            # Define policy endpoints
            $endpoints = @{
                DeviceConfiguration = @{
                    Url = "$graphBaseUrl/deviceConfigurations"
                    Name = 'Device Configuration Policies'
                }
                DeviceCompliance = @{
                    Url = "$graphBaseUrl/deviceCompliancePolicies"
                    Name = 'Device Compliance Policies'
                }
                AppProtection = @{
                    Url = "$graphBaseUrl/managedAppPolicies"
                    Name = 'App Protection Policies'
                }
            }

            # Determine which endpoints to query
            $endpointsToQuery = if ($PolicyType -eq 'All') {
                $endpoints.Keys
            } else {
                @($PolicyType)
            }

            foreach ($type in $endpointsToQuery) {
                Write-Verbose "Retrieving $($endpoints[$type].Name)..."
                
                $url = if ($PolicyId) {
                    "$($endpoints[$type].Url)/$PolicyId"
                } else {
                    $endpoints[$type].Url
                }

                $response = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
                
                if ($PolicyId) {
                    # Single policy
                    $policy = $response
                    $policy | Add-Member -NotePropertyName 'PolicyType' -NotePropertyValue $type -Force
                    $policies += $policy
                    Write-Host "Retrieved policy: $($policy.displayName)" -ForegroundColor Cyan
                } else {
                    # Multiple policies
                    if ($response.value) {
                        foreach ($policy in $response.value) {
                            $policy | Add-Member -NotePropertyName 'PolicyType' -NotePropertyValue $type -Force
                            $policies += $policy
                        }
                        Write-Host "Retrieved $($response.value.Count) $($endpoints[$type].Name)" -ForegroundColor Cyan
                    }
                }
            }

            return $policies
        }
        catch {
            Write-Error "Failed to retrieve policies: $_"
            return $null
        }
    }
}

#endregion

#region Policy Migration Functions

<#
.SYNOPSIS
    Copies an Intune policy from source tenant to target tenant.

.DESCRIPTION
    Clones a policy from the source tenant and creates it in the target tenant.
    Handles policy transformation and removes properties that cannot be set during creation.

.PARAMETER PolicyId
    The ID of the policy to copy from the source tenant.

.PARAMETER PolicyType
    The type of policy being copied.

.PARAMETER NewPolicyName
    Optional. New name for the policy in the target tenant. If not specified, appends " (Cloned)" to original name.

.EXAMPLE
    Copy-IntunePolicy -PolicyId "12345678-1234-1234-1234-123456789012" -PolicyType DeviceConfiguration

.EXAMPLE
    Copy-IntunePolicy -PolicyId "12345678-1234-1234-1234-123456789012" -PolicyType DeviceConfiguration -NewPolicyName "My Custom Policy"
#>
function Copy-IntunePolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PolicyId,

        [Parameter(Mandatory = $true)]
        [ValidateSet('DeviceConfiguration', 'DeviceCompliance', 'AppProtection')]
        [string]$PolicyType,

        [Parameter(Mandatory = $false)]
        [string]$NewPolicyName
    )

    begin {
        # Verify both connections exist
        if (-not $Script:IntuneConnection.SourceToken -or -not $Script:IntuneConnection.TargetToken) {
            throw "Both Source and Target tenant connections are required. Please run Connect-IntuneInsanity for both tenants."
        }
    }

    process {
        try {
            # Get the policy from source tenant
            Write-Host "Retrieving policy from source tenant..." -ForegroundColor Cyan
            $sourcePolicy = Get-IntunePolicy -PolicyId $PolicyId -PolicyType $PolicyType -TenantType Source

            if (-not $sourcePolicy) {
                throw "Policy not found in source tenant"
            }

            # Transform policy for target tenant
            $targetPolicy = ConvertTo-IntuneTargetPolicy -SourcePolicy $sourcePolicy -NewPolicyName $NewPolicyName

            # Create policy in target tenant
            Write-Host "Creating policy in target tenant..." -ForegroundColor Cyan
            $createdPolicy = New-IntunePolicy -Policy $targetPolicy -PolicyType $PolicyType

            if ($createdPolicy) {
                Write-Host "Successfully copied policy: $($targetPolicy.displayName)" -ForegroundColor Green
                return $createdPolicy
            }
            else {
                throw "Failed to create policy in target tenant"
            }
        }
        catch {
            Write-Error "Failed to copy policy: $_"
            return $null
        }
    }
}

<#
.SYNOPSIS
    Exports Intune policies to JSON files.

.DESCRIPTION
    Exports policies from the connected tenant to JSON files for backup or manual migration.

.PARAMETER PolicyType
    The type of policy to export.

.PARAMETER OutputPath
    The directory path where JSON files will be saved.

.PARAMETER TenantType
    Specifies whether to export from Source or Target tenant.

.EXAMPLE
    Export-IntunePolicy -PolicyType All -OutputPath "C:\IntuneBackup" -TenantType Source
#>
function Export-IntunePolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('DeviceConfiguration', 'DeviceCompliance', 'AppProtection', 'All')]
        [string]$PolicyType = 'All',

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Source', 'Target')]
        [string]$TenantType
    )

    begin {
        # Create output directory if it doesn't exist
        if (-not (Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        }
    }

    process {
        try {
            # Get all policies
            $policies = Get-IntunePolicy -PolicyType $PolicyType -TenantType $TenantType

            if (-not $policies) {
                Write-Warning "No policies found to export"
                return
            }

            $exportCount = 0
            foreach ($policy in $policies) {
                $fileName = "$($policy.displayName -replace '[\\/:*?"<>|]', '_')_$($policy.id).json"
                $filePath = Join-Path $OutputPath $fileName
                
                $policy | ConvertTo-Json -Depth 10 | Out-File -FilePath $filePath -Encoding UTF8
                $exportCount++
            }

            Write-Host "Successfully exported $exportCount policies to $OutputPath" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to export policies: $_"
        }
    }
}

<#
.SYNOPSIS
    Imports Intune policies from JSON files.

.DESCRIPTION
    Imports policies from JSON files and creates them in the target tenant.

.PARAMETER InputPath
    The directory path or file path containing JSON policy files.

.PARAMETER TenantType
    Specifies whether to import to Source or Target tenant.

.EXAMPLE
    Import-IntunePolicy -InputPath "C:\IntuneBackup" -TenantType Target
#>
function Import-IntunePolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Source', 'Target')]
        [string]$TenantType
    )

    process {
        try {
            $files = if (Test-Path $InputPath -PathType Container) {
                Get-ChildItem -Path $InputPath -Filter "*.json"
            } else {
                Get-Item $InputPath
            }

            if (-not $files) {
                Write-Warning "No JSON files found at $InputPath"
                return
            }

            $importCount = 0
            foreach ($file in $files) {
                try {
                    Write-Host "Importing policy from $($file.Name)..." -ForegroundColor Cyan
                    
                    $policyJson = Get-Content $file.FullName -Raw
                    $policy = $policyJson | ConvertFrom-Json

                    # Transform for import
                    $targetPolicy = ConvertTo-IntuneTargetPolicy -SourcePolicy $policy

                    # Create policy
                    $created = New-IntunePolicy -Policy $targetPolicy -PolicyType $policy.PolicyType -TenantType $TenantType

                    if ($created) {
                        $importCount++
                        Write-Host "  Successfully imported: $($targetPolicy.displayName)" -ForegroundColor Green
                    }
                }
                catch {
                    Write-Warning "  Failed to import $($file.Name): $_"
                }
            }

            Write-Host "Successfully imported $importCount policies" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to import policies: $_"
        }
    }
}

#endregion

#region Helper Functions

<#
.SYNOPSIS
    Transforms a source policy for creation in target tenant.

.DESCRIPTION
    Internal helper function that removes read-only properties and updates policy metadata.
#>
function ConvertTo-IntuneTargetPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$SourcePolicy,

        [Parameter(Mandatory = $false)]
        [string]$NewPolicyName
    )

    # Clone the policy object
    $targetPolicy = $SourcePolicy | ConvertTo-Json -Depth 10 | ConvertFrom-Json

    # Remove read-only properties that cannot be set during creation
    # Note: Keep '@odata.type' for App Protection Policies as it's required for subtypes
    $readOnlyProperties = @(
        'id',
        'createdDateTime',
        'lastModifiedDateTime',
        'version',
        '@odata.context'
    )

    foreach ($prop in $readOnlyProperties) {
        if ($targetPolicy.PSObject.Properties.Name -contains $prop) {
            $targetPolicy.PSObject.Properties.Remove($prop)
        }
    }

    # Update display name
    if ($NewPolicyName) {
        $targetPolicy.displayName = $NewPolicyName
    }
    elseif ($targetPolicy.displayName) {
        $targetPolicy.displayName = "$($targetPolicy.displayName) (Cloned)"
    }

    return $targetPolicy
}

<#
.SYNOPSIS
    Creates a new policy in the specified tenant.

.DESCRIPTION
    Internal helper function that creates a policy using Microsoft Graph API.
#>
function New-IntunePolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Policy,

        [Parameter(Mandatory = $true)]
        [ValidateSet('DeviceConfiguration', 'DeviceCompliance', 'AppProtection')]
        [string]$PolicyType,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Source', 'Target')]
        [string]$TenantType = 'Target'
    )

    try {
        # Get the appropriate token
        $token = if ($TenantType -eq 'Source') { $Script:IntuneConnection.SourceToken } else { $Script:IntuneConnection.TargetToken }
        
        if (-not $token) {
            throw "Not connected to $TenantType tenant"
        }

        $headers = @{
            'Authorization' = "Bearer $token"
            'Content-Type'  = 'application/json'
        }

        $graphBaseUrl = 'https://graph.microsoft.com/v1.0/deviceManagement'

        # Determine endpoint
        $endpoint = switch ($PolicyType) {
            'DeviceConfiguration' { "$graphBaseUrl/deviceConfigurations" }
            'DeviceCompliance' { "$graphBaseUrl/deviceCompliancePolicies" }
            'AppProtection' { "$graphBaseUrl/managedAppPolicies" }
        }

        # Create policy
        $body = $Policy | ConvertTo-Json -Depth 10
        $response = Invoke-RestMethod -Method Post -Uri $endpoint -Headers $headers -Body $body

        return $response
    }
    catch {
        Write-Error "Failed to create policy: $_"
        return $null
    }
}

#endregion

# Export module members
Export-ModuleMember -Function @(
    'Connect-IntuneInsanity',
    'Disconnect-IntuneInsanity',
    'Get-IntunePolicy',
    'Copy-IntunePolicy',
    'Export-IntunePolicy',
    'Import-IntunePolicy'
)
