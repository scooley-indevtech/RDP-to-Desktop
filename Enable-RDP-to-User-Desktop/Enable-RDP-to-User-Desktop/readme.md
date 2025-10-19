# Enable-RDP-to-User-Desktop.ps1

## Overview

A PowerShell script that enables Remote Desktop Protocol (RDP) on multiple Windows computers remotely and grants RDP access to a specified domain user. This script is designed to be executed from a Domain Controller and uses PowerShell Remoting to configure target computers.

## What It Does

For each computer specified in the `-ComputerNames` parameter, the script performs:

1. **Enables Remote Desktop** - Sets the registry key to allow RDP connections
2. **Allows less secure connections** - Disables Network Level Authentication (NLA) requirement for broader compatibility
3. **Grants user access** - Adds the specified domain user to the local "Remote Desktop Users" group
4. **Configures Windows Firewall** - Enables the Remote Desktop firewall rules on all network profiles
5. **Provides detailed reporting** - Shows success/failure for each computer with a summary table

## Prerequisites

### On the Domain Controller (where you run the script)

- PowerShell 5.0 or higher
- Domain Administrator credentials (or credentials with admin rights on target computers)
- Network connectivity to target computers

### On Target Computers

- **PowerShell Remoting must be enabled** - See "Enabling PS Remoting" section below
- Windows firewall must allow WinRM (Windows Remote Management)
- The executing user must have administrative rights on target computers

## Enabling PS Remoting on Target Computers

Before running this script, PowerShell Remoting must be enabled on all target computers. Deploy this via your RMM tool:

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

## Parameters

### -ComputerNames (Required)

An array of computer names (NetBIOS names or FQDNs) to configure.

**Type:** `string[]` (array of strings)

**Examples:**
```powershell
-ComputerNames "PC001"
-ComputerNames @("PC001", "PC002", "PC003")
-ComputerNames "WKS-SALES-01", "WKS-SALES-02"
```

### -DomainUser (Required)

The domain user account to grant RDP access. Must be in `DOMAIN\username` format.

**Type:** `string`

**Examples:**
- `"CONTOSO\jsmith"`
- `"CORP\administrator"`
- `"DOMAIN\bmg"`

### -Credential (Optional)

PSCredential object for authenticating to remote computers. If not provided, the script uses your current credentials.

**Type:** `PSCredential`

**Example:**
```powershell
$cred = Get-Credential
-Credential $cred
```

## Usage

### Basic Usage - Single Computer

```powershell
.\Invoke-RemoteRDPSetup.ps1 -ComputerNames "PC001" -DomainUser "CONTOSO\jsmith"
```

### Multiple Computers - Same User

```powershell
.\Invoke-RemoteRDPSetup.ps1 -ComputerNames @("PC001", "PC002", "PC003") -DomainUser "CONTOSO\jsmith"
```

### With Explicit Credentials

```powershell
$cred = Get-Credential
.\Invoke-RemoteRDPSetup.ps1 -ComputerNames @("PC001", "PC002") -DomainUser "CONTOSO\jsmith" -Credential $cred
```

### Using a Variable for Computer List

```powershell
$computers = @("WKS-SALES-01", "WKS-SALES-02", "WKS-ACCT-15", "LAB-PC-42")
.\Invoke-RemoteRDPSetup.ps1 -ComputerNames $computers -DomainUser "CONTOSO\bmg"
```

### Import Computer List from CSV

```powershell
$computers = Import-Csv "computers.csv" | Select-Object -ExpandProperty ComputerName
.\Invoke-RemoteRDPSetup.ps1 -ComputerNames $computers -DomainUser "CONTOSO\helpdesk"
```

### Import from Active Directory

```powershell
$computers = Get-ADComputer -Filter "Name -like 'WKS-*'" | Select-Object -ExpandProperty Name
.\Invoke-RemoteRDPSetup.ps1 -ComputerNames $computers -DomainUser "CONTOSO\support"
```

## Output

The script provides real-time feedback and a comprehensive summary:

### Console Output Example

```
Enabling RDP on 3 computer(s) for user: CONTOSO\jsmith

Processing: PC001...
  ✓ SUCCESS: PC001
Processing: PC002...
  ✗ FAILED: PC002 - The RPC server is unavailable
Processing: PC003...
  ✓ SUCCESS: PC003

=== SUMMARY ===
ComputerName Status  Message
------------ ------  -------
PC001        Success RDP enabled successfully
PC002        Failed  The RPC server is unavailable
PC003        Success RDP enabled successfully

Completed: 2 of 3 successful
```

### Color Coding

- **Cyan** - Informational headers and summaries
- **Yellow** - Computer currently being processed
- **Green** - Successful operations (✓)
- **Red** - Failed operations (✗)

## How It Works

### Execution Flow

1. **Parameter Validation** - Validates required parameters (`-ComputerNames` and `-DomainUser`)
2. **Loop Through Computers** - Iterates through each computer in the `$ComputerNames` array
3. **Remote Execution** - Uses `Invoke-Command` to execute the script block on each target computer
4. **Configuration** - Performs RDP enablement, NLA disable, user addition, and firewall configuration
5. **Result Collection** - Captures success/failure for each computer
6. **Summary Report** - Displays formatted table with all results

### Script Block Execution

The actual RDP configuration happens inside a script block that runs on the remote computer. This script block:

- Runs with the credentials provided (or your current credentials)
- Executes with administrative privileges
- Returns a success/failure status back to the main script
- Includes automatic fallback for older Windows versions (uses `netsh` if `Enable-NetFirewallRule` fails)

## Registry Changes Made

### Enable RDP
```
HKLM:\System\CurrentControlSet\Control\Terminal Server
Key: fDenyTSConnections
Value: 0 (Enabled)
```

### Disable NLA Requirement
```
HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp
Key: UserAuthentication
Value: 0 (Disabled)
```

## Firewall Configuration

Enables the "Remote Desktop" firewall rule group on all network profiles (Domain, Private, Public).

### Compatibility

The script uses a dual-method approach:

**Modern systems (Windows 8/Server 2012+):**
```powershell
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
```

**Legacy systems (Windows 7/Server 2008 R2):**
```powershell
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
```

## Error Handling

### Per-Computer Error Handling

Each computer is processed independently. If one fails, the script continues to the next computer.

### Common Errors and Solutions

**"The RPC server is unavailable"**
- Computer is offline or unreachable
- Check netw
