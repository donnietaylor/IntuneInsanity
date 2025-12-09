@{
    # Script module or binary module file associated with this manifest
    RootModule = 'IntuneInsanity.psm1'

    # Version number of this module
    ModuleVersion = '1.0.0'

    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

    # Author of this module
    Author = 'Donnie Taylor'

    # Company or vendor of this module
    CompanyName = 'IntuneInsanity'

    # Copyright statement for this module
    Copyright = '(c) 2025 Donnie Taylor. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'PowerShell module to clone Intune policies from one tenant to another'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module
    FunctionsToExport = @(
        'Connect-IntuneInsanity',
        'Disconnect-IntuneInsanity',
        'Get-IntunePolicy',
        'Copy-IntunePolicy',
        'Export-IntunePolicy',
        'Import-IntunePolicy'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module
            Tags = @('Intune', 'Microsoft365', 'Azure', 'DeviceManagement', 'MDM', 'Policy')

            # A URL to the license for this module
            LicenseUri = ''

            # A URL to the main website for this project
            ProjectUri = 'https://github.com/donnietaylor/IntuneInsanity'

            # ReleaseNotes of this module
            ReleaseNotes = 'Initial release - Clone Intune policies between tenants'
        }
    }
}
