# Security Audit & Hardening Report

**System:** Lab laptop (Windows 11 Home + WSL2 Ubuntu + Docker)
**Audit date:** October 14, 2026
**Method:** [`13-security-audit.ps1`](../scripts/13-security-audit.ps1) is read-only and makes no changes. Fixes were applied separately with [`14-hardening.ps1`](../scripts/14-hardening.ps1) and [`16-fix-monitoring.ps1`](../scripts/16-fix-monitoring.ps1), then re-checked.

## Scope

| Area | What was checked |
|---|---|
| Endpoint protection | Defender status, real-time protection, signature age, other registered AV |
| Firewall | Profiles enabled, custom inbound allow rules, Hyper-V (WSL) firewall rules |
| Exposure | Listening TCP/UDP ports on Windows and Linux, network profile |
| Remote access | RDP, SMB shares, SMBv1 |
| Identity | Local accounts, Administrators group membership, auto-logon |
| Data protection | BitLocker / device encryption |
| Patching | Recent Windows updates, pending Ubuntu updates |
| Containers | Published ports, containers with the Docker socket mounted (and read/write access) |
| Persistence | Startup items |

## Results: passed

| Control | Result |
|---|---|
| Microsoft Defender | Enabled, real-time protection on, signatures updated the same day |
| Firewall | Enabled on Domain, Private and Public profiles |
| Disk encryption | BitLocker: fully encrypted, protection on |
| Remote Desktop | Disabled |
| SMBv1 | Disabled |
| Built-in Administrator / Guest | Disabled |
| Auto-logon | Not configured |
| Windows Update | Current |

## Findings & remediation

| # | Finding | Severity | Remediation | Evidence after fix |
|---|---|---|---|---|
| 1 | 112 pending Ubuntu package updates | High | `apt-get update && apt-get upgrade` (non-interactive, keep existing configs) | `pending after: 0` |
| 2 | Hyper-V firewall rule still allowed ports 53 and 8080 into Linux after Pi-hole was retired | Medium | Removed and rebuilt the rule: TCP 3000, 3001, 9443 only, source `192.168.1.0/24` only | Rule shows `{3000, 3001, 9443}` / `192.168.1.0/255.255.255.0` |
| 3 | Dashboard container unreachable (port 3000 conflict with AdGuard's setup wizard) | Medium | Moved AdGuard admin to 3080, recreated dashboard container | `dashboard http -> 200`, container `healthy` |
| 4 | No backup of lab configuration | Medium | Weekly scheduled backup, 5-copy retention | First backup created and verified |
| 5 | Monitoring blind to Windows-hosted services (container network isolation) | Medium | Tested host networking in a throwaway container first, then switched the monitoring containers | 5/5 monitors up, alerts confirmed on phone |
| 6 | AdGuard config readable only by admins, so it was skipped by the backup | Low | Weekly task running as SYSTEM copies the config into the backup folder | Copy present, included in later backups |

## Accepted risks / next steps

| Item | Notes |
|---|---|
| Portainer has read/write access to the Docker socket | This is required for Portainer to manage containers. Mitigated by LAN-only firewall access and a strong admin password. The dashboard's socket mount is read-only. |
| Plex firewall rules allow any source | These are created by the Plex installer and needed for remote streaming. Review whether remote access is actually used. |
| Second antivirus product (McAfee) installed alongside Defender | Defender is the active AV. Plan to uninstall McAfee to reduce attack surface and background load. |
| Daily-use account is a local admin | Common on home PCs. A future step is a separate standard user for daily use. |
| Backups are stored on the same disk | They protect against misconfiguration, not disk failure. Next step is copying them to external or cloud storage. |
| Monitoring runs on the same machine it watches | It can't alert if the whole laptop goes down. Next step is an external "heartbeat" check. |

## Principles followed

- **Audit first, change second:** the audit script is read-only, so it's safe to run anytime.
- **Least exposure:** every opened port is limited to the home subnet and, on Windows, to the specific program.
- **Test before you change production:** the networking fix was proven in a disposable container before touching the running services.
- **Verify with evidence:** every fix logs before/after output instead of assuming it worked.
