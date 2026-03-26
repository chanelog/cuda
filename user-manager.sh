#!/bin/bash
# ============================================================
#   VPN PANEL - USER MANAGER
#   Kelola user untuk semua protokol
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

PANEL_DIR="/etc/vpn-panel"
USER_DB="$PANEL_DIR/users"

PROTOCOL="${1:-ssh}"

# ==========================================
#   HELPERS
# ==========================================
input() { echo -ne "${WHITE}$1: ${NC}"; read "$2"; }

validate_days() {
  if ! [[ "$1" =~ ^[0-9]+$ ]] || [ "$1" -lt 1 ]; then
    echo -e "${RED}Hari tidak valid!${NC}"; return 1
  fi
}

expiry_date() {
  date -d "+$1 days" '+%Y-%m-%d'
}

days_left() {
  local exp=$1
  local now=$(date +%s)
  local exp_ts=$(date -d "$exp" +%s 2>/dev/null || echo 0)
  echo $(( (exp_ts - now) / 86400 ))
}

# ==========================================
#   SSH USER MANAGEMENT
# ==========================================
add_ssh_user() {
  clear
  echo -e "${CYAN}╔════════════════════════════╗${NC}"
  echo -e "${CYAN}║   TAMBAH USER SSH           ║${NC}"
  echo -e "${CYAN}╚════════════════════════════╝${NC}"
  input "Username" username
  input "Password" password
  input "Masa aktif (hari)" days

  validate_days "$days" || return
  exp=$(expiry_date "$days")

  # Buat user sistem
  if id "$username" &>/dev/null; then
    echo -e "${RED}User '$username' sudah ada!${NC}"
    return
  fi

  useradd -e "$exp" -s /bin/false -M "$username"
  echo "$username:$password" | chpasswd

  # Simpan ke DB
  echo "$username|$password|$exp|ssh" >> "$USER_DB/ssh.db"

  echo -e "\n${GREEN}╔══════════════════════════════════╗${NC}"
  echo -e "${GREEN}║     USER SSH BERHASIL DIBUAT     ║${NC}"
  echo -e "${GREEN}╠══════════════════════════════════╣${NC}"
  echo -e "${GREEN}║${NC} Username  : ${WHITE}$username${NC}"
  echo -e "${GREEN}║${NC} Password  : ${WHITE}$password${NC}"
  echo -e "${GREEN}║${NC} Expired   : ${WHITE}$exp${NC}"
  echo -e "${GREEN}║${NC} Host      : ${WHITE}$(curl -s ifconfig.me)${NC}"
  echo -e "${GREEN}║${NC} Port SSH  : ${WHITE}22, 2222${NC}"
  echo -e "${GREEN}║${NC} Dropbear  : ${WHITE}442, 109${NC}"
  echo -e "${GREEN}║${NC} SSH-WS    : ${WHITE}8880${NC}"
  echo -e "${GREEN}╚══════════════════════════════════╝${NC}"
  echo -e "\nTekan Enter..."; read
}

del_ssh_user() {
  clear
  echo -e "${CYAN}╔════════════════════════════╗${NC}"
  echo -e "${CYAN}║   HAPUS USER SSH            ║${NC}"
  echo -e "${CYAN}╚════════════════════════════╝${NC}"
  list_users_ssh
  input "Username yang dihapus" username

  if ! id "$username" &>/dev/null; then
    echo -e "${RED}User tidak ditemukan!${NC}"; return
  fi

  userdel "$username" 2>/dev/null
  sed -i "/^$username|/d" "$USER_DB/ssh.db" 2>/dev/null
  echo -e "${GREEN}[✓] User '$username' berhasil dihapus${NC}"
  sleep 1
}

list_users_ssh() {
  echo -e "\n${YELLOW}Daftar User SSH:${NC}"
  echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║ No  │ Username       │ Expired    │ Sisa    ║${NC}"
  echo -e "${CYAN}╠══════════════════════════════════════════════╣${NC}"
  
  if [ ! -f "$USER_DB/ssh.db" ] || [ ! -s "$USER_DB/ssh.db" ]; then
    echo -e "${CYAN}║${NC}  Belum ada user SSH                          ${CYAN}║${NC}"
  else
    i=1
    while IFS='|' read -r uname pass exp proto; do
      dl=$(days_left "$exp")
      if [ "$dl" -lt 0 ]; then
        status="${RED}EXPIRED${NC}"
      elif [ "$dl" -le 3 ]; then
        status="${YELLOW}${dl}h lagi${NC}"
      else
        status="${GREEN}${dl}h lagi${NC}"
      fi
      printf "${CYAN}║${NC} %-3s │ %-14s │ %-10s │ " "$i" "$uname" "$exp"
      echo -e "$status ${CYAN}║${NC}"
      i=$((i+1))
    done < "$USER_DB/ssh.db"
  fi
  echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
}

renew_ssh_user() {
  list_users_ssh
  input "Username yang diperbarui" username
  input "Tambah hari" days
  validate_days "$days" || return

  if ! grep -q "^$username|" "$USER_DB/ssh.db"; then
    echo -e "${RED}User tidak ditemukan!${NC}"; return
  fi

  new_exp=$(expiry_date "$days")
  usermod -e "$new_exp" "$username"
  sed -i "s/^$username|[^|]*|[^|]*|/$username|$(grep "^$username|" "$USER_DB/ssh.db" | cut -d'|' -f2)|$new_exp|/" "$USER_DB/ssh.db"
  echo -e "${GREEN}[✓] User '$username' diperpanjang sampai $new_exp${NC}"
  sleep 1
}

# ==========================================
#   XRAY USER MANAGEMENT (VMess/VLESS/Trojan)
# ==========================================
add_xray_user() {
  local PROTO=$1
  local PORT
  local PATH_WS

  case "$PROTO" in
    vmess)  PORT=8443; PATH_WS="/vmess"; TAG="vmess-ws-tls" ;;
    vless)  PORT=2083; PATH_WS="/vless"; TAG="vless-ws-tls" ;;
    trojan) PORT=2087; PATH_WS="/trojan"; TAG="trojan-ws-tls" ;;
  esac

  clear
  echo -e "${CYAN}╔═════════════════════════════════╗${NC}"
  echo -e "${CYAN}║   TAMBAH USER ${PROTO^^}               ║${NC}"
  echo -e "${CYAN}╚═════════════════════════════════╝${NC}"
  input "Username/remarks" username
  input "Masa aktif (hari)" days
  validate_days "$days" || return

  exp=$(expiry_date "$days")
  UUID=$(cat /proc/sys/kernel/random/uuid)
  SERVER_IP=$(curl -s ifconfig.me)

  # Tambah ke xray config
  XRAY_CONF="/etc/xray/config.json"
  
  if [ "$PROTO" = "trojan" ]; then
    # Tambah password trojan ke config
    jq --arg user "$username" --arg pass "$UUID" --arg exp "$exp" \
      '.inbounds[] | select(.tag=="trojan-ws-tls") .settings.clients += [{"password": $pass, "email": ($user + "@" + $exp)}]' \
      "$XRAY_CONF" > /tmp/xray_tmp.json 2>/dev/null
    echo "$username|$UUID|$exp|trojan" >> "$USER_DB/trojan.db"
    DISPLAY_PASS="$UUID"
    DISPLAY_UUID=""
  else
    jq --arg id "$UUID" --arg email "$username@$exp" \
      "(.inbounds[] | select(.tag==\"$TAG\") | .settings.clients) += [{\"id\": \$id, \"alterId\": 0, \"email\": \$email}]" \
      "$XRAY_CONF" > /tmp/xray_tmp.json 2>/dev/null
    [ -s /tmp/xray_tmp.json ] && mv /tmp/xray_tmp.json "$XRAY_CONF"
    echo "$username|$UUID|$exp|$PROTO" >> "$USER_DB/${PROTO}.db"
    DISPLAY_UUID="$UUID"
    DISPLAY_PASS=""
  fi

  systemctl restart xray &>/dev/null

  echo -e "\n${GREEN}╔══════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║    USER ${PROTO^^} BERHASIL DIBUAT           ║${NC}"
  echo -e "${GREEN}╠══════════════════════════════════════════╣${NC}"
  echo -e "${GREEN}║${NC} Remarks  : ${WHITE}$username${NC}"
  [ -n "$DISPLAY_UUID" ] && echo -e "${GREEN}║${NC} UUID     : ${WHITE}$UUID${NC}"
  [ -n "$DISPLAY_PASS" ] && echo -e "${GREEN}║${NC} Password : ${WHITE}$UUID${NC}"
  echo -e "${GREEN}║${NC} Server   : ${WHITE}$SERVER_IP${NC}"
  echo -e "${GREEN}║${NC} Port     : ${WHITE}$PORT${NC}"
  echo -e "${GREEN}║${NC} Path     : ${WHITE}$PATH_WS${NC}"
  echo -e "${GREEN}║${NC} TLS      : ${WHITE}true${NC}"
  echo -e "${GREEN}║${NC} Expired  : ${WHITE}$exp${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
  echo -e "\nTekan Enter..."; read
}

del_xray_user() {
  local PROTO=$1
  list_xray_users "$PROTO"
  input "Username yang dihapus" username

  if ! grep -q "^$username|" "$USER_DB/${PROTO}.db"; then
    echo -e "${RED}User tidak ditemukan!${NC}"; return
  fi

  UUID=$(grep "^$username|" "$USER_DB/${PROTO}.db" | cut -d'|' -f2)
  
  # Hapus dari xray config
  if [ "$PROTO" = "trojan" ]; then
    jq "(.inbounds[] | select(.tag==\"trojan-ws-tls\") | .settings.clients) |= map(select(.password != \"$UUID\"))" \
      /etc/xray/config.json > /tmp/xray_tmp.json && mv /tmp/xray_tmp.json /etc/xray/config.json
  else
    TAG="${PROTO}-ws-tls"
    jq "(.inbounds[] | select(.tag==\"$TAG\") | .settings.clients) |= map(select(.id != \"$UUID\"))" \
      /etc/xray/config.json > /tmp/xray_tmp.json && mv /tmp/xray_tmp.json /etc/xray/config.json
  fi

  sed -i "/^$username|/d" "$USER_DB/${PROTO}.db"
  systemctl restart xray &>/dev/null
  echo -e "${GREEN}[✓] User '$username' dihapus${NC}"
  sleep 1
}

list_xray_users() {
  local PROTO=$1
  echo -e "\n${YELLOW}Daftar User ${PROTO^^}:${NC}"
  echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║ No  │ Username       │ Expired    │ Sisa      ║${NC}"
  echo -e "${CYAN}╠════════════════════════════════════════════════╣${NC}"
  
  DB="$USER_DB/${PROTO}.db"
  if [ ! -f "$DB" ] || [ ! -s "$DB" ]; then
    echo -e "${CYAN}║${NC}  Belum ada user ${PROTO^^}                           ${CYAN}║${NC}"
  else
    i=1
    while IFS='|' read -r uname uuid exp proto; do
      dl=$(days_left "$exp")
      if [ "$dl" -lt 0 ]; then
        status="${RED}EXPIRED${NC}"
      else
        status="${GREEN}${dl}h${NC}"
      fi
      printf "${CYAN}║${NC} %-3s │ %-14s │ %-10s │ " "$i" "$uname" "$exp"
      echo -e "$status          ${CYAN}║${NC}"
      i=$((i+1))
    done < "$DB"
  fi
  echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
}

renew_xray_user() {
  local PROTO=$1
  list_xray_users "$PROTO"
  input "Username yang diperbarui" username
  input "Tambah hari" days
  validate_days "$days" || return

  if ! grep -q "^$username|" "$USER_DB/${PROTO}.db"; then
    echo -e "${RED}User tidak ditemukan!${NC}"; return
  fi

  new_exp=$(expiry_date "$days")
  sed -i "s/^$username|\([^|]*\)|[^|]*|/\$username|\1|$new_exp|/" "$USER_DB/${PROTO}.db"
  echo -e "${GREEN}[✓] User '$username' diperpanjang sampai $new_exp${NC}"
  sleep 1
}

# ==========================================
#   UDP USER / INFO
# ==========================================
udp_menu() {
  clear
  echo -e "${CYAN}╔═══════════════════════════════╗${NC}"
  echo -e "${CYAN}║   UDP CUSTOM & ZIVPN INFO     ║${NC}"
  echo -e "${CYAN}╠═══════════════════════════════╣${NC}"
  SERVER_IP=$(curl -s ifconfig.me)
  echo -e "${CYAN}║${NC} Server IP   : ${WHITE}$SERVER_IP${NC}"
  echo -e "${CYAN}║${NC} UDP Port    : ${WHITE}7300${NC}"
  echo -e "${CYAN}║${NC} UDPGW Port  : ${WHITE}7300${NC}"
  echo -e "${CYAN}║${NC} Protocol    : ${WHITE}UDP Custom / ZiVPN${NC}"
  echo -e "${CYAN}║${NC} Status UDPGW: $(systemctl is-active badvpn-udpgw 2>/dev/null)"
  echo -e "${CYAN}╠═══════════════════════════════╣${NC}"
  echo -e "${CYAN}║${YELLOW}  [1] Restart UDP Service      ${CYAN}║${NC}"
  echo -e "${CYAN}║${YELLOW}  [2] Ganti UDP Port           ${CYAN}║${NC}"
  echo -e "${CYAN}║${YELLOW}  [0] Kembali                  ${CYAN}║${NC}"
  echo -e "${CYAN}╚═══════════════════════════════╝${NC}"
  echo -ne "\nPilih: "; read opt
  case $opt in
    1) systemctl restart badvpn-udpgw udp-custom 2>/dev/null; echo -e "${GREEN}[✓] UDP restarted${NC}"; sleep 1 ;;
    2) input "Port baru" udp_port
       sed -i "s/\"port\": [0-9]*/\"port\": $udp_port/" $PANEL_DIR/config/udp-custom.conf
       systemctl restart udp-custom badvpn-udpgw 2>/dev/null
       echo -e "${GREEN}[✓] UDP port diubah ke $udp_port${NC}"; sleep 1 ;;
    0) return ;;
  esac
}

# ==========================================
#   PROTOCOL MENU ROUTER
# ==========================================
ssh_menu() {
  while true; do
    clear
    echo -e "${CYAN}╔═══════════════════════════╗${NC}"
    echo -e "${CYAN}║   MANAJEMEN USER SSH       ║${NC}"
    echo -e "${CYAN}╠═══════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} [1] Tambah User SSH      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} [2] Hapus User SSH       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} [3] Daftar User SSH      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} [4] Perpanjang User SSH  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} [0] Kembali              ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════╝${NC}"
    echo -ne "\nPilih: "; read opt
    case $opt in
      1) add_ssh_user ;;
      2) del_ssh_user ;;
      3) list_users_ssh; echo -e "\nTekan Enter..."; read ;;
      4) renew_ssh_user ;;
      0) break ;;
    esac
  done
}

xray_proto_menu() {
  PROTO=$1
  while true; do
    clear
    echo -e "${CYAN}╔════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   MANAJEMEN USER ${PROTO^^}           ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} [1] Tambah User ${PROTO^^}         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} [2] Hapus User ${PROTO^^}          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} [3] Daftar User ${PROTO^^}         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} [4] Perpanjang User ${PROTO^^}     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} [0] Kembali                   ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════╝${NC}"
    echo -ne "\nPilih: "; read opt
    case $opt in
      1) add_xray_user "$PROTO" ;;
      2) del_xray_user "$PROTO" ;;
      3) list_xray_users "$PROTO"; echo -e "\nTekan Enter..."; read ;;
      4) renew_xray_user "$PROTO" ;;
      0) break ;;
    esac
  done
}

# ==========================================
#   MAIN
# ==========================================
mkdir -p "$USER_DB"

case "$PROTOCOL" in
  ssh)    ssh_menu ;;
  vmess)  xray_proto_menu vmess ;;
  vless)  xray_proto_menu vless ;;
  trojan) xray_proto_menu trojan ;;
  udp)    udp_menu ;;
  *)      echo -e "${RED}Protokol tidak dikenal: $PROTOCOL${NC}" ;;
esac
