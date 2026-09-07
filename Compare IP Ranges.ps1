# Press 'F5' to run this script. Running this script will load the ConfigurationManager
# Site configuration
$SiteCode = ""  # Site code 
$ProviderMachineName = "" # SMS Provider machine name

# Customizations
$initParams = @{}
#$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
#$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors

# Do not change anything below this line

# Import the ConfigurationManager.psd1 module 
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}

# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}

# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams


$Ranges = @(
    '10.241.8.1-10.241.8.254',
)

Function ConvertFrom-IPToInt64 () { 
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [string] $ip
    ) 
    
    PROCESS {
        $octets =$ip.split(".") 
        [int64]([int64]$octets[0]*16777216 +[int64]$octets[1]*65536 +[int64]$octets[2]*256 +[int64]$octets[3])
    }
}

# Get all SCCM IP Range boundaries once
$Boundaries = Get-CMBoundary | Where-Object {
    $_.BoundaryType -eq 3 -and $_.Value
} 

foreach ($Range in $Ranges) {

    $Parts = $Range -split '-'

    $StartIP_Range = ConvertFrom-IPToInt64 $Parts[0]
    $EndIP_Range   = ConvertFrom-IPToInt64 $Parts[1]

    $MissingIPs = @()

    # Check every IP in the requested range
    for ($IP = $StartIP_Range; $IP -le $EndIP_Range; $IP++) {

        $Covered = $false

        foreach ($Boundary in $Boundaries) {

            $BoundaryParts = $Boundary.value -split '-'

            $StartIP_Boundary = ConvertFrom-IPToInt64 $BoundaryParts[0]
            $EndIP_Boundary   = ConvertFrom-IPToInt64 $BoundaryParts[1]

            if ($IP -ge $StartIP_Boundary -and
                $IP -le $EndIP_Boundary) {

                $Covered = $true
                break
            }
        }

        if (-not $Covered) {
            $MissingIPs += $IP
        }
    }

    if ($MissingIPs.Count -eq 0) {
        Write-Host "$Range : FULLY COVERED" -ForegroundColor Green
    }
    else {
        Write-Host "$Range : NOT FULLY COVERED" -ForegroundColor Red
    }
}
