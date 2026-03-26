# VPN PANEL - ALL PROTOCOL
## Support: Ubuntu 18/20/22/24 | Debian 9/10/11/12

### PROTOKOL YANG DISUPPORT
- SSH (OpenSSH + Dropbear + SSH-WebSocket)
- VMess WebSocket + TLS (Xray-core terbaru)
- VLESS WebSocket + TLS (Xray-core terbaru)
- Trojan WebSocket + TLS (Xray-core terbaru)
- UDP Custom + badvpn-udpgw (ZiVPN)

---

## CARA INSTALL

### 1. Upload ke VPS
```bash
# Dari lokal ke VPS
scp -r vpn-panel/ root@IP_VPS:/root/

# Atau clone jika sudah di GitHub
git clone https://github.com/REPO_KAMU/vpn-panel /root/vpn-panel
```

### 2. Beri izin dan jalankan
```bash
cd /root/vpn-panel
chmod +x install.sh menu.sh user-manager.sh monitor.sh expired-check.sh
bash install.sh
```

### 3. Setelah install selesai
```bash
# Buka menu utama
vpn-menu

# Atau kelola user langsung
vpn-user ssh        # Manajemen user SSH
vpn-user vmess      # Manajemen user VMess
vpn-user vless      # Manajemen user VLESS
vpn-user trojan     # Manajemen user Trojan
vpn-user udp        # Info & manage UDP
```

---

## PORT DEFAULT

| Protokol      | Port(s)              |
|---------------|----------------------|
| OpenSSH       | 22, 2222             |
| Dropbear      | 442, 109             |
| SSH-WebSocket | 8880                 |
| VMess WS      | 80 (path: /vmess)    |
| VMess WSS     | 8443 (path: /vmess)  |
| VLESS WSS     | 2083 (path: /vless)  |
| Trojan WSS    | 2087 (path: /trojan) |
| UDP Custom    | 7300                 |
| badvpn-udpgw  | 7300 (local)         |

---

## SETUP DOMAIN + TLS REAL (Opsional)
Setelah install, dari menu utama pilih **[8] Setup Domain/TLS**
dan masukkan domain/subdomain kamu. Pastikan domain sudah
diarahkan ke IP VPS sebelum menjalankan ini.

---

## AUTO MENU SAAT LOGIN
Script ini otomatis menampilkan menu saat kamu login sebagai
**root** ke VPS. Untuk menonaktifkan, hapus baris berikut
dari `/etc/profile`:
```bash
# VPN Panel Auto Menu
if [ "$(id -u)" -eq 0 ] && [ -f /usr/local/bin/vpn-menu ]; then
  /usr/local/bin/vpn-menu
fi
```

---

## STRUKTUR FILE
```
/etc/vpn-panel/
  config/
    server.info        - Info server & UUID
    xray-uuid.conf     - UUID default xray
    udp-custom.conf    - Config UDP
    domain             - Domain TLS (jika ada)
    banner.txt         - Banner Dropbear
  users/
    ssh.db             - Database user SSH
    vmess.db           - Database user VMess
    vless.db           - Database user VLESS
    trojan.db          - Database user Trojan

/usr/local/bin/
  vpn-menu             - Menu utama
  vpn-user             - Manajemen user
  vpn-monitor          - Monitor service (cron)
  vpn-expired-check    - Cek & hapus user expired (cron)
```

---

## LOG
```
/var/log/vpn-panel/monitor.log   - Log restart otomatis service
/var/log/vpn-panel/expired.log   - Log user yang dihapus
/var/log/xray-access.log         - Access log Xray
/var/log/xray-error.log          - Error log Xray
```
