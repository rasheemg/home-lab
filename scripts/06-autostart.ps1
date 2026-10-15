# HomeLab step 6: keep Linux (and the lab) running, and start it automatically at login.
$log = Join-Path $PSScriptRoot 'step6-log.txt'
"Step 6 started $(Get-Date)" | Set-Content $log
function Log($m) { $m | Add-Content $log; Write-Host $m }

# 1) Never let WSL shut itself down when idle.
$cfg = Join-Path $env:USERPROFILE '.wslconfig'
$c = if (Test-Path $cfg) { Get-Content $cfg -Raw } else { "[wsl2]`r`n" }
if ($c -notmatch 'vmIdleTimeout') { $c = $c -replace '\[wsl2\]\r?\n', "[wsl2]`r`nvmIdleTimeout=-1`r`n" }
if ($c -notmatch '\[general\]') { $c = $c.TrimEnd() + "`r`n`r`n[general]`r`ninstanceIdleTimeout=-1`r`n" }
Set-Content -Path $cfg -Value $c -Encoding ASCII
Log "Updated .wslconfig:`n$c"

# 2) Hidden launcher in your Startup folder: starts Ubuntu at login and keeps it alive.
$startup = [Environment]::GetFolderPath('Startup')
$vbs = Join-Path $startup 'HomeLab-keepalive.vbs'
'CreateObject("WScript.Shell").Run "wsl.exe -d Ubuntu --exec sleep infinity", 0, False' | Set-Content -Path $vbs -Encoding ASCII
Log "Created startup launcher: $vbs"

# 3) Apply now: restart WSL with the new settings and start the keepalive.
wsl.exe --shutdown
Start-Sleep 5
Start-Process wscript.exe -ArgumentList "`"$vbs`""
Start-Sleep 25
$st = (wsl.exe -d Ubuntu -u root -- bash -c "docker ps --format '{{.Names}}  {{.Status}}'" 2>&1 | Out-String) -replace "`0",""
Log "Containers after restart:`n$st"
if ($st -match 'portainer' -and $st -match 'homepage') { Log "RESULT: SUCCESS"; Write-Host "`nLab will now start by itself at login. Tell Claude 'done'." -ForegroundColor Green }
else { Log "RESULT: CHECK"; Write-Host "`nFinished - tell Claude 'done' and it will read the log." -ForegroundColor Yellow }
Read-Host "Press Enter to close"
