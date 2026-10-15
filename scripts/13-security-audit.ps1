# HomeLab step 13: READ-ONLY security audit. Changes nothing. Saves audit.txt for Claude to review.
param([switch]$Elevated)
$out = 'C:\Users\Sheem\Documents\HomeLab\audit.txt'
if (-not $Elevated) {
  "Security audit $(Get-Date)" | Set-Content $out
  Write-Host "Running read-only audit. Click YES on the Windows prompt (needed to read some security settings)..." -ForegroundColor Cyan
  Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Elevated"
  # Linux side (no admin needed)
  $bash = @'
echo '--- containers and published ports ---'
docker ps --format '{{.Names}} | {{.Image}} | {{.Ports}}'
echo
echo '--- containers with docker.sock mounted (RW true = full control) ---'
for c in $(docker ps -q); do
  n=$(docker inspect -f '{{.Name}}' "$c")
  docker inspect -f '{{range .Mounts}}{{.Source}} RW={{.RW}}{{println}}{{end}}' "$c" | grep docker.sock | sed "s#^#$n #"
done
echo
echo '--- Linux listening ports ---'
ss -tulpn | head -40
echo
echo '--- pending Ubuntu updates (count) ---'
apt-get -s upgrade 2>/dev/null | grep -c '^Inst'
echo '--- Linux users with login shells ---'
awk -F: '$7 ~ /(bash|sh)$/ {print $1}' /etc/passwd
'@
  $sh = Join-Path $PSScriptRoot 'audit.sh'
  [IO.File]::WriteAllText($sh, ($bash -replace "`r","") + "`n")
  $l = (wsl.exe -d Ubuntu -u root -- bash /mnt/c/Users/Sheem/Documents/HomeLab/audit.sh 2>&1 | Out-String) -replace "`0",""
  "`n========== LINUX (WSL) ==========`n$l" | Add-Content $out
  Write-Host "`nAudit saved. Tell Claude 'done'." -ForegroundColor Green
  Read-Host "Press Enter to close"; exit
}
function S($t) { "`n========== $t ==========" | Add-Content $out }
function A($o) { ($o | Out-String -Width 200) | Add-Content $out }
try {
  S "ANTIVIRUS (Defender)"; A (Get-MpComputerStatus -ErrorAction SilentlyContinue | Select AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled,AntivirusSignatureLastUpdated,QuickScanEndTime)
  S "OTHER ANTIVIRUS REGISTERED"; A (Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction SilentlyContinue | Select displayName,productState)
  S "FIREWALL PROFILES"; A (Get-NetFirewallProfile | Select Name,Enabled,DefaultInboundAction,DefaultOutboundAction)
  S "NETWORK PROFILE (Public is safer)"; A (Get-NetConnectionProfile | Select InterfaceAlias,NetworkCategory)
  S "INBOUND ALLOW RULES (enabled, non-default, top 60)"; A (Get-NetFirewallRule -Direction Inbound -Enabled True -Action Allow | Where-Object { $_.Group -eq $null -or $_.Group -eq '' } | Select -First 60 DisplayName,Profile | Sort DisplayName)
  S "HYPER-V (WSL) FIREWALL RULES"; A (Get-NetFirewallHyperVRule -ErrorAction SilentlyContinue | Select Name,Protocol,LocalPorts,RemoteAddresses,Action)
  S "WINDOWS LISTENING TCP PORTS"; A (Get-NetTCPConnection -State Listen | Where-Object { $_.LocalAddress -notin @('127.0.0.1','::1') } | Select LocalAddress,LocalPort,@{n='Process';e={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}} | Sort LocalPort -Unique)
  S "WINDOWS LISTENING UDP PORTS (non-loopback)"; A (Get-NetUDPEndpoint | Where-Object { $_.LocalAddress -notin @('127.0.0.1','::1') -and $_.LocalPort -lt 10000 } | Select LocalAddress,LocalPort,@{n='Process';e={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}} | Sort LocalPort -Unique)
  S "REMOTE DESKTOP"; A ("RDP deny connections (1 = off): " + (Get-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -ErrorAction SilentlyContinue).fDenyTSConnections)
  S "SHARED FOLDERS"; A (Get-SmbShare -ErrorAction SilentlyContinue | Select Name,Path,Description)
  S "SMBv1 (should be off)"; A (Get-SmbServerConfiguration -ErrorAction SilentlyContinue | Select EnableSMB1Protocol)
  S "LOCAL ACCOUNTS"; A (Get-LocalUser | Select Name,Enabled,PasswordRequired,LastLogon)
  S "ADMINISTRATORS GROUP"; A (Get-LocalGroupMember Administrators -ErrorAction SilentlyContinue | Select Name,PrincipalSource)
  S "DISK ENCRYPTION"; A (Get-BitLockerVolume -MountPoint C: -ErrorAction SilentlyContinue | Select MountPoint,ProtectionStatus,VolumeStatus); A ("Device encryption (manage-bde):"); A (manage-bde -status C: 2>&1 | Select-String 'Protection Status|Conversion Status')
  S "WINDOWS UPDATE (last 5 installed)"; A (Get-HotFix | Sort InstalledOn -Descending -ErrorAction SilentlyContinue | Select -First 5 HotFixID,InstalledOn)
  S "SCREEN LOCK / AUTO-LOGON"; A ("AutoAdminLogon: " + (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue).AutoAdminLogon)
  S "LAB SERVICES"; A (Get-Service AdGuardHome,'Plex Media Server' -ErrorAction SilentlyContinue | Select Name,Status,StartType); A (Get-Process 'Plex Media Server' -ErrorAction SilentlyContinue | Select ProcessName,Id)
  S "STARTUP ITEMS"; A (Get-CimInstance Win32_StartupCommand | Select Name,Command,Location)
} catch { A "ERROR: $($_.Exception.Message)" }
