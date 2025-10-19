# Invoke-RemoteRDPSetup.ps1
# Wrapper script to enable RDP on multiple remote computers

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string[]]$ComputerNames,
    
    [Parameter(Mandatory=$true)]
    [string]$DomainUser,
    
    [Parameter(Mandatory=$false)]
    [PSCredential]$Credential
)

# The script block to run on remote computers
$scriptBlock = {
    param($User)
    
    try {
        # Enable RDP
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
        
        # Allow less secure connections (disable NLA)
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0
        
        # Add user to Remote Desktop Users group
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $User -ErrorAction Stop
        
        # Enable firewall rules (compatible with older Windows versions)
        try {
            # Try modern method first (Windows 8/Server 2012+)
            Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
        }
        catch {
            # Fallback to netsh for older Windows versions
            netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
        }
        
        return @{
            Success = $true
            Message = "RDP enabled successfully"
        }
    }
    catch {
        return @{
            Success = $false
            Message = $_.Exception.Message
        }
    }
}

# Results array
$results = @()

Write-Host "`nEnabling RDP on $($ComputerNames.Count) computer(s) for user: $DomainUser`n" -ForegroundColor Cyan

foreach ($computer in $ComputerNames) {
    Write-Host "Processing: $computer..." -ForegroundColor Yellow
    
    try {
        # Build parameters for Invoke-Command
        $invokeParams = @{
            ComputerName = $computer
            ScriptBlock = $scriptBlock
            ArgumentList = $DomainUser
            ErrorAction = 'Stop'
        }
        
        # Add credential if provided
        if ($Credential) {
            $invokeParams['Credential'] = $Credential
        }
        
        # Execute the script remotely
        $result = Invoke-Command @invokeParams
        
        if ($result.Success) {
            Write-Host "  ✓ SUCCESS: $computer" -ForegroundColor Green
            $results += [PSCustomObject]@{
                ComputerName = $computer
                Status = "Success"
                Message = $result.Message
            }
        }
        else {
            Write-Host "  ✗ FAILED: $computer - $($result.Message)" -ForegroundColor Red
            $results += [PSCustomObject]@{
                ComputerName = $computer
                Status = "Failed"
                Message = $result.Message
            }
        }
    }
    catch {
        Write-Host "  ✗ FAILED: $computer - $($_.Exception.Message)" -ForegroundColor Red
        $results += [PSCustomObject]@{
            ComputerName = $computer
            Status = "Failed"
            Message = $_.Exception.Message
        }
    }
}

# Display summary
Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize

$successCount = ($results | Where-Object {$_.Status -eq "Success"}).Count
Write-Host "`nCompleted: $successCount of $($ComputerNames.Count) successful`n" -ForegroundColor Cyan
