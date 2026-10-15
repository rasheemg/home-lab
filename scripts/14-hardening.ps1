# HomeLab step 14: fixes from the security audit (each listed so you know exactly what changes).
#  A) Dashboard repair: recreate the dashboard container so it's reachable on port 3000 again.
#  B) Ubuntu security updates: install the 112 pending Linux updates.
#  C) Tighten the Linux-side firewall: remove leftover Pi-hole ports (53, 8080). Keep only 3000, 3001, 9443 from home Wi-Fi.
param([switch]$Elevated)
$log = 'C:\Users\Sheem\Documents\HomeLab\step14-log.txt'
if (-not $Elevated) {
  "Step 14 started $(Get-Date)" | Set-Content $log
  $bash = @'
set -e
cd /opt/homelab
echo '--- A) recreate dashboard ---'
docker compose up -d --force-recreate homepage
sleep 10
docker ps --filter name=homepage --format '{{.Names}} | {{.Status}} | {{.Ports}}'
printf 'dashboard http -> '; curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3000 || echo fail
echo '--- B) Ubuntu updates ---'
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get -y -qq -o Dpkg::Options::=--force-confold upgrade >/dev/null
echo "pending after: $(apt-get -s upgrade 2>/dev/null | grep -c '^Inst')"
'@
  $sh = Join-Path $PSScriptRoot 'step14.sh'
  [IO.File]::WriteAllText($sh, ($bash -replace "`r","") + "`n")
  Write-Host "A+B) Repairing dashboard and installing Ubuntu updates (3-8 minutes)..." -ForegroundColor Cyan
  $o = (wsl.exe -d Ubuntu -u root -- bash /mnt/c/Users/Sheem/Documents/HomeLab/step14.sh 2>&1 | Out-String) -replace "`0",""
  "Linux side:`n$o" | Add-Content $log
  Write-Host "C) Tightening firewall. Click YES on the Windows prompt..." -ForegroundColor Cyan
  Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Elevated"
  Get-Content $log | Write-Host
  Write-Host "`nDone - tell Claude 'done'." -ForegroundColor Green
  Read-Host "Press Enter to close"; exit
}
function Log($m) { $m | Add-Content $log }
try {
  $wsl = '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}'
  Get-NetFirewallHyperVRule -ErrorAction SilentlyContinue | Where-Object Name -like 'HomeLab-*' | Remove-NetFirewallHyperVRule
  New-NetFirewallHyperVRule -Name 'HomeLab-TCP' -DisplayName 'HomeLab TCP (LAN only)' -Direction Inbound -VMCreatorId $wsl `
    -Protocol TCP -LocalPorts 3000,3001,9443 -RemoteAddresses '192.168.1.0/24' -Action Allow | Out-Null
  Log "C) Linux firewall now:"
  Log (Get-NetFirewallHyperVRule | Where-Object Name -like 'HomeLab-*' | Format-Table Name,Protocol,LocalPorts,RemoteAddresses,Action -AutoSize | Out-String)
} catch { Log "C) ERROR: $($_.Exception.Message)" }
