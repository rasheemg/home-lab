# HomeLab step 2: install WSL2 + Ubuntu, with a memory cap so Plex and Windows stay fast.
# Needs admin (Windows will ask "Allow changes?" - click Yes). A restart is required afterwards.
$log = Join-Path $PSScriptRoot 'step2-log.txt'
"Step 2 started $(Get-Date)" | Set-Content $log

# 1) Memory cap for the Linux side: this laptop has 8 GB, so give Linux 3 GB + 4 GB swap.
$cfg = Join-Path $env:USERPROFILE '.wslconfig'
@"
[wsl2]
memory=3GB
processors=4
swap=4GB
"@ | Set-Content -Path $cfg -Encoding ASCII
"Wrote $cfg (memory=3GB, processors=4, swap=4GB)" | Add-Content $log

# 2) Install WSL2 + Ubuntu (elevated).
Write-Host "Installing WSL2 + Ubuntu. Click YES on the Windows prompt..." -ForegroundColor Cyan
$p = Start-Process -FilePath 'wsl.exe' -ArgumentList '--install','-d','Ubuntu','--no-launch' -Verb RunAs -Wait -PassThru
"wsl --install exit code: $($p.ExitCode)" | Add-Content $log

if ($p.ExitCode -eq 0) {
  "Install command finished OK. Restart required." | Add-Content $log
  Write-Host "`nDone. RESTART this laptop now, then tell Claude 'restarted'." -ForegroundColor Green
} else {
  "Install did not finish cleanly." | Add-Content $log
  Write-Host "`nSomething went wrong (exit code $($p.ExitCode)). Tell Claude." -ForegroundColor Yellow
}
Read-Host "Press Enter to close"
