# HomeLab step 16: fix what step 15 found.
#  A) Uptime Kuma + dashboard can't see Plex/AdGuard (they run on Windows, the containers were walled off).
#     Test a fix first; ONLY if the test passes, switch those two containers to share the laptop's network.
#  B) AdGuard's settings file is admin-only, so the backup couldn't copy it. Add a small weekly
#     Windows task (runs as SYSTEM) that copies it into HomeLab-Backups\adguard-copy for the backup to pick up.
param([switch]$Elevated)
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\Sheem\Documents\HomeLab\step16-log.txt'
function Log($m) { $m | Add-Content $log; Write-Host $m }
if (-not $Elevated) {
  "Step 16 started $(Get-Date)" | Set-Content $log
  $bash = @'
set +e
cd /opt/homelab
echo '--- A) test from the laptop network ---'
docker run --rm --network host --entrypoint node -e NODE_NO_WARNINGS=1 -e NODE_TLS_REJECT_UNAUTHORIZED=0 louislam/uptime-kuma:2 -e '
const t=[];for(const h of ["127.0.0.1","192.168.1.158"]){t.push(["Plex",h,"http://"+h+":32400/identity"]);t.push(["AdGuard",h,"http://"+h+":3080"]);}
(async()=>{for(const [n,h,u] of t){try{const r=await fetch(u,{signal:AbortSignal.timeout(5000)});console.log("OK|"+n+"|"+h+"|"+r.status)}catch(e){console.log("FAIL|"+n+"|"+h+"|"+(e.cause&&e.cause.code?e.cause.code:e.message))}}
for(const h of ["127.0.0.1","192.168.1.158"]){const R=new (require("dns").promises.Resolver)();R.setServers([h]);try{console.log("OK|DNS|"+h+"|"+(await R.resolve4("google.com"))[0])}catch(e){console.log("FAIL|DNS|"+h+"|"+e.code)}}})()' > /tmp/t16.txt 2>&1
cat /tmp/t16.txt
H=""
for h in 127.0.0.1 192.168.1.158; do
  if grep -q "^OK|Plex|$h|" /tmp/t16.txt && grep -q "^OK|AdGuard|$h|" /tmp/t16.txt; then H=$h; break; fi
done
if [ -z "$H" ]; then echo "RESULT A: test did not pass - nothing changed"; exit 0; fi
echo "RESULT A: test passed using $H - switching dashboard + Uptime Kuma"
cp /mnt/c/Users/Sheem/Documents/HomeLab/stack/docker-compose.host.yml /opt/homelab/docker-compose.yml
sed -i "s#siteMonitor: http://192.168.1.158:#siteMonitor: http://$H:#" /opt/homelab/homepage/services.yaml
docker compose up -d 2>&1 | tail -5
sleep 20
docker ps --format '{{.Names}} | {{.Status}}'
for u in http://localhost:3000 http://localhost:3001; do printf '%s -> ' $u; curl -s -o /dev/null -w '%{http_code}\n' $u; done
cp /opt/homelab/docker-compose.yml /mnt/c/Users/Sheem/Documents/HomeLab/stack/docker-compose.yml
cp /opt/homelab/homepage/services.yaml /mnt/c/Users/Sheem/Documents/HomeLab/stack/homepage/services.yaml
echo "MONITOR HOST: $H"
'@
  $sh = 'C:\Users\Sheem\Documents\HomeLab\step16.sh'
  [IO.File]::WriteAllText($sh, ($bash -replace "`r","") + "`n")
  Write-Host "A) Testing and fixing monitoring (1-2 minutes)..." -ForegroundColor Cyan
  $o = (wsl.exe -d Ubuntu -u root -- bash /mnt/c/Users/Sheem/Documents/HomeLab/step16.sh 2>&1 | Out-String) -replace "`0",""
  Log $o
  Write-Host "B) Setting up the AdGuard settings copy. Click YES on the Windows prompt..." -ForegroundColor Cyan
  Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Elevated"
  Write-Host "`nDone - tell Claude 'done'." -ForegroundColor Green
  Read-Host "Press Enter to close"; exit
}
try {
  $dst = 'C:\Users\Sheem\Documents\HomeLab-Backups\adguard-copy'
  $cmd = "New-Item -ItemType Directory '$dst' -Force | Out-Null; Copy-Item 'C:\AdGuardHome\AdGuardHome.yaml' '$dst' -Force"
  $act = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -Command `"$cmd`""
  $trg = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At '2:50am'
  $pri = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
  $set = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
  Register-ScheduledTask -TaskName 'HomeLab AdGuard Settings Copy' -Action $act -Trigger $trg -Principal $pri -Settings $set -Force -ErrorAction Stop | Out-Null
  Start-ScheduledTask -TaskName 'HomeLab AdGuard Settings Copy'
  Start-Sleep 8
  Log ("B) AdGuard copy task: ok. Copy present now: " + (Test-Path "$dst\AdGuardHome.yaml"))
} catch { Log "B) ERROR: $($_.Exception.Message)" }
