# HomeLab step 10: replace Pi-hole with AdGuard Home running natively on Windows.
param([switch]$Elevated)
$log = 'C:\Users\Sheem\Documents\HomeLab\step10-log.txt'
if (-not $Elevated) {
  "Step 10 started $(Get-Date)" | Set-Content $log
  # 1) Inside Linux (no admin needed): remove Pi-hole, pause the dashboard so port 3000 is free for AdGuard's setup page.
  $o = (wsl.exe -d Ubuntu -u root -- bash -c "cd /opt/homelab/pihole 2>/dev/null && docker compose down; docker stop homepage; docker ps --format '{{.Names}}'" 2>&1 | Out-String) -replace "`0",""
  "Linux side:`n$o" | Add-Content $log
  Write-Host "Installing AdGuard Home. Click YES on the Windows prompt..." -ForegroundColor Cyan
  Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Elevated"
  $t = Get-Content $log -Raw; Write-Host $t
  if ($t -match 'RESULT: INSTALLED') {
    Start-Process 'http://127.0.0.1:3000'
    Write-Host "`nAdGuard setup page is opening in your browser. Follow Claude's steps, then tell Claude 'done'." -ForegroundColor Green
  } else { Write-Host "`nSomething didn't finish - tell Claude 'done'." -ForegroundColor Yellow }
  Read-Host "Press Enter to close"; exit
}
function Log($m) { $m | Add-Content $log }
try {
  $dir = 'C:\AdGuardHome'
  if (-not (Test-Path "$dir\AdGuardHome.exe")) {
    $zip = "$env:TEMP\AdGuardHome_windows_amd64.zip"
    [Net.ServicePointManager]::SecurityProtocol = 'Tls12'
    Invoke-WebRequest 'https://static.adguard.com/adguardhome/release/AdGuardHome_windows_amd64.zip' -OutFile $zip -UseBasicParsing
    Expand-Archive $zip -DestinationPath 'C:\' -Force
    Log "Downloaded and extracted to $dir"
  }
  $svc = Get-Service AdGuardHome -ErrorAction SilentlyContinue
  if (-not $svc) { & "$dir\AdGuardHome.exe" -s install 2>&1 | Out-String | ForEach-Object { Log $_ } }
  Start-Sleep 5
  $svc = Get-Service AdGuardHome -ErrorAction SilentlyContinue
  Log "Service: $($svc.Status) / $($svc.StartType)"
  if ($svc.Status -eq 'Running') { Log "RESULT: INSTALLED" } else { Log "RESULT: CHECK" }
} catch { Log "ERROR: $($_.Exception.Message)"; Log "RESULT: CHECK" }
