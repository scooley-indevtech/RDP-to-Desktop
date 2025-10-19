# Remote RDP Setup Script

## Overview

This PowerShell script automates the process of enabling Remote Desktop Protocol (RDP) on multiple Windows computers from a Domain Controller. It configures each computer with a specific domain user who will have RDP access.

## What It Does

For each computer in the list, the script:

1. **Enables Remote Desktop** - Turns on RDP functionality
2. **Allows less secure connections** - Disables Network Level Authentication (NLA) requirement
3. **Adds a domain user** - Grants the specified user RDP access by adding them to the "Remote Desktop Users" group
4. **Enables firewall rules** - Opens the necessary firewall ports for RDP on all network profiles (Domain, Private, Public)

## Prerequisites

### On the Domain Controller (where you run the script)

- PowerShell 5.0 or higher
- Domain Administrator credentials
- Network connectivity to target computers

### On Target Computers

- **PowerShell Remoting must be enabled** - See "Enabling PS Remoting" section below
- Windows firewall must allow WinRM (Windows Remote Management)
- The executing user must have administrative rights on target computers

## Enabling PS Remoting on Target Computers

Before running the main script, PowerShell Remoting must be enabled on all target computers. You can do this through your RMM tool using one of these commands:

### Basic (Allow from any IP)

```powershell
Enable-PSRemoting -Force -SkipNetworkProfileCheck; Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
```

### Secure (Allow only from Domain Controller)

Replace `192.168.1.10` with your DC's IP address:

```powershell
Enable-PSRemoting -Force -SkipNetworkProfileCheck; Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -RemoteAddress "192.168.1.10"
```

For multiple DCs:

```powershell
Enable-PSRemoting -Force -SkipNetworkProfileCheck; Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -RemoteAddress @("192.168.1.10","192.168.1.11")
```

## Configuration

### Edit the Computer/User Array

Open `Invoke-RemoteRDPSetup.ps1` and modify the `$computerUserPairs` array with your actual computer names and domain users:

```powershell
$computerUserPairs = @(
    @{ComputerName = "WKS-SALES-01"; DomainUser = "CONTOSO\jsmith"},
    @{ComputerName = "WKS-SALES-02"; DomainUser = "CONTOSO\mjones"},
    @{ComputerName = "WKS-ACCT-15"; DomainUser = "CONTOSO\bwilliams"}
)
```

**Format:**
- `ComputerName` - NetBIOS name or FQDN of the target computer
- `DomainUser` - Domain user in `DOMAIN\username` format

### Optional: Use Credentials

If you need to run with specific credentials, uncomment this line in the script:

```powershell
$credential = Get-Credential
```

You'll be prompted for credentials when the script runs.

## Usage

### Basic Execution

Run from PowerShell on your Domain Controller:

```powershell
.\Invoke-RemoteRDPSetup.ps1
```

### With Explicit Credentials

```powershell
$cred = Get-Credential
# Then edit the script to uncomment the credential line, or pass it manually
```

## Output

The script provides:

- **Real-time progress** - Shows each computer as it's being processed
- **Success/Failure indicators** - Visual feedback with color-coded results
- **Summary table** - Complete overview of all operations
- **Success count** - Total number of successful configurations

### Example Output

```
Enabling RDP on 5 computer(s)

Processing [1/5]: WKS-SALES-01 (User: CONTOSO\jsmith)...
  ✓ SUCCESS: WKS-SALES-01
Processing [2/5]: WKS-SALES-02 (User: CONTOSO\mjones)...
  ✗ FAILED: WKS-SALES-02 - Access is denied

=== SUMMARY ===
ComputerName   DomainUser        Status  Message
------------   ----------        ------  -------
WKS-SALES-01   CONTOSO\jsmith    Success RDP enabled successfully
WKS-SALES-02   CONTOSO\mjones    Failed  Access is denied

Completed: 1 of 2 successful
```

## Compatibility

- **Windows 7 / Server 2008 R2 and newer** - Uses fallback `netsh` commands for older systems
- **Windows 8 / Server 2012 and newer** - Uses modern `Enable-NetFirewallRule` cmdlets

The script automatically detects the OS version and uses the appropriate method.

## Troubleshooting

### "Access is denied"
- Verify you have administrative rights on the target computer
- Check that your account is a Domain Administrator
- Try running with explicit credentials

### "WinRM cannot complete the operation"
- PS Remoting is not enabled on the target computer
- Run the PS Remoting enablement command via your RMM

### "Cannot find computer"
- Verify the computer name is correct
- Check network connectivity: `Test-Connection -ComputerName COMPUTER_NAME`
- Ensure DNS resolution is working

### "A parameter cannot be found that matches parameter name 'Profile'"
- This has been fixed in the latest version
- The script now uses backward-compatible firewall commands

### User already exists in group
- The script will throw an error if the user is already in the Remote Desktop Users group
- This is expected behavior and won't affect RDP functionality

## Security Considerations

- **Disabling NLA** - This script disables Network Level Authentication for compatibility. If you require NLA for security, remove or comment out that section.
- **Firewall on all profiles** - RDP is enabled on Domain, Private, AND Public profiles. Adjust if needed.
- **PS Remoting access** - Consider restricting PS Remoting to only your DC's IP address (see Prerequisites section)
- **Audit trail** - Keep logs of which users were granted RDP access to which computers

## Files

- `Invoke-RemoteRDPSetup.ps1` - Main wrapper script (this file)
- `Enable-RemoteRDP.ps1` - Standalone script for single computer setup (optional)
- `README.md` - This documentation

## License

Free to use and modify for your environment.

## Support

This script is provided as-is without warranty. Test in a non-production environment before deploying to production systems.
