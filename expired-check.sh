#!/bin/bash
# ============================================================
#   VPN PANEL - EXPIRED USER CHECKER
#   Dipanggil cron setiap hari tengah malam
# ============================================================

PANEL_DIR="/etc/vpn-panel"
USER_DB="$PANEL_DIR/users"
LOG="/var/log/vpn-panel/expired.log"
TODAY=$(date '+%Y-%m-%d')

echo "$(date '+%Y-%m-%d %H:%M:%S') === Expired check start ===" >> "$LOG"

# Check SSH users
if [ -f "$USER_DB/ssh.db" ]; then
  while IFS='|' read -r uname pass exp proto; do
    if [[ "$exp" < "$TODAY" ]]; then
      userdel "$uname" 2>/dev/null
      sed -i "/^$uname|/d" "$USER_DB/ssh.db"
      echo "$(date '+%Y-%m-%d %H:%M:%S') [DELETED] SSH user: $uname (exp: $exp)" >> "$LOG"
    fi
  done < "$USER_DB/ssh.db"
fi

# Check VMess users
for PROTO in vmess vless trojan; do
  DB="$USER_DB/${PROTO}.db"
  if [ -f "$DB" ]; then
    while IFS='|' read -r uname uuid exp proto; do
      if [[ "$exp" < "$TODAY" ]]; then
        # Remove from xray config
        if [ "$PROTO" = "trojan" ]; then
          jq "(.inbounds[] | select(.tag==\"trojan-ws-tls\") | .settings.clients) |= map(select(.password != \"$uuid\"))" \
            /etc/xray/config.json > /tmp/xray_clean.json && mv /tmp/xray_clean.json /etc/xray/config.json
        else
          TAG="${proto}-ws-tls"
          jq "(.inbounds[] | select(.tag==\"$TAG\") | .settings.clients) |= map(select(.id != \"$uuid\"))" \
            /etc/xray/config.json > /tmp/xray_clean.json && mv /tmp/xray_clean.json /etc/xray/config.json
        fi
        sed -i "/^$uname|/d" "$DB"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [DELETED] ${PROTO^^} user: $uname (exp: $exp)" >> "$LOG"
      fi
    done < "$DB"
  fi
done

# Restart xray if any changes
systemctl restart xray 2>/dev/null
echo "$(date '+%Y-%m-%d %H:%M:%S') === Expired check done ===" >> "$LOG"
