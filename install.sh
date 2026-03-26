#!/bin/bash
# ============================================================
#   VPN PANEL - ALL PROTOCOL INSTALLER
#   Support: Ubuntu 18/20/22/24 | Debian 9/10/11/12
#   Protocols: SSH, VMess, VLESS, Trojan, UDP Custom, ZiVPN
# ============================================================

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

PANEL_DIR="/etc/vpn-panel"
BIN_DIR="/usr/local/bin"
LOG_DIR="/var/log/vpn-panel"

# --- Banner ---
show_banner() {
  clear
  echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${WHITE}        VPN PANEL - ALL PROTOCOL INSTALLER           ${CYAN}║${NC}"
  echo -e "${CYAN}║${YELLOW}     SSH • VMess • VLESS • Trojan • UDP • WS+TLS     ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
  echo ""
}

# --- OS Check ---
check_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
  else
    echo -e "${RED}[ERROR] OS tidak dapat dideteksi!${NC}"
    exit 1
  fi

  case "$OS" in
    ubuntu)
      PKG="apt-get"
      echo -e "${GREEN}[✓] Detected: Ubuntu $VER${NC}"
      ;;
    debian)
      PKG="apt-get"
      echo -e "${GREEN}[✓] Detected: Debian $VER${NC}"
      ;;
    *)
      echo -e "${RED}[ERROR] OS $OS tidak didukung. Hanya Ubuntu & Debian.${NC}"
      exit 1
      ;;
  esac
}

# --- Root Check ---
check_root() {
  if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}[ERROR] Harus dijalankan sebagai root!${NC}"
    echo -e "${YELLOW}Gunakan: sudo bash install.sh${NC}"
    exit 1
  fi
}

# --- Install Dependencies ---
install_deps() {
  echo -e "\n${YELLOW}[*] Installing dependencies...${NC}"
  $PKG update -y &>/dev/null
  $PKG install -y \
    curl wget unzip jq uuid-runtime \
    net-tools iptables cron \
    openssl ca-certificates gnupg lsb-release \
    python3 python3-pip \
    screenfetch neofetch \
    htop speedtest-cli \
    socat netcat-openbsd &>/dev/null
  echo -e "${GREEN}[✓] Dependencies installed${NC}"
}

# --- Prepare Directories ---
prepare_dirs() {
  mkdir -p $PANEL_DIR/{config,users,certs,bin,logs}
  mkdir -p $LOG_DIR
  echo -e "${GREEN}[✓] Directories prepared${NC}"
}

# ==========================================
#   INSTALL SSH (OpenSSH + Dropbear)
# ==========================================
install_ssh() {
  echo -e "\n${YELLOW}[*] Installing SSH (OpenSSH + Dropbear)...${NC}"

  # OpenSSH
  $PKG install -y openssh-server &>/dev/null

  # Dropbear
  $PKG install -y dropbear &>/dev/null

  # Configure OpenSSH
  cat > /etc/ssh/sshd_config << 'EOF'
Port 22
Port 2222
AddressFamily any
ListenAddress 0.0.0.0
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin yes
MaxAuthTries 3
PubkeyAuthentication yes
PasswordAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

  # Configure Dropbear
  cat > /etc/default/dropbear << 'EOF'
NO_START=0
DROPBEAR_PORT=442
DROPBEAR_EXTRA_ARGS="-p 109"
DROPBEAR_BANNER="/etc/vpn-panel/config/banner.txt"
DROPBEAR_RECEIVE_WINDOW=65536
EOF

  # SSH over WebSocket (Python-based)
  cat > /usr/local/bin/ssh-ws << 'EOF'
#!/usr/bin/env python3
import asyncio, websockets, socket, threading

LISTEN_PORT = 8880
SSH_HOST = "127.0.0.1"
SSH_PORT = 22

async def handler(ws, path):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((SSH_HOST, SSH_PORT))
    sock.setblocking(False)
    loop = asyncio.get_event_loop()
    async def ws_to_sock():
        try:
            async for msg in ws:
                await loop.sock_sendall(sock, msg if isinstance(msg, bytes) else msg.encode())
        except: pass
    async def sock_to_ws():
        try:
            while True:
                data = await loop.sock_recv(sock, 4096)
                if not data: break
                await ws.send(data)
        except: pass
    await asyncio.gather(ws_to_sock(), sock_to_ws())
    sock.close()

asyncio.get_event_loop().run_until_complete(
    websockets.serve(handler, "0.0.0.0", LISTEN_PORT)
)
asyncio.get_event_loop().run_forever()
EOF
  chmod +x /usr/local/bin/ssh-ws
  pip3 install websockets &>/dev/null

  # SSH-WS systemd service
  cat > /etc/systemd/system/ssh-ws.service << 'EOF'
[Unit]
Description=SSH over WebSocket
After=network.target

[Service]
ExecStart=/usr/local/bin/ssh-ws
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable ssh ssh-ws dropbear &>/dev/null
  systemctl restart ssh dropbear ssh-ws &>/dev/null
  echo -e "${GREEN}[✓] SSH (OpenSSH:22,2222 | Dropbear:442,109 | WS:8880) installed${NC}"
}

# ==========================================
#   INSTALL XRAY (VMess, VLESS, Trojan)
# ==========================================
install_xray() {
  echo -e "\n${YELLOW}[*] Configuring Xray-core (VMess/VLESS/Trojan)...${NC}"

  # Binary sudah diinstall oleh download-bins.sh
  if [ ! -f "/usr/local/bin/xray" ]; then
    echo -e "${RED}[ERROR] xray binary tidak ditemukan!${NC}"; exit 1
  fi

  # Generate UUIDs
  UUID_VMESS=$(cat /proc/sys/kernel/random/uuid)
  UUID_VLESS=$(cat /proc/sys/kernel/random/uuid)
  UUID_TROJAN=$(openssl rand -hex 16)

  mkdir -p /etc/xray

  # Save UUIDs
  cat > $PANEL_DIR/config/xray-uuid.conf << EOF
VMESS_UUID=$UUID_VMESS
VLESS_UUID=$UUID_VLESS
TROJAN_PASS=$UUID_TROJAN
EOF

  # Generate self-signed cert (if no real cert)
  if [ ! -f /etc/xray/xray.crt ]; then
    openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
      -subj "/C=ID/ST=Jakarta/L=Jakarta/O=VPN/CN=vpn.local" \
      -keyout /etc/xray/xray.key \
      -out /etc/xray/xray.crt &>/dev/null
    echo -e "${YELLOW}  [!] Self-signed cert generated. Use acme.sh for real TLS.${NC}"
  fi

  # Xray Config
  cat > /etc/xray/config.json << EOF
{
  "log": { "loglevel": "warning", "access": "/var/log/xray-access.log", "error": "/var/log/xray-error.log" },
  "inbounds": [
    {
      "port": 8443, "protocol": "vmess", "tag": "vmess-ws-tls",
      "settings": { "clients": [{ "id": "$UUID_VMESS", "alterId": 0 }] },
      "streamSettings": {
        "network": "ws", "security": "tls",
        "tlsSettings": { "certificates": [{ "certificateFile": "/etc/xray/xray.crt", "keyFile": "/etc/xray/xray.key" }] },
        "wsSettings": { "path": "/vmess" }
      }
    },
    {
      "port": 80, "protocol": "vmess", "tag": "vmess-ws",
      "settings": { "clients": [{ "id": "$UUID_VMESS", "alterId": 0 }] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } }
    },
    {
      "port": 2083, "protocol": "vless", "tag": "vless-ws-tls",
      "settings": { "clients": [{ "id": "$UUID_VLESS", "flow": "" }], "decryption": "none" },
      "streamSettings": {
        "network": "ws", "security": "tls",
        "tlsSettings": { "certificates": [{ "certificateFile": "/etc/xray/xray.crt", "keyFile": "/etc/xray/xray.key" }] },
        "wsSettings": { "path": "/vless" }
      }
    },
    {
      "port": 2087, "protocol": "trojan", "tag": "trojan-ws-tls",
      "settings": { "clients": [{ "password": "$UUID_TROJAN" }] },
      "streamSettings": {
        "network": "ws", "security": "tls",
        "tlsSettings": { "certificates": [{ "certificateFile": "/etc/xray/xray.crt", "keyFile": "/etc/xray/xray.key" }] },
        "wsSettings": { "path": "/trojan" }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct" },
    { "protocol": "blackhole", "tag": "blocked" }
  ]
}
EOF

  # Xray systemd
  cat > /etc/systemd/system/xray.service << 'EOF'
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable xray &>/dev/null
  systemctl restart xray &>/dev/null
  echo -e "${GREEN}[✓] Xray installed (VMess:8443,80 | VLESS:2083 | Trojan:2087)${NC}"
}

# ==========================================
#   INSTALL UDP CUSTOM + UDP ZIVPN
# ==========================================
install_udp() {
  echo -e "\n${YELLOW}[*] Installing UDP Custom + UDP ZiVPN...${NC}"

  # UDP Custom (udp-custom from GitHub)
  echo -e "${CYAN}  Downloading UDP Custom...${NC}"
  UDPC_URL="https://github.com/ThePowerOfSwift/udp-custom/releases/latest/download/udp-custom-linux-amd64"
  # Fallback to building from source if binary unavailable
  wget -q "$UDPC_URL" -O /usr/local/bin/udp-custom 2>/dev/null || {
    echo -e "${YELLOW}  [!] Downloading alternative UDP Custom...${NC}"
    wget -q "https://github.com/zivpn/udp-custom/releases/latest/download/udp-custom" \
      -O /usr/local/bin/udp-custom 2>/dev/null || true
  }

  # UDP ZiVPN (badvpn udpgw based)
  echo -e "${CYAN}  Installing badvpn-udpgw (UDP relay)...${NC}"
  $PKG install -y cmake gcc g++ make &>/dev/null
  
  # Download and compile badvpn udpgw
  BADVPN_URL="https://github.com/ambrop72/badvpn/archive/refs/heads/master.zip"
  wget -q "$BADVPN_URL" -O /tmp/badvpn.zip
  unzip -q /tmp/badvpn.zip -d /tmp/
  cd /tmp/badvpn-master
  mkdir -p build && cd build
  cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 &>/dev/null
  make &>/dev/null
  mv udpgw/badvpn-udpgw /usr/local/bin/
  chmod +x /usr/local/bin/badvpn-udpgw
  cd / && rm -rf /tmp/badvpn*
  echo -e "${GREEN}  [✓] badvpn-udpgw compiled${NC}"

  # UDP Custom config
  cat > $PANEL_DIR/config/udp-custom.conf << 'EOF'
{
  "listen": "0.0.0.0",
  "port": 7300,
  "tunnel": "127.0.0.1:7200",
  "key": "vpn-panel-udp-key",
  "protocol": "udp",
  "obfs": true
}
EOF

  # ZiVPN UDP systemd
  cat > /etc/systemd/system/udp-custom.service << 'EOF'
[Unit]
Description=UDP Custom VPN
After=network.target

[Service]
ExecStart=/usr/local/bin/udp-custom server --config /etc/vpn-panel/config/udp-custom.conf
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  # badvpn-udpgw systemd
  cat > /etc/systemd/system/badvpn-udpgw.service << 'EOF'
[Unit]
Description=BadVPN UDP Gateway
After=network.target

[Service]
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500 --max-connections-for-client 10
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable badvpn-udpgw udp-custom &>/dev/null
  systemctl restart badvpn-udpgw &>/dev/null
  echo -e "${GREEN}[✓] UDP services installed (UDP-Custom:7300 | UDPGW:7300)${NC}"
}

# ==========================================
#   SETUP TLS CERTIFICATE (acme.sh)
# ==========================================
setup_tls() {
  echo -e "\n${YELLOW}[*] Installing acme.sh for TLS management...${NC}"
  curl -s https://get.acme.sh | sh -s email=admin@vpn.local &>/dev/null
  echo -e "${GREEN}[✓] acme.sh installed. Run 'acme.sh --issue -d DOMAIN --standalone' for real cert.${NC}"
}

# ==========================================
#   SETUP FIREWALL (iptables)
# ==========================================
setup_firewall() {
  echo -e "\n${YELLOW}[*] Configuring firewall...${NC}"
  
  $PKG install -y iptables-persistent &>/dev/null 2>&1 || true

  # Allow established
  iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  
  # SSH ports
  iptables -A INPUT -p tcp --dport 22 -j ACCEPT
  iptables -A INPUT -p tcp --dport 2222 -j ACCEPT
  iptables -A INPUT -p tcp --dport 442 -j ACCEPT
  iptables -A INPUT -p tcp --dport 109 -j ACCEPT
  
  # Xray ports
  iptables -A INPUT -p tcp --dport 80 -j ACCEPT
  iptables -A INPUT -p tcp --dport 8443 -j ACCEPT
  iptables -A INPUT -p tcp --dport 2083 -j ACCEPT
  iptables -A INPUT -p tcp --dport 2087 -j ACCEPT
  
  # SSH WebSocket
  iptables -A INPUT -p tcp --dport 8880 -j ACCEPT
  
  # UDP
  iptables -A INPUT -p udp --dport 7300 -j ACCEPT
  
  # Save
  iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
  echo -e "${GREEN}[✓] Firewall configured${NC}"
}

# ==========================================
#   SETUP MOTD / AUTO MENU ON LOGIN
# ==========================================
setup_motd() {
  echo -e "\n${YELLOW}[*] Setting up auto-menu on login...${NC}"

  # Disable default MOTD
  chmod -x /etc/update-motd.d/* 2>/dev/null || true

  # Create welcome script
  cat > /etc/vpn-panel/config/banner.txt << 'EOF'
Welcome to VPN Panel Server
EOF

  # Add menu call to /etc/profile
  cat >> /etc/profile << 'EOF'

# VPN Panel Auto Menu
if [ "$(id -u)" -eq 0 ] && [ -f /usr/local/bin/vpn-menu ]; then
  /usr/local/bin/vpn-menu
fi
EOF

  echo -e "${GREEN}[✓] Auto-menu on login configured${NC}"
}

# ==========================================
#   SETUP AUTO-RENEW (cron)
# ==========================================
setup_cron() {
  echo -e "\n${YELLOW}[*] Setting up auto-renew cron...${NC}"
  
  # Auto delete expired users (daily at midnight)
  (crontab -l 2>/dev/null; echo "0 0 * * * /usr/local/bin/vpn-expired-check >> /var/log/vpn-panel/expired.log 2>&1") | crontab -
  
  # Auto restart services (every 5 min check)
  (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/vpn-monitor >> /var/log/vpn-panel/monitor.log 2>&1") | crontab -

  # TLS cert renew (daily)
  (crontab -l 2>/dev/null; echo "0 2 * * * /root/.acme.sh/acme.sh --cron --home /root/.acme.sh >> /var/log/acme.log 2>&1") | crontab -

  echo -e "${GREEN}[✓] Cron jobs configured${NC}"
}

# ==========================================
#   INSTALL MENU SCRIPTS
# ==========================================
install_menus() {
  echo -e "\n${YELLOW}[*] Installing menu scripts...${NC}"
  
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  
  cp "$SCRIPT_DIR/menu.sh" /usr/local/bin/vpn-menu
  cp "$SCRIPT_DIR/user-manager.sh" /usr/local/bin/vpn-user
  cp "$SCRIPT_DIR/monitor.sh" /usr/local/bin/vpn-monitor
  cp "$SCRIPT_DIR/expired-check.sh" /usr/local/bin/vpn-expired-check
  
  chmod +x /usr/local/bin/vpn-menu \
            /usr/local/bin/vpn-user \
            /usr/local/bin/vpn-monitor \
            /usr/local/bin/vpn-expired-check
  
  echo -e "${GREEN}[✓] Menu scripts installed${NC}"
}

# ==========================================
#   SAVE SERVER INFO
# ==========================================
save_info() {
  SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null)
  
  source $PANEL_DIR/config/xray-uuid.conf
  
  cat > $PANEL_DIR/config/server.info << EOF
SERVER_IP=$SERVER_IP
INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')
OS=$(. /etc/os-release && echo "$PRETTY_NAME")
VMESS_UUID=$VMESS_UUID
VLESS_UUID=$VLESS_UUID
TROJAN_PASS=$TROJAN_PASS
SSH_PORT=22
SSH_PORT2=2222
DROPBEAR_PORT=442
DROPBEAR_PORT2=109
SSH_WS_PORT=8880
VMESS_WS_PORT=80
VMESS_WSS_PORT=8443
VLESS_WSS_PORT=2083
TROJAN_WSS_PORT=2087
UDP_PORT=7300
EOF
  echo -e "${GREEN}[✓] Server info saved to $PANEL_DIR/config/server.info${NC}"
}

# ==========================================
#   SHOW FINAL INFO
# ==========================================
show_final() {
  source $PANEL_DIR/config/server.info
  source $PANEL_DIR/config/xray-uuid.conf

  clear
  echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${WHITE}          INSTALASI SELESAI! / INSTALL DONE          ${CYAN}║${NC}"
  echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
  echo -e "${CYAN}║${NC} IP Server   : ${WHITE}$SERVER_IP${CYAN}${NC}"
  echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
  echo -e "${CYAN}║${YELLOW} [ SSH ]                                             ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  OpenSSH    : Port 22, 2222                          ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  Dropbear   : Port 442, 109                          ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  SSH-WS     : Port 8880                              ${CYAN}║${NC}"
  echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
  echo -e "${CYAN}║${YELLOW} [ VMess WebSocket ]                                 ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  UUID       : $VMESS_UUID ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  WS Port    : 80  (path: /vmess)                     ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  WSS Port   : 8443 (path: /vmess)                    ${CYAN}║${NC}"
  echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
  echo -e "${CYAN}║${YELLOW} [ VLESS WebSocket+TLS ]                             ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  UUID       : $VLESS_UUID ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  WSS Port   : 2083 (path: /vless)                    ${CYAN}║${NC}"
  echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
  echo -e "${CYAN}║${YELLOW} [ Trojan WebSocket+TLS ]                            ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  Password   : $TROJAN_PASS                   ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  WSS Port   : 2087 (path: /trojan)                   ${CYAN}║${NC}"
  echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
  echo -e "${CYAN}║${YELLOW} [ UDP ]                                             ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  UDP Custom : Port 7300                              ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  UDPGW      : Port 7300 (local relay)                ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
  echo -e "\n${GREEN}Ketik '${WHITE}vpn-menu${GREEN}' untuk membuka panel management${NC}\n"
}

# ==========================================
#   MAIN
# ==========================================
main() {
  show_banner
  check_root
  check_os
  prepare_dirs

  # Download & install semua binary dari sumber resmi
  echo -e "\n${YELLOW}[*] Downloading all binaries from official sources...${NC}"
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  bash "$SCRIPT_DIR/download-bins.sh"

  install_deps
  install_ssh
  install_xray
  install_udp
  setup_tls
  setup_firewall
  setup_motd
  setup_cron
  install_menus
  save_info
  show_final
}

main "$@"
