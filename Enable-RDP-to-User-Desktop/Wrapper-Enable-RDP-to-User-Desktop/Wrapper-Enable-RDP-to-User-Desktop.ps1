# Invoke-RemoteRDPSetup.ps1
# Wrapper script to enable RDP on multiple remote computers with per-computer user assignment

# Define array of computers and their corresponding domain users
$computerUserPairs = @(
    @{ComputerName = "WKS-SALES-01"; DomainUser = "CONTOSO\jsmith"},
    @{ComputerName = "WKS-SALES-02"; DomainUser = "CONTOSO\mjones"},
    @{ComputerName = "WKS-ACCT-15"; DomainUser = "CONTOSO\bwilliams"},
    @{ComputerName = "LAB-PC-42"; DomainUser = "CONTOSO\rdavis"},
    @{ComputerName = "CONF-RM-A"; DomainUser = "CONTOSO\sgarcia"}
)

# Optional: Credential for remote execution (if needed)
# $credential = Get-Credential

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

Write-Host "`nEnabling RDP on $($computerUserPairs.Count) computer(s)`n" -ForegroundColor Cyan

# Initialize counter for while loop
$i = 0

# Process each computer/user pair using while loop
while ($i -lt $computerUserPairs.Count) {
    $computer = $computerUserPairs[$i].ComputerName
    $user = $computerUserPairs[$i].DomainUser
    
    Write-Host "Processing [$($i+1)/$($computerUserPairs.Count)]: $computer (User: $user)..." -ForegroundColor Yellow
    
    try {
        # Build parameters for Invoke-Command
        $invokeParams = @{
            ComputerName = $computer
            ScriptBlock = $scriptBlock
            ArgumentList = $user
            ErrorAction = 'Stop'
        }
        
        # Add credential if it exists
        if ($credential) {
            $invokeParams['Credential'] = $credential
        }
        
        # Execute the script remotely
        $result = Invoke-Command @invokeParams
        
        if ($result.Success) {
            Write-Host "  ✓ SUCCESS: $computer" -ForegroundColor Green
            $results += [PSCustomObject]@{
                ComputerName = $computer
                DomainUser = $user
                Status = "Success"
                Message = $result.Message
            }
        }
        else {
            Write-Host "  ✗ FAILED: $computer - $($result.Message)" -ForegroundColor Red
            $results += [PSCustomObject]@{
                ComputerName = $computer
                DomainUser = $user
                Status = "Failed"
                Message = $result.Message
            }
        }
    }
    catch {
        Write-Host "  ✗ FAILED: $computer - $($_.Exception.Message)" -ForegroundColor Red
        $results += [PSCustomObject]@{
            ComputerName = $computer
            DomainUser = $user
            Status = "Failed"
            Message = $_.Exception.Message
        }
    }
    
    # Increment counter
    $i++
}

# Display summary
Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize

$successCount = ($results | Where-Object {$_.Status -eq "Success"}).Count
Write-Host "`nCompleted: $successCount of $($computerUserPairs.Count) successful`n" -ForegroundColor Cyan
