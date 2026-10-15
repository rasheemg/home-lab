# Runbook

## Daily: is everything up?

- **Phone:** no ntfy alert means all is well. Alerts fire on any **down** or **recovered** event.
- **Dashboard:** `http://<lab-ip>:3000` shows every service with a live status dot.
- **Uptime Kuma:** `http://<lab-ip>:3001` shows response times and uptime history.

## Service addresses

| Service | URL | Runs on |
|---|---|---|
| Dashboard | `http://<lab-ip>:3000` | Docker (WSL2) |
| Uptime Kuma | `http://<lab-ip>:3001` | Docker (WSL2) |
| Portainer | `https://<lab-ip>:9443` | Docker (WSL2) |
| AdGuard Home | `http://<lab-ip>:3080` | Windows service |
| Plex | `http://<lab-ip>:32400/web` | Windows app |

## Startup behavior

- At login, a hidden launcher starts Ubuntu and keeps it running (`vmIdleTimeout=-1`).
- Docker starts through systemd, and containers use `restart: unless-stopped`.
- AdGuard Home runs as an automatic Windows service.
- Power settings: never sleep on AC.

## Common fixes

| Problem | Fix |
|---|---|
| A container is down | Portainer → Containers → select → **Restart**. Or in Ubuntu: `cd /opt/homelab && docker compose up -d` |
| Whole house has no internet but Wi-Fi is connected | DNS is down. Check that the AdGuard Home service is running (`services.msc`). For a quick bypass, set the router DNS back to automatic. |
| Dashboard shows a service as down | Open that service directly. If it's up, the problem is the dashboard config (`stack/homepage/services.yaml`). |
| Linux side is unresponsive | `wsl --shutdown`, then sign out and back in, or run the startup launcher again |

## Backups

- **Automatic:** every Sunday at 3 AM, or at the next boot if missed. The newest 5 copies are kept.
- **Manual:** run `15-backup` anytime.
- **Location:** `Documents\HomeLab-Backups\homelab-backup-<date>.zip`
- **Contents:**
  - `lab-linux.tgz`: `/opt/homelab` (compose + dashboard config) and the Portainer and Uptime Kuma Docker volumes
  - `AdGuardHome.yaml`: AdGuard settings and filter lists
  - `plex-settings.reg`: Plex server settings
  - `HomeLab-scripts\`: all build scripts

> Backups contain password hashes and config. Keep them private, and never commit them to Git.

## Restore (outline)

1. Rebuild the base: WSL2 + Ubuntu (`02`), Docker (`03`).
2. Extract `lab-linux.tgz` inside Ubuntu as root: `tar xzf lab-linux.tgz -C /` (restores `/opt/homelab` and the Docker volumes), then `cd /opt/homelab && docker compose up -d`.
3. Reinstall AdGuard Home (`10`), stop the service, copy `AdGuardHome.yaml` into `C:\AdGuardHome\`, and start the service.
4. Reinstall Plex, double-click `plex-settings.reg`, and re-add the media folders.
5. Re-apply the firewall rules (`11`, `14`) and auto-start (`06`).
