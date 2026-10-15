# Troubleshooting Log

These are real problems I hit while building the lab, how I narrowed each one down, and what fixed it.

## 1. Pi-hole ran fine, but no device could use it for DNS

**Symptom:** Pi-hole's container was healthy and answered DNS on the laptop itself, but phones on Wi-Fi got no answers.

**Diagnosis:**
1. Port 53 was already taken by Ubuntu's `systemd-resolved`. I freed it, but that didn't fix the problem.
2. I confirmed the firewall rules allowed UDP/TCP 53 from the home subnet.
3. **Packet capture:** I ran `tcpdump` on port 53 inside Linux for 2 minutes while a phone made DNS lookups. The result was **0 packets captured**, so the queries never reached Linux at all. WSL2's mirrored networking mode was dropping inbound DNS from other devices before it reached the VM.

**Fix:** I changed the architecture instead of fighting the platform. I replaced Pi-hole with **AdGuard Home running natively on Windows** as a service, with firewall rules scoped to the AdGuard program, ports 53/3080 and the local subnet.

**Lesson:** When a service "should" work, measure where the traffic stops before changing configuration.

## 2. Dashboard went down after installing AdGuard

**Symptom:** The Homepage dashboard on port 3000 stopped responding.

**Cause:** AdGuard's first-run setup wizard binds port 3000, which collided with the dashboard.

**Fix:** I moved AdGuard's admin interface to **3080**, restarted AdGuard to release 3000, and recreated the dashboard container. I also documented a port map:

| Port | Service |
|---|---|
| 53 | AdGuard DNS |
| 3000 | Homepage dashboard |
| 3001 | Uptime Kuma |
| 3080 | AdGuard admin |
| 9443 | Portainer (HTTPS) |
| 32400 | Plex |

## 3. Router DNS setting wasn't where expected

**Symptom:** The Verizon router's LAN/network pages had no DNS server field.

**Fix:** The setting was under **Network Connections → Broadband Connection → Settings → IPv4 DNS**. I also:
- gave the lab laptop a **DHCP reservation** so its IP never changes (if it did, the whole house would lose DNS)
- disabled IPv6 DNS handout so devices couldn't bypass the blocker over IPv6

## 4. Monitoring couldn't see Plex or AdGuard

**Symptom:** Uptime Kuma (in a Docker container) got `ECONNREFUSED` for Plex and AdGuard, even though both were running.

**Diagnosis:** I ran a reachability test from inside the monitoring container. Services in other containers worked, but services on the Windows host were refused. Docker's bridge network isolates containers from the host.

**Fix:**
1. I ran a **throwaway container on the host network** and tested `127.0.0.1` and the LAN IP. Loopback worked and the LAN IP didn't.
2. Only after the test passed did the script switch the monitoring and dashboard containers to `network_mode: host` and point health checks at `127.0.0.1`. The change was automatic and conditional: if the test failed, nothing would change.

## 5. Laptop stopped charging at a fixed percentage

**Symptom:** The battery stuck below 100%, even with a different charger and port.

**Diagnosis:** A Windows battery report compared full-charge capacity against design capacity and charge cycles. It showed a worn battery, not a charger or software problem.

**Fix:** I reset the charging controller (BIOS "Disable Built-in Battery") and kept the laptop on AC power. A replacement battery is planned. This matters for a server because a healthy battery acts as a mini UPS during power blips.

## 6. Scripted file pushes didn't always land

**Symptom:** An updated script sometimes still ran the old version.

**Fix:** After every copy, I verified **file size and content** on the target before running anything. The lesson is not to trust a "success" message and to check the result.
