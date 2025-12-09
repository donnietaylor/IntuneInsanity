# Example: Restore Policies from Backup
# This script imports Intune policies from a backup directory

# Import the module
Import-Module .\IntuneInsanity.psd1

# Define tenant credentials
$tenantId = "00000000-0000-0000-0000-000000000002"
$clientId = "22222222-2222-2222-2222-222222222222"
$clientSecret = "your-secret-here"

# Define backup location to restore from
$backupPath = "C:\IntuneBackup\2025-12-09_143000"

# Verify backup exists
if (-not (Test-Path $backupPath)) {
    Write-Error "Backup path not found: $backupPath"
    exit
}

# Display backup info if manifest exists
$manifestPath = Join-Path $backupPath "backup-manifest.json"
if (Test-Path $manifestPath) {
    $manifest = Get-Content $manifestPath | ConvertFrom-Json
    Write-Host "=== Backup Information ===" -ForegroundColor Yellow
    Write-Host "Backup Date: $($manifest.BackupDate)" -ForegroundColor Cyan
    Write-Host "Source Tenant: $($manifest.TenantId)" -ForegroundColor Cyan
    Write-Host ""
}

# Connect to target tenant
Write-Host "Connecting to target tenant..." -ForegroundColor Cyan
Connect-IntuneInsanity -TenantId $tenantId `
                        -ClientId $clientId `
                        -ClientSecret $clientSecret `
                        -TenantType Target

# Import Device Configuration Policies
$configPath = Join-Path $backupPath "DeviceConfiguration"
if (Test-Path $configPath) {
    Write-Host "`nImporting Device Configuration Policies..." -ForegroundColor Cyan
    Import-IntunePolicy -InputPath $configPath -TenantType Target
}

# Import Device Compliance Policies
$compliancePath = Join-Path $backupPath "DeviceCompliance"
if (Test-Path $compliancePath) {
    Write-Host "`nImporting Device Compliance Policies..." -ForegroundColor Cyan
    Import-IntunePolicy -InputPath $compliancePath -TenantType Target
}

# Import App Protection Policies
$appProtectionPath = Join-Path $backupPath "AppProtection"
if (Test-Path $appProtectionPath) {
    Write-Host "`nImporting App Protection Policies..." -ForegroundColor Cyan
    Import-IntunePolicy -InputPath $appProtectionPath -TenantType Target
}

Write-Host "`n=== Restore Complete ===" -ForegroundColor Green

# Disconnect
Disconnect-IntuneInsanity -TenantType Target
