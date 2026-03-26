#!/bin/bash
# ============================================================
#   VPN PANEL - MAIN MENU
#   Dipanggil otomatis saat login sebagai root
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

PANEL_DIR="/etc/vpn-panel"

# Load server info
[ -f "$PANEL_DIR/config/server.info" ] && source "$PANEL_DIR/config/server.info"

get_service_status() {
  local svc=$1
  if systemctl is-active --quiet "$svc" 2>/dev/null; then
    echo -e "${GREEN}● ON${NC}"
  else
    echo -e "${RED}● OFF${NC}"
  fi
}

get_uptime() {
  uptime -p | sed 's/up //'
}

get_cpu() {
  top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1
}

get_ram() {
  free -m | awk 'NR==2{printf "%.0f%%", $3*100/$2}'
}

get_disk() {
  df -h / | awk 'NR==2{print $5}'
}

show_menu() {
  clear
  SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unknown")
  
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${MAGENTA}  ██╗   ██╗██████╗ ███╗   ██╗    ██████╗  █████╗ ███╗   ██╗${CYAN}║${NC}"
  echo -e "${CYAN}║${MAGENTA}  ██║   ██║██╔══██╗████╗  ██║    ██╔══██╗██╔══██╗████╗  ██║${CYAN}║${NC}"
  echo -e "${CYAN}║${MAGENTA}  ██║   ██║██████╔╝██╔██╗ ██║    ██████╔╝███████║██╔██╗ ██║${CYAN}║${NC}"
  echo -e "${CYAN}║${MAGENTA}  ╚██╗ ██╔╝██╔═══╝ ██║╚██╗██║    ██╔═══╝ ██╔══██║██║╚██╗██║${CYAN}║${NC}"
  echo -e "${CYAN}║${MAGENTA}   ╚████╔╝ ██║     ██║ ╚████║    ██║     ██║  ██║██║ ╚████║${CYAN}║${NC}"
  echo -e "${CYAN}║${MAGENTA}    ╚═══╝  ╚═╝     ╚═╝  ╚═══╝    ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝${CYAN}║${NC}"
  echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${NC}"
  echo -e "${CYAN}║${NC} IP: ${WHITE}$SERVER_IP${NC} │ Uptime: ${WHITE}$(get_uptime)${NC}                      ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC} CPU: ${WHITE}$(get_cpu)%${NC} │ RAM: ${WHITE}$(get_ram)${NC} │ Disk: ${WHITE}$(get_disk)${NC}              ${CYAN}║${NC}"
  echo -e "${CYAN}╠═══════════════════════════╦══════════════════════════════╣${NC}"
  echo -e "${CYAN}║${YELLOW} SERVICES STATUS           ${CYAN}║${YELLOW} ALL PROTOCOL PANEL          ${CYAN}║${NC}"
  echo -e "${CYAN}╠═══════════════════════════╬══════════════════════════════╣${NC}"
  echo -e "${CYAN}║${NC} SSH   : $(get_service_status ssh)         ${CYAN}║${WHITE} [1] Kelola User SSH         ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC} Dropbr: $(get_service_status dropbear)         ${CYAN}║${WHITE} [2] Kelola User VMess       ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC} SSH-WS: $(get_service_status ssh-ws)         ${CYAN}║${WHITE} [3] Kelola User VLESS       ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC} Xray  : $(get_service_status xray)         ${CYAN}║${WHITE} [4] Kelola User Trojan      ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC} UDP   : $(get_service_status badvpn-udpgw)         ${CYAN}║${WHITE} [5] Kelola UDP Custom       ${CYAN}║${NC}"
  echo -e "${CYAN}╠═══════════════════════════╬══════════════════════════════╣${NC}"
  echo -e "${CYAN}║${YELLOW} TOOLS                     ${CYAN}║${YELLOW} SYSTEM                      ${CYAN}║${NC}"
  echo -e "${CYAN}╠═══════════════════════════╬══════════════════════════════╣${NC}"
  echo -e "${CYAN}║${WHITE} [6] Speedtest              ${CYAN}║${WHITE} [9]  Restart Semua Service  ${CYAN}║${NC}"
  echo -e "${CYAN}║${WHITE} [7] Info Server            ${CYAN}║${WHITE} [10] Cek Service Status     ${CYAN}║${NC}"
  echo -e "${CYAN}║${WHITE} [8] Setup Domain/TLS       ${CYAN}║${WHITE} [11] Update Panel           ${CYAN}║${NC}"
  echo -e "${CYAN}╠═══════════════════════════╩══════════════════════════════╣${NC}"
  echo -e "${CYAN}║${RED}             [0] Keluar Menu  [99] Reboot VPS           ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
  echo -ne "\n${WHITE}  Pilih Menu: ${NC}"
}

# ==========================================
#   MENU ACTIONS
# ==========================================
run_speedtest() {
  echo -e "\n${YELLOW}[*] Running speedtest...${NC}"
  speedtest-cli --simple 2>/dev/null || speedtest 2>/dev/null || echo -e "${RED}speedtest-cli tidak tersedia${NC}"
  echo -e "\nTekan Enter untuk kembali..."; read
}

show_server_info() {
  clear
  source $PANEL_DIR/config/server.info 2>/dev/null
  echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║          SERVER & PROTOCOL INFORMATION          ║${NC}"
  echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
  echo -e "${CYAN}║${NC} IP Server   : ${WHITE}$SERVER_IP${NC}"
  echo -e "${CYAN}║${NC} Install Date: ${WHITE}$INSTALL_DATE${NC}"
  echo -e "${CYAN}║${NC} OS          : ${WHITE}$OS${NC}"
  echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
  echo -e "${CYAN}║${YELLOW} SSH${NC}"
  echo -e "${CYAN}║${NC}  OpenSSH  : 22, 2222"
  echo -e "${CYAN}║${NC}  Dropbear : 442, 109"
  echo -e "${CYAN}║${NC}  SSH-WS   : 8880"
  echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
  echo -e "${CYAN}║${YELLOW} VMess WS/WSS${NC}"
  echo -e "${CYAN}║${NC}  UUID     : ${WHITE}$VMESS_UUID${NC}"
  echo -e "${CYAN}║${NC}  Port WS  : 80  │ Path: /vmess"
  echo -e "${CYAN}║${NC}  Port WSS : 8443 │ Path: /vmess"
  echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
  echo -e "${CYAN}║${YELLOW} VLESS WSS${NC}"
  echo -e "${CYAN}║${NC}  UUID     : ${WHITE}$VLESS_UUID${NC}"
  echo -e "${CYAN}║${NC}  Port WSS : 2083 │ Path: /vless"
  echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
  echo -e "${CYAN}║${YELLOW} Trojan WSS${NC}"
  echo -e "${CYAN}║${NC}  Password : ${WHITE}$TROJAN_PASS${NC}"
  echo -e "${CYAN}║${NC}  Port WSS : 2087 │ Path: /trojan"
  echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
  echo -e "${CYAN}║${YELLOW} UDP${NC}"
  echo -e "${CYAN}║${NC}  UDP-Custom: 7300 │ UDPGW: 7300"
  echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
  echo -e "\nTekan Enter untuk kembali..."; read
}

setup_domain_tls() {
  clear
  echo -e "${YELLOW}Setup Domain & TLS Certificate${NC}"
  echo -ne "Masukkan domain/subdomain kamu: "
  read DOMAIN
  if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Domain tidak boleh kosong!${NC}"
  else
    echo -e "${CYAN}[*] Meminta sertifikat untuk $DOMAIN...${NC}"
    systemctl stop xray
    ~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone \
      --keylength ec-256 --server letsencrypt
    ~/.acme.sh/acme.sh --installcert -d $DOMAIN \
      --ecc \
      --cert-file /etc/xray/xray.crt \
      --key-file /etc/xray/xray.key \
      --reloadcmd "systemctl restart xray"
    echo "$DOMAIN" > $PANEL_DIR/config/domain
    systemctl start xray
    echo -e "${GREEN}[✓] TLS certificate berhasil dipasang untuk $DOMAIN${NC}"
  fi
  echo -e "\nTekan Enter untuk kembali..."; read
}

restart_services() {
  echo -e "\n${YELLOW}[*] Restarting all services...${NC}"
  systemctl restart ssh dropbear ssh-ws xray badvpn-udpgw udp-custom 2>/dev/null
  echo -e "${GREEN}[✓] Semua service di-restart${NC}"
  sleep 1
}

check_services() {
  clear
  echo -e "${CYAN}╔══════════════════════════════╗${NC}"
  echo -e "${CYAN}║     STATUS SEMUA SERVICE     ║${NC}"
  echo -e "${CYAN}╠══════════════════════════════╣${NC}"
  for svc in ssh dropbear ssh-ws xray badvpn-udpgw udp-custom; do
    STATUS=$(systemctl is-active $svc 2>/dev/null)
    if [ "$STATUS" = "active" ]; then
      echo -e "${CYAN}║${NC} $svc: ${GREEN}● RUNNING${NC}"
    else
      echo -e "${CYAN}║${NC} $svc: ${RED}● STOPPED${NC}"
    fi
  done
  echo -e "${CYAN}╚══════════════════════════════╝${NC}"
  echo -e "\nTekan Enter untuk kembali..."; read
}

# ==========================================
#   MAIN LOOP
# ==========================================
while true; do
  show_menu
  read choice
  case $choice in
    1) vpn-user ssh ;;
    2) vpn-user vmess ;;
    3) vpn-user vless ;;
    4) vpn-user trojan ;;
    5) vpn-user udp ;;
    6) run_speedtest ;;
    7) show_server_info ;;
    8) setup_domain_tls ;;
    9) restart_services ;;
    10) check_services ;;
    11) echo -e "${YELLOW}[*] Updating...${NC}"; cd /root/vpn-panel && git pull 2>/dev/null || echo "Update manual diperlukan"; sleep 2 ;;
    99) echo -e "${RED}Rebooting...${NC}"; reboot ;;
    0) echo -e "${GREEN}Keluar dari menu.${NC}"; break ;;
    *) echo -e "${RED}Pilihan tidak valid!${NC}"; sleep 1 ;;
  esac
done
