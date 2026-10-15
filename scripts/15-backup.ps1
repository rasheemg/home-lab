# HomeLab step 15: BACKUP your lab settings + test what Uptime Kuma can reach.
#  - Saves one zip to Documents\HomeLab-Backups (keeps the newest 5).
#  - Includes: HomeLab scripts, dashboard/Portainer/Uptime Kuma data, AdGuard settings, Plex settings + Plex's own newest library backup.
#  - Sets up an automatic weekly backup (Sundays 3 AM, or next time the laptop is on).
#  - Changes nothing else. No admin prompt needed.
#  NOTE: the zip contains your lab's settings (and password hashes). Keep it private - never upload it to GitHub.
param([switch]$Quiet)
$ErrorActionPreference = 'Continue'
$bk  = 'C:\Users\Sheem\Documents\HomeLab-Backups'
$stg = "$bk\staging"
$log = 'C:\Users\Sheem\Documents\HomeLab\step15-log.txt'
$stamp = Get-Date -Format 'yyyy-MM-dd_HHmm'
function Log($m) { $m | Add-Content $log; if (-not $Quiet) { Write-Host $m } }
"Step 15 (backup) started $(Get-Date)" | Set-Content $log
New-Item -ItemType Directory $bk -Force | Out-Null
Remove-Item $stg -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $stg -Force | Out-Null

$bash = @'
set +e
cd /opt/homelab
echo '--- what Uptime Kuma can reach ---'
docker exec -e NODE_TLS_REJECT_UNAUTHORIZED=0 uptime-kuma node -e '
const t=[["Plex","http://192.168.1.158:32400/identity"],["AdGuard admin","http://192.168.1.158:3080"],["Dashboard by name","http://homepage:3000"],["Portainer by name","https://portainer:9443"],["Dashboard by LAN IP","http://192.168.1.158:3000"]];
(async()=>{for(const [n,u] of t){try{const r=await fetch(u,{signal:AbortSignal.timeout(5000)});console.log(n+" | "+u+" | "+r.status)}catch(e){console.log(n+" | "+u+" | FAIL "+(e.cause&&e.cause.code?e.cause.code:e.message))}}
const R=new (require("dns").promises.Resolver)();R.setServers(["192.168.1.158"]);
try{console.log("AdGuard DNS | 192.168.1.158:53 | "+(await R.resolve4("google.com"))[0])}catch(e){console.log("AdGuard DNS | 192.168.1.158:53 | FAIL "+e.code)}})()' 2>&1
echo '--- backing up Linux side ---'
VOLS=$(docker volume ls -q | grep -E 'portainer_data|uptime_kuma_data' | sed 's#^#var/lib/docker/volumes/#')
echo "volumes: $VOLS"
docker compose stop uptime-kuma portainer >/dev/null 2>&1
tar czf /tmp/lab-linux.tgz -C / opt/homelab $VOLS
echo "tar exit: $?"
docker compose start uptime-kuma portainer >/dev/null 2>&1
cp /tmp/lab-linux.tgz /mnt/c/Users/Sheem/Documents/HomeLab-Backups/staging/ && rm -f /tmp/lab-linux.tgz
echo "linux backup bytes: $(stat -c %s /mnt/c/Users/Sheem/Documents/HomeLab-Backups/staging/lab-linux.tgz 2>/dev/null)"
sleep 5
docker ps --format '{{.Names}} | {{.Status}}'
'@
$sh = 'C:\Users\Sheem\Documents\HomeLab\step15.sh'
[IO.File]::WriteAllText($sh, ($bash -replace "`r","") + "`n")
if (-not $Quiet) { Write-Host "Testing monitors and backing up (1-3 minutes)..." -ForegroundColor Cyan }
$o = (wsl.exe -d Ubuntu -u root -- bash /mnt/c/Users/Sheem/Documents/HomeLab/step15.sh 2>&1 | Out-String) -replace "`0",""
Log $o

Log '--- backing up Windows side ---'
try { Copy-Item 'C:\Users\Sheem\Documents\HomeLab' "$stg\HomeLab-scripts" -Recurse -ErrorAction Stop; Log 'HomeLab scripts: ok' } catch { Log "HomeLab scripts: FAIL $($_.Exception.Message)" }
try { Copy-Item 'C:\Users\Sheem\Documents\HomeLab-Backups\adguard-copy\AdGuardHome.yaml' $stg -ErrorAction Stop; Log 'AdGuard settings: ok' } catch { Log "AdGuard settings: FAIL $($_.Exception.Message)" }
reg.exe export 'HKCU\Software\Plex, Inc.\Plex Media Server' "$stg\plex-settings.reg" /y 2>&1 | Out-Null
Log ("Plex settings: " + $(if (Test-Path "$stg\plex-settings.reg") {'ok'} else {'FAIL'}))
$pdb = "$env:LOCALAPPDATA\Plex Media Server\Plug-in Support\Databases"
$latest = Get-ChildItem $pdb -Filter 'com.plexapp.plugins.library.db-20*' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($latest) { Copy-Item $latest.FullName $stg; Log "Plex library backup: ok ($($latest.Name))" } else { Log 'Plex library backup: none yet (Plex makes one every few days - fine)' }

$zip = "$bk\homelab-backup-$stamp.zip"
try {
  Compress-Archive -Path "$stg\*" -DestinationPath $zip -Force -ErrorAction Stop
  Log ("ZIP: $zip  ({0:N1} MB)" -f ((Get-Item $zip).Length / 1MB))
} catch { Log "ZIP: FAIL $($_.Exception.Message)" }
Remove-Item $stg -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem $bk -Filter 'homelab-backup-*.zip' | Sort-Object Name -Descending | Select-Object -Skip 5 | Remove-Item -Force
Log ("Backups kept: " + ((Get-ChildItem $bk -Filter 'homelab-backup-*.zip').Count))

if (-not $Quiet) {
  try {
    $act = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Quiet"
    $trg = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am
    $set = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName 'HomeLab Weekly Backup' -Action $act -Trigger $trg -Settings $set -Force -ErrorAction Stop | Out-Null
    Log 'Weekly backup task: ok (Sundays 3 AM)'
  } catch { Log "Weekly backup task: FAIL $($_.Exception.Message)" }
  Write-Host "`nDone - tell Claude 'done'." -ForegroundColor Green
  Read-Host "Press Enter to close"
}
