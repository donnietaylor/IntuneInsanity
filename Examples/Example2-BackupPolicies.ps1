# Example: Backup All Intune Policies to JSON
# This script exports all Intune policies from a tenant to JSON files for backup

# Import the module
Import-Module .\IntuneInsanity.psd1

# Define tenant credentials
$tenantId = "00000000-0000-0000-0000-000000000001"
$clientId = "11111111-1111-1111-1111-111111111111"
$clientSecret = "your-secret-here"

# Define backup location
$backupPath = "C:\IntuneBackup\$(Get-Date -Format 'yyyy-MM-dd_HHmmss')"

# Connect to tenant
Write-Host "Connecting to tenant..." -ForegroundColor Cyan
Connect-IntuneInsanity -TenantId $tenantId `
                        -ClientId $clientId `
                        -ClientSecret $clientSecret `
                        -TenantType Source

# Create backup directory
Write-Host "Creating backup directory: $backupPath" -ForegroundColor Cyan
New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

# Export all policy types
Write-Host "`nExporting Device Configuration Policies..." -ForegroundColor Cyan
Export-IntunePolicy -PolicyType DeviceConfiguration `
                    -OutputPath "$backupPath\DeviceConfiguration" `
                    -TenantType Source

Write-Host "`nExporting Device Compliance Policies..." -ForegroundColor Cyan
Export-IntunePolicy -PolicyType DeviceCompliance `
                    -OutputPath "$backupPath\DeviceCompliance" `
                    -TenantType Source

Write-Host "`nExporting App Protection Policies..." -ForegroundColor Cyan
Export-IntunePolicy -PolicyType AppProtection `
                    -OutputPath "$backupPath\AppProtection" `
                    -TenantType Source

Write-Host "`n=== Backup Complete ===" -ForegroundColor Green
Write-Host "Policies backed up to: $backupPath" -ForegroundColor Yellow

# Create a backup manifest
$manifest = @{
    BackupDate = Get-Date
    TenantId = $tenantId
    BackupPath = $backupPath
}

$manifest | ConvertTo-Json | Out-File "$backupPath\backup-manifest.json"

# Disconnect
Disconnect-IntuneInsanity -TenantType Source

Write-Host "`nBackup manifest created. Disconnected from tenant." -ForegroundColor Cyan
