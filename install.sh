#!/bin/bash
# install.sh - Instalasi otomatis code-server di Ubuntu/Debian
set -e

if [ "$EUID" -eq 0 ]; then
  echo "Jalankan sebagai user biasa (bukan root), bukan dengan sudo."
  exit 1
fi

PORT=8080

echo "Pilih cara akses:"
echo "  1) Lokal (localhost / port forwarding VirtualBox)"
echo "  2) Cloudflare Tunnel (quick tunnel, URL sementara)"
echo "  3) Domain sendiri (named tunnel Cloudflare)"
read -rp "Pilihan [1/2/3]: " MODE
case "$MODE" in
  1|2|3) ;;
  *) echo "Pilihan tidak valid."; exit 1 ;;
esac

if [ "$MODE" = "3" ]; then
  read -rp "Masukkan hostname (contoh: code.namaanda.eu.org): " HOSTNAME_CF
  if [ -z "$HOSTNAME_CF" ]; then
    echo "Hostname tidak boleh kosong."
    exit 1
  fi
fi

read -rsp "Masukkan password code-server: " PASSWORD
echo
if [ -z "$PASSWORD" ]; then
  echo "Password tidak boleh kosong."
  exit 1
fi
case "$PASSWORD" in
  *\"*|*\\*) echo 'Password tidak boleh mengandung tanda " atau \.'; exit 1 ;;
esac

install_cloudflared() {
  ARCH=$(dpkg --print-architecture)   # amd64 atau arm64
  curl -fL -o /tmp/cloudflared.deb \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb"
  sudo dpkg -i /tmp/cloudflared.deb
  rm -f /tmp/cloudflared.deb
}

echo "[1/5] Memperbarui sistem..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl

echo "[2/5] Memasang code-server..."
curl -fsSL https://code-server.dev/install.sh | sh

echo "[3/5] Mengaktifkan layanan..."
sudo systemctl enable --now code-server@$USER
sleep 5   # beri waktu agar file konfigurasi default dibuat

echo "[4/5] Menulis konfigurasi..."
if [ "$MODE" = "1" ]; then
  BIND="0.0.0.0"
else
  BIND="127.0.0.1"
fi
mkdir -p ~/.config/code-server
cat > ~/.config/code-server/config.yaml <<EOF
bind-addr: ${BIND}:${PORT}
auth: password
password: "${PASSWORD}"
cert: false
EOF
sudo systemctl restart code-server@$USER

echo "[5/5] Menyiapkan akses..."
case "$MODE" in
  1)
    if sudo ufw status | grep -q "Status: active"; then
      sudo ufw allow ${PORT}/tcp
    fi
    IP=$(hostname -I | awk '{print $1}')
    echo
    echo "Selesai. code-server berjalan di ${IP}:${PORT}."
    if echo "$IP" | grep -q '^10\.0\.2\.'; then
      echo
      echo "Terdeteksi VirtualBox mode NAT (IP ${IP})."
      echo "Tambahkan port forwarding DI LAPTOP HOST (bukan di VM):"
      echo "  GUI: Settings > Network > Adapter 1 > Advanced > Port Forwarding"
      echo "       TCP, Host IP 127.0.0.1, Host Port ${PORT}, Guest IP ${IP}, Guest Port ${PORT}"
      echo "  CLI: VBoxManage controlvm \"NAMA_VM\" natpf1 \"code-server,tcp,127.0.0.1,${PORT},,${PORT}\""
      echo "Lalu buka di laptop: http://localhost:${PORT}"
    else
      echo "Buka dari laptop: http://${IP}:${PORT}"
    fi
    ;;
  2)
    install_cloudflared
    echo
    echo "Selesai. Jalankan tunnel dengan perintah:"
    echo "  cloudflared tunnel --url http://localhost:${PORT}"
    echo "Lalu buka URL https://....trycloudflare.com yang muncul."
    ;;
  3)
    install_cloudflared
    echo
    echo "Login Cloudflare: salin URL yang muncul, buka di browser laptop, lalu pilih domain Anda."
    cloudflared tunnel login

    OUT=$(cloudflared tunnel create codeserver 2>&1)
    echo "$OUT"
    TUNNEL_ID=$(echo "$OUT" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -n1)
    if [ -z "$TUNNEL_ID" ]; then
      echo "Gagal membaca ID tunnel. Jika tunnel 'codeserver' sudah ada, hapus dulu: cloudflared tunnel delete codeserver"
      exit 1
    fi

    cloudflared tunnel route dns codeserver "$HOSTNAME_CF"

    sudo mkdir -p /etc/cloudflared
    sudo cp ~/.cloudflared/${TUNNEL_ID}.json /etc/cloudflared/
    sudo tee /etc/cloudflared/config.yml > /dev/null <<EOF
tunnel: ${TUNNEL_ID}
credentials-file: /etc/cloudflared/${TUNNEL_ID}.json
ingress:
  - hostname: ${HOSTNAME_CF}
    service: http://localhost:${PORT}
  - service: http_status:404
EOF
    sudo cloudflared service install
    echo
    echo "Selesai. Buka: https://${HOSTNAME_CF}"
    ;;
esac