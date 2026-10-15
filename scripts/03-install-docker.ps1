# HomeLab step 3: install Docker Engine inside Ubuntu (no Docker Desktop - saves ~2 GB RAM).
# Runs as root inside Ubuntu, so it never asks for your Linux password.
$log = Join-Path $PSScriptRoot 'step3-log.txt'
"Step 3 started $(Get-Date)" | Set-Content $log
function Log($m) { $m | Add-Content $log; Write-Host $m }

# 0) Is Ubuntu installed and has a user been created?
$distros = ((wsl.exe -l -v) -join "`n") -replace "`0",""
Log "WSL distros:`n$distros"
$linuxUser = ((wsl.exe -d Ubuntu -- whoami) -join "") -replace "`0",""
$linuxUser = $linuxUser.Trim()
Log "Default Linux user: '$linuxUser'"
if (-not $linuxUser -or $linuxUser -eq 'root') {
  Log "NO_LINUX_USER: open 'Ubuntu' from the Start menu once and create your username/password, then run this again."
  Read-Host "Press Enter to close"; exit 1
}

# 1) Let devices on your Wi-Fi reach lab services (needed for Pi-hole, dashboards on your phone).
$cfg = Join-Path $env:USERPROFILE '.wslconfig'
$c = Get-Content $cfg -Raw
if ($c -notmatch 'networkingMode') { Add-Content $cfg "networkingMode=mirrored`r`n"; Log "Added networkingMode=mirrored to .wslconfig" }

# 2) Inside Ubuntu: enable systemd (so Docker starts by itself), install Docker, add your user.
$bash = @"
set -e
grep -q 'systemd=true' /etc/wsl.conf 2>/dev/null || printf '[boot]\nsystemd=true\n' >> /etc/wsl.conf
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq ca-certificates curl git >/dev/null
if ! command -v docker >/dev/null; then curl -fsSL https://get.docker.com | sh >/dev/null; fi
usermod -aG docker $linuxUser
mkdir -p /opt/homelab && chown ${linuxUser}: /opt/homelab
docker --version
docker compose version
"@ -replace "`r",""
$sh = Join-Path $PSScriptRoot 'step3.sh'
[IO.File]::WriteAllText($sh, $bash + "`n")
$shLinux = '/mnt/c' + ($sh.Substring(2) -replace '\\','/')
Log "Installing Docker inside Ubuntu (2-5 minutes)..."
$out = (wsl.exe -d Ubuntu -u root -- bash $shLinux 2>&1 | Out-String) -replace "`0",""
Log $out
Log "install exit code: $LASTEXITCODE"

# 3) Restart WSL so systemd + mirrored networking take effect, then test Docker.
wsl.exe --shutdown
Start-Sleep 8
$test = (wsl.exe -d Ubuntu -u root -- bash -c "systemctl is-active docker; docker run --rm hello-world 2>&1 | head -3" 2>&1 | Out-String) -replace "`0",""
Log "TEST:`n$test"
if ($test -match 'Hello from Docker') { Log "RESULT: SUCCESS"; Write-Host "`nDocker is working. Tell Claude 'done'." -ForegroundColor Green }
else { Log "RESULT: CHECK"; Write-Host "`nFinished, but the test didn't pass. Tell Claude 'done' - it will read the log." -ForegroundColor Yellow }
Read-Host "Press Enter to close"
