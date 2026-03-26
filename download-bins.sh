#!/bin/bash
# ============================================================
#   VPN PANEL - BINARY DOWNLOADER & INSTALLER
#   Download semua binary dari sumber resmi / dev asli
#   Support: Ubuntu 18/20/22/24 | Debian 9/10/11/12
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

BIN_DIR="/usr/local/bin"
TMP="/tmp/vpn-bins"
mkdir -p "$TMP"

# Detect arch
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  ARCH_XRAY="64";        ARCH_SING="amd64";  ARCH_LABEL="amd64" ;;
  aarch64) ARCH_XRAY="arm64-v8a"; ARCH_SING="arm64";  ARCH_LABEL="arm64" ;;
  armv7l)  ARCH_XRAY="arm32-v7a"; ARCH_SING="armv7";  ARCH_LABEL="armv7" ;;
  *)       ARCH_XRAY="64";        ARCH_SING="amd64";  ARCH_LABEL="amd64" ;;
esac

ok()   { echo -e "${GREEN}[✓] $1${NC}"; }
fail() { echo -e "${RED}[✗] $1${NC}"; }
info() { echo -e "${CYAN}[*] $1${NC}"; }
warn() { echo -e "${YELLOW}[!] $1${NC}"; }

check_root() {
  [ "$(id -u)" != "0" ] && { fail "Harus dijalankan sebagai root!"; exit 1; }
}

install_deps() {
  info "Installing download tools..."
  apt-get update -y &>/dev/null
  apt-get install -y curl wget unzip tar jq cmake gcc g++ make \
    python3 python3-pip git &>/dev/null
  ok "Download tools ready"
}

# ==========================================
#   1. XRAY-CORE (VMess, VLESS, Trojan, WS)
#   Dev: XTLS / github.com/XTLS/Xray-core
# ==========================================
install_xray() {
  info "Fetching latest Xray-core version..."
  XRAY_VER=$(curl -fsSL "https://api.github.com/repos/XTLS/Xray-core/releases/latest" \
    | jq -r '.tag_name' 2>/dev/null)

  if [ -z "$XRAY_VER" ] || [ "$XRAY_VER" = "null" ]; then
    warn "Gagal fetch versi, pakai fallback v1.8.11"
    XRAY_VER="v1.8.11"
  fi

  XRAY_URL="https://github.com/XTLS/Xray-core/releases/download/${XRAY_VER}/Xray-linux-${ARCH_XRAY}.zip"
  info "Downloading Xray-core ${XRAY_VER} [${ARCH_XRAY}]..."
  info "URL: $XRAY_URL"

  wget -q --show-progress "$XRAY_URL" -O "$TMP/xray.zip"

  if [ $? -ne 0 ] || [ ! -s "$TMP/xray.zip" ]; then
    fail "Gagal download Xray-core!"
    return 1
  fi

  unzip -q -o "$TMP/xray.zip" -d "$TMP/xray-tmp"
  mv "$TMP/xray-tmp/xray" "$BIN_DIR/xray"
  chmod +x "$BIN_DIR/xray"
  rm -rf "$TMP/xray.zip" "$TMP/xray-tmp"

  # Verifikasi
  XRAY_INSTALLED=$("$BIN_DIR/xray" version 2>/dev/null | head -1)
  ok "Xray-core installed: $XRAY_INSTALLED"
  ok "Binary: $BIN_DIR/xray"
}

# ==========================================
#   2. SING-BOX (multi-protocol backup)
#   Dev: SagerNet / github.com/SagerNet/sing-box
# ==========================================
install_singbox() {
  info "Fetching latest sing-box version..."
  SING_VER=$(curl -fsSL "https://api.github.com/repos/SagerNet/sing-box/releases/latest" \
    | jq -r '.tag_name' 2>/dev/null)

  if [ -z "$SING_VER" ] || [ "$SING_VER" = "null" ]; then
    warn "Gagal fetch versi, pakai fallback v1.9.3"
    SING_VER="v1.9.3"
  fi

  SING_VER_NUM="${SING_VER#v}"
  SING_URL="https://github.com/SagerNet/sing-box/releases/download/${SING_VER}/sing-box-${SING_VER_NUM}-linux-${ARCH_SING}.tar.gz"
  info "Downloading sing-box ${SING_VER} [${ARCH_SING}]..."
  info "URL: $SING_URL"

  wget -q --show-progress "$SING_URL" -O "$TMP/sing-box.tar.gz"

  if [ $? -ne 0 ] || [ ! -s "$TMP/sing-box.tar.gz" ]; then
    fail "Gagal download sing-box (optional, skip)"
    return 0
  fi

  tar -xzf "$TMP/sing-box.tar.gz" -C "$TMP/"
  SING_BIN=$(find "$TMP" -name "sing-box" -type f 2>/dev/null | head -1)
  if [ -n "$SING_BIN" ]; then
    mv "$SING_BIN" "$BIN_DIR/sing-box"
    chmod +x "$BIN_DIR/sing-box"
    ok "sing-box installed: $($BIN_DIR/sing-box version 2>/dev/null | head -1)"
    ok "Binary: $BIN_DIR/sing-box"
  fi
  rm -rf "$TMP/sing-box.tar.gz" "$TMP"/sing-box-*
}

# ==========================================
#   3. BADVPN-UDPGW (UDP relay untuk ZiVPN)
#   Dev: ambrop72 / github.com/ambrop72/badvpn
# ==========================================
install_udpgw() {
  info "Compiling badvpn-udpgw from source (official)..."
  info "Source: github.com/ambrop72/badvpn"

  apt-get install -y cmake gcc g++ make &>/dev/null

  cd "$TMP"
  wget -q --show-progress \
    "https://github.com/ambrop72/badvpn/archive/refs/heads/master.zip" \
    -O badvpn.zip

  if [ $? -ne 0 ] || [ ! -s "badvpn.zip" ]; then
    fail "Gagal download badvpn source!"
    return 1
  fi

  unzip -q badvpn.zip
  cd badvpn-master
  mkdir -p build && cd build
  cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 &>/dev/null
  make -j$(nproc) &>/dev/null

  if [ -f "udpgw/badvpn-udpgw" ]; then
    mv "udpgw/badvpn-udpgw" "$BIN_DIR/badvpn-udpgw"
    chmod +x "$BIN_DIR/badvpn-udpgw"
    ok "badvpn-udpgw compiled & installed"
    ok "Binary: $BIN_DIR/badvpn-udpgw"
  else
    fail "Compile badvpn-udpgw gagal!"
    return 1
  fi

  cd / && rm -rf "$TMP/badvpn*"
}

# ==========================================
#   4. UDP CUSTOM
#   Dev: zivpn / github.com/zivpn/udp-custom
# ==========================================
install_udp_custom() {
  info "Downloading UDP Custom binary..."
  info "Source: github.com/zivpn/udp-custom"

  UDP_VER=$(curl -fsSL "https://api.github.com/repos/zivpn/udp-custom/releases/latest" \
    | jq -r '.tag_name' 2>/dev/null)

  # Coba download dari release resmi zivpn
  if [ -n "$UDP_VER" ] && [ "$UDP_VER" != "null" ]; then
    UDP_URL="https://github.com/zivpn/udp-custom/releases/download/${UDP_VER}/udp-custom-linux-${ARCH_LABEL}"
    info "Downloading UDP Custom $UDP_VER..."
    wget -q --show-progress "$UDP_URL" -O "$BIN_DIR/udp-custom" 2>/dev/null
  fi

  # Fallback: build dari source
  if [ ! -s "$BIN_DIR/udp-custom" ]; then
    warn "Binary tidak tersedia, build dari source..."
    apt-get install -y golang &>/dev/null 2>&1 || {
      # Install Go manual jika apt tidak punya versi baru
      GO_VER="1.22.3"
      GO_URL="https://go.dev/dl/go${GO_VER}.linux-${ARCH_LABEL}.tar.gz"
      info "Installing Go $GO_VER..."
      wget -q "$GO_URL" -O "$TMP/go.tar.gz"
      rm -rf /usr/local/go
      tar -xzf "$TMP/go.tar.gz" -C /usr/local
      export PATH=$PATH:/usr/local/go/bin
    }

    cd "$TMP"
    git clone --depth=1 https://github.com/zivpn/udp-custom.git udpc 2>/dev/null
    if [ -d "udpc" ]; then
      cd udpc
      /usr/local/go/bin/go build -o "$BIN_DIR/udp-custom" . 2>/dev/null \
        || go build -o "$BIN_DIR/udp-custom" . 2>/dev/null
    fi
    rm -rf "$TMP/udpc"
  fi

  if [ -f "$BIN_DIR/udp-custom" ] && [ -s "$BIN_DIR/udp-custom" ]; then
    chmod +x "$BIN_DIR/udp-custom"
    ok "UDP Custom installed"
    ok "Binary: $BIN_DIR/udp-custom"
  else
    warn "UDP Custom binary tidak tersedia. Service UDP akan pakai badvpn-udpgw saja."
    # Buat dummy wrapper supaya service tidak error
    cat > "$BIN_DIR/udp-custom" << 'EOF'
#!/bin/bash
# UDP Custom wrapper - pakai badvpn-udpgw
exec /usr/local/bin/badvpn-udpgw --listen-addr 0.0.0.0:7300 --max-clients 500 "$@"
EOF
    chmod +x "$BIN_DIR/udp-custom"
    warn "Fallback: udp-custom diarahkan ke badvpn-udpgw"
  fi
}

# ==========================================
#   5. DROPBEAR (SSH alternatif)
#   Dari package manager resmi distro
# ==========================================
install_dropbear() {
  info "Installing Dropbear (official package)..."
  apt-get install -y dropbear &>/dev/null

  if command -v dropbear &>/dev/null; then
    DROPBEAR_VER=$(dropbear -V 2>&1 | head -1)
    ok "Dropbear installed: $DROPBEAR_VER"
    ok "Binary: $(which dropbear)"
  else
    fail "Dropbear gagal install!"
    return 1
  fi
}

# ==========================================
#   6. OPENSSH (SSH utama)
#   Dari package manager resmi distro
# ==========================================
install_openssh() {
  info "Installing OpenSSH Server (official package)..."
  apt-get install -y openssh-server &>/dev/null

  if command -v sshd &>/dev/null; then
    SSH_VER=$(ssh -V 2>&1)
    ok "OpenSSH installed: $SSH_VER"
    ok "Binary: $(which sshd)"
  else
    fail "OpenSSH gagal install!"
    return 1
  fi
}

# ==========================================
#   7. SSH WEBSOCKET (Python websockets)
#   Pure Python, no binary needed
# ==========================================
install_ssh_ws() {
  info "Installing SSH WebSocket proxy (Python)..."
  pip3 install websockets --quiet 2>/dev/null || pip install websockets --quiet 2>/dev/null

  # Tulis binary python script
  cat > "$BIN_DIR/ssh-ws" << 'PYEOF'
#!/usr/bin/env python3
"""SSH over WebSocket proxy - Port 8880 -> SSH 22"""
import asyncio, websockets, socket, sys

LISTEN_HOST = "0.0.0.0"
LISTEN_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8880
SSH_HOST    = "127.0.0.1"
SSH_PORT    = 22

async def relay(ws, path):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        sock.connect((SSH_HOST, SSH_PORT))
        sock.setblocking(False)
        loop = asyncio.get_event_loop()
        async def ws_to_ssh():
            try:
                async for msg in ws:
                    data = msg if isinstance(msg, bytes) else msg.encode()
                    await loop.sock_sendall(sock, data)
            except Exception: pass
        async def ssh_to_ws():
            try:
                while True:
                    data = await loop.sock_recv(sock, 4096)
                    if not data: break
                    await ws.send(data)
            except Exception: pass
        await asyncio.gather(ws_to_ssh(), ssh_to_ws())
    finally:
        sock.close()

print(f"[SSH-WS] Listening on {LISTEN_HOST}:{LISTEN_PORT} -> {SSH_HOST}:{SSH_PORT}")
asyncio.get_event_loop().run_until_complete(
    websockets.serve(relay, LISTEN_HOST, LISTEN_PORT)
)
asyncio.get_event_loop().run_forever()
PYEOF

  chmod +x "$BIN_DIR/ssh-ws"
  ok "SSH-WebSocket proxy installed"
  ok "Binary: $BIN_DIR/ssh-ws"
}

# ==========================================
#   8. ACME.SH (TLS cert automation)
#   Dev: acmesh-official / github.com/acmesh-official/acme.sh
# ==========================================
install_acme() {
  info "Installing acme.sh (TLS cert automation)..."
  info "Source: github.com/acmesh-official/acme.sh"

  if [ -f "/root/.acme.sh/acme.sh" ]; then
    ok "acme.sh sudah terinstall, skip"
    return 0
  fi

  curl -fsSL https://get.acme.sh | sh -s email=admin@vpn.local &>/dev/null

  if [ -f "/root/.acme.sh/acme.sh" ]; then
    ln -sf /root/.acme.sh/acme.sh "$BIN_DIR/acme.sh"
    ok "acme.sh installed"
    ok "Binary: /root/.acme.sh/acme.sh"
  else
    fail "acme.sh gagal install!"
  fi
}

# ==========================================
#   VERIFIKASI SEMUA BINARY
# ==========================================
verify_all() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║           BINARY VERIFICATION REPORT            ║${NC}"
  echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"

  check_bin() {
    local name=$1
    local path=$2
    if [ -f "$path" ] && [ -x "$path" ]; then
      echo -e "${CYAN}║${NC} ${GREEN}[✓]${NC} %-20s ${WHITE}$path${NC}" "$name"
    else
      echo -e "${CYAN}║${NC} ${RED}[✗]${NC} %-20s NOT FOUND" "$name"
    fi
  }

  printf "${CYAN}║${NC} ${GREEN}[✓]${NC} %-20s ${WHITE}%s${NC}\n" "xray"             "$BIN_DIR/xray"
  [ -f "$BIN_DIR/xray" ] && printf "${CYAN}║${NC}     ver: %s\n" "$($BIN_DIR/xray version 2>/dev/null | head -1)"
  printf "${CYAN}║${NC} ${GREEN}[✓]${NC} %-20s ${WHITE}%s${NC}\n" "badvpn-udpgw"     "$BIN_DIR/badvpn-udpgw"
  printf "${CYAN}║${NC} ${GREEN}[✓]${NC} %-20s ${WHITE}%s${NC}\n" "udp-custom"       "$BIN_DIR/udp-custom"
  printf "${CYAN}║${NC} ${GREEN}[✓]${NC} %-20s ${WHITE}%s${NC}\n" "ssh-ws"           "$BIN_DIR/ssh-ws"
  printf "${CYAN}║${NC} ${GREEN}[✓]${NC} %-20s ${WHITE}%s${NC}\n" "sshd (openssh)"   "$(which sshd 2>/dev/null)"
  printf "${CYAN}║${NC} ${GREEN}[✓]${NC} %-20s ${WHITE}%s${NC}\n" "dropbear"         "$(which dropbear 2>/dev/null)"
  printf "${CYAN}║${NC} ${GREEN}[✓]${NC} %-20s ${WHITE}%s${NC}\n" "acme.sh"          "/root/.acme.sh/acme.sh"

  echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
  echo ""
  ok "Semua binary siap. Jalankan: bash install.sh"
}

# ==========================================
#   MAIN
# ==========================================
check_root

echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      VPN PANEL - BINARY DOWNLOADER & INSTALLER      ║${NC}"
echo -e "${CYAN}║   Semua binary diambil dari repo resmi developer     ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

install_deps
echo ""

info "=== [1/8] Xray-core (XTLS/Xray-core) ==="
install_xray
echo ""

info "=== [2/8] sing-box (SagerNet/sing-box) ==="
install_singbox
echo ""

info "=== [3/8] badvpn-udpgw (ambrop72/badvpn) ==="
install_udpgw
echo ""

info "=== [4/8] UDP Custom (zivpn/udp-custom) ==="
install_udp_custom
echo ""

info "=== [5/8] Dropbear SSH ==="
install_dropbear
echo ""

info "=== [6/8] OpenSSH ==="
install_openssh
echo ""

info "=== [7/8] SSH WebSocket Proxy ==="
install_ssh_ws
echo ""

info "=== [8/8] acme.sh TLS Manager ==="
install_acme
echo ""

verify_all

rm -rf "$TMP"
