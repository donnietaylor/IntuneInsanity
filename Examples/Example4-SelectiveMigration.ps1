# Example: Selective Policy Migration with Filtering
# This script demonstrates filtering and selectively cloning specific policies

# Import the module
Import-Module .\IntuneInsanity.psd1

# Define tenant credentials
$sourceTenantId = "00000000-0000-0000-0000-000000000001"
$sourceClientId = "11111111-1111-1111-1111-111111111111"
$sourceSecret = "your-source-secret-here"

$targetTenantId = "00000000-0000-0000-0000-000000000002"
$targetClientId = "22222222-2222-2222-2222-222222222222"
$targetSecret = "your-target-secret-here"

# Connect to both tenants
Write-Host "Connecting to tenants..." -ForegroundColor Cyan
Connect-IntuneInsanity -TenantId $sourceTenantId -ClientId $sourceClientId -ClientSecret $sourceSecret -TenantType Source
Connect-IntuneInsanity -TenantId $targetTenantId -ClientId $targetClientId -ClientSecret $targetSecret -TenantType Target

# Get all policies
Write-Host "`nRetrieving all policies from source tenant..." -ForegroundColor Cyan
$allPolicies = Get-IntunePolicy -PolicyType All -TenantType Source

# Display available policies
Write-Host "`n=== Available Policies ===" -ForegroundColor Yellow
$allPolicies | Select-Object @{Name='Name';Expression={$_.displayName}}, 
                             @{Name='Type';Expression={$_.PolicyType}} | 
                Format-Table -AutoSize

# Example 1: Clone only Windows 10 policies
Write-Host "`n--- Cloning Windows 10 Policies ---" -ForegroundColor Cyan
$windowsPolicies = $allPolicies | Where-Object { $_.displayName -like "*Windows*10*" }
Write-Host "Found $($windowsPolicies.Count) Windows 10 policies" -ForegroundColor Yellow

foreach ($policy in $windowsPolicies) {
    Write-Host "Cloning: $($policy.displayName)" -ForegroundColor Cyan
    Copy-IntunePolicy -PolicyId $policy.id -PolicyType $policy.PolicyType
}

# Example 2: Clone only compliance policies
Write-Host "`n--- Cloning Compliance Policies ---" -ForegroundColor Cyan
$compliancePolicies = $allPolicies | Where-Object { $_.PolicyType -eq 'DeviceCompliance' }
Write-Host "Found $($compliancePolicies.Count) compliance policies" -ForegroundColor Yellow

foreach ($policy in $compliancePolicies) {
    Write-Host "Cloning: $($policy.displayName)" -ForegroundColor Cyan
    Copy-IntunePolicy -PolicyId $policy.id -PolicyType $policy.PolicyType
}

# Example 3: Clone policies with custom naming
Write-Host "`n--- Cloning with Custom Names ---" -ForegroundColor Cyan
$selectedPolicy = $allPolicies | Where-Object { $_.displayName -eq "Corporate Device Policy" } | Select-Object -First 1

if ($selectedPolicy) {
    $newName = "Branch Office - $($selectedPolicy.displayName)"
    Write-Host "Cloning '$($selectedPolicy.displayName)' as '$newName'" -ForegroundColor Cyan
    Copy-IntunePolicy -PolicyId $selectedPolicy.id -PolicyType $selectedPolicy.PolicyType -NewPolicyName $newName
}

Write-Host "`n=== Selective Migration Complete ===" -ForegroundColor Green

# Disconnect
Disconnect-IntuneInsanity -TenantType All
