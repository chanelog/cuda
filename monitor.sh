#!/bin/bash
# ============================================================
#   VPN PANEL - SERVICE MONITOR
#   Dipanggil oleh cron setiap 5 menit
# ============================================================

SERVICES="ssh dropbear ssh-ws xray badvpn-udpgw"
LOG="/var/log/vpn-panel/monitor.log"

for svc in $SERVICES; do
  if ! systemctl is-active --quiet "$svc" 2>/dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [RESTART] $svc" >> "$LOG"
    systemctl restart "$svc" 2>/dev/null
  fi
done
