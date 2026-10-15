# HomeLab step 4: start the core stack - dashboard, Portainer, Uptime Kuma.
$log = Join-Path $PSScriptRoot 'step4-log.txt'
"Step 4 started $(Get-Date)" | Set-Content $log
function Log($m) { $m | Add-Content $log; Write-Host $m }

$src = '/mnt/c/Users/Sheem/Documents/HomeLab/stack'
$bash = @"
set -e
mkdir -p /opt/homelab
cp -r $src/. /opt/homelab/
chown -R sheem: /opt/homelab
cd /opt/homelab
docker compose pull -q
docker compose up -d
sleep 15
docker compose ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}'
echo '--- checks ---'
for u in http://localhost:3000 http://localhost:3001 ; do printf '%s -> ' `$u; curl -s -o /dev/null -w '%{http_code}\n' `$u || echo fail; done
printf 'https://localhost:9443 -> '; curl -sk -o /dev/null -w '%{http_code}\n' https://localhost:9443 || echo fail
free -m | head -2
"@ -replace "`r",""
$sh = Join-Path $PSScriptRoot 'step4.sh'
[IO.File]::WriteAllText($sh, $bash + "`n")
Log "Downloading and starting containers (2-4 minutes)..."
$out = (wsl.exe -d Ubuntu -u root -- bash /mnt/c/Users/Sheem/Documents/HomeLab/step4.sh 2>&1 | Out-String) -replace "`0",""
Log $out
Log "exit code: $LASTEXITCODE"
if ($out -match 'localhost:3000 -> 200') {
  Log "RESULT: SUCCESS"
  Write-Host "`nYour lab is up! Opening the dashboard..." -ForegroundColor Green
  Start-Process 'http://localhost:3000'
} else { Log "RESULT: CHECK"; Write-Host "`nFinished - tell Claude 'done' and it will read the log." -ForegroundColor Yellow }
Read-Host "Press Enter to close"
