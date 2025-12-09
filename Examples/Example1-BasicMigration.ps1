# Example: Basic Tenant-to-Tenant Policy Migration
# This script demonstrates how to clone all policies from one tenant to another

# Import the module
Import-Module .\IntuneInsanity.psd1

# Define tenant credentials
$sourceTenantId = "00000000-0000-0000-0000-000000000001"
$sourceClientId = "11111111-1111-1111-1111-111111111111"
$sourceSecret = "your-source-secret-here"

$targetTenantId = "00000000-0000-0000-0000-000000000002"
$targetClientId = "22222222-2222-2222-2222-222222222222"
$targetSecret = "your-target-secret-here"

# Connect to source tenant
Write-Host "Connecting to source tenant..." -ForegroundColor Cyan
Connect-IntuneInsanity -TenantId $sourceTenantId `
                        -ClientId $sourceClientId `
                        -ClientSecret $sourceSecret `
                        -TenantType Source

# Connect to target tenant
Write-Host "Connecting to target tenant..." -ForegroundColor Cyan
Connect-IntuneInsanity -TenantId $targetTenantId `
                        -ClientId $targetClientId `
                        -ClientSecret $targetSecret `
                        -TenantType Target

# Get all device configuration policies from source
Write-Host "`nRetrieving policies from source tenant..." -ForegroundColor Cyan
$policies = Get-IntunePolicy -PolicyType DeviceConfiguration -TenantType Source

Write-Host "`nFound $($policies.Count) policies to clone" -ForegroundColor Yellow

# Clone each policy to target tenant
$successCount = 0
$failCount = 0

foreach ($policy in $policies) {
    Write-Host "`nCloning: $($policy.displayName)" -ForegroundColor Cyan
    
    $result = Copy-IntunePolicy -PolicyId $policy.id `
                                -PolicyType $policy.PolicyType
    
    if ($result) {
        $successCount++
    } else {
        $failCount++
    }
}

# Summary
Write-Host "`n=== Migration Summary ===" -ForegroundColor Yellow
Write-Host "Successfully cloned: $successCount policies" -ForegroundColor Green
Write-Host "Failed: $failCount policies" -ForegroundColor Red

# Disconnect
Disconnect-IntuneInsanity -TenantType All
