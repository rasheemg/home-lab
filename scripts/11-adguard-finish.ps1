# HomeLab step 11: let home devices reach AdGuard (firewall), bring the dashboard back, add AdGuard to it.
# Firewall rules: ONLY your home Wi-Fi (local subnet), ONLY AdGuard's program, ONLY ports 53 (DNS) and 3080 (admin page).
param([switch]$Elevated)
$log = 'C:\Users\Sheem\Documents\HomeLab\step11-log.txt'
if (-not $Elevated) {
  "Step 11 started $(Get-Date)" | Set-Content $log
  Write-Host "Opening AdGuard to your home Wi-Fi. Click YES on the Windows prompt..." -ForegroundColor Cyan
  Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Elevated"
  $o = (wsl.exe -d Ubuntu -u root -- bash -c "cp /mnt/c/Users/Sheem/Documents/HomeLab/stack/homepage/services.yaml /opt/homelab/homepage/services.yaml && docker start homepage && sleep 8 && docker ps --format '{{.Names}}  {{.Status}}'" 2>&1 | Out-String) -replace "`0",""
  "Linux side:`n$o" | Add-Content $log
  try { $r = Resolve-DnsName doubleclick.net -Server 127.0.0.1 -DnsOnly -QuickTimeout -ErrorAction Stop | Select -First 1 | Out-String; "Block test (expect 0.0.0.0):`n$r" | Add-Content $log } catch { "Block test failed: $($_.Exception.Message)" | Add-Content $log }
  try { $r = Resolve-DnsName example.com -Server 127.0.0.1 -DnsOnly -QuickTimeout -ErrorAction Stop | Select -First 1 | Out-String; "Normal lookup:`n$r" | Add-Content $log } catch { "Normal lookup failed: $($_.Exception.Message)" | Add-Content $log }
  Get-Content $log | Write-Host
  Write-Host "`nDone - tell Claude 'done'." -ForegroundColor Green
  Read-Host "Press Enter to close"; exit
}
function Log($m) { $m | Add-Content $log }
try {
  $exe = 'C:\AdGuardHome\AdGuardHome.exe'
  Get-NetFirewallRule -DisplayName 'HomeLab AdGuard*' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
  New-NetFirewallRule -DisplayName 'HomeLab AdGuard DNS (UDP)' -Direction Inbound -Program $exe -Protocol UDP -LocalPort 53 -RemoteAddress LocalSubnet -Profile Any -Action Allow | Out-Null
  New-NetFirewallRule -DisplayName 'HomeLab AdGuard DNS (TCP)' -Direction Inbound -Program $exe -Protocol TCP -LocalPort 53 -RemoteAddress LocalSubnet -Profile Any -Action Allow | Out-Null
  New-NetFirewallRule -DisplayName 'HomeLab AdGuard Admin' -Direction Inbound -Program $exe -Protocol TCP -LocalPort 3080 -RemoteAddress LocalSubnet -Profile Any -Action Allow | Out-Null
  Log "Firewall rules created:"; Log (Get-NetFirewallRule -DisplayName 'HomeLab AdGuard*' | Format-Table DisplayName,Enabled,Action -AutoSize | Out-String)
  Log "AdGuard listening:"; Log (Get-NetUDPEndpoint -LocalPort 53 -ErrorAction SilentlyContinue | Format-Table LocalAddress,LocalPort,OwningProcess -AutoSize | Out-String)
  Log "RESULT: FIREWALL_OK"
} catch { Log "ERROR: $($_.Exception.Message)" }
