#!/bin/bash

set -e

if [ "$EUID" -eq 0 ]; then
  echo "Jalankan sebagai user biasa (bukan root), bukan dengan sudo."
  exit 1
fi

PORT=8080

read -rp "Masukkan hostname (contoh: example.eu.org): " HOSTNAME_CF
if [ -z "$HOSTNAME_CF" ]; then
  echo "Hostname tidak boleh kosong."
  exit 1
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

read -rp "Batas memori (contoh 1G, kosongkan untuk melewati): " MEMLIMIT

read -rp "Jadwalkan backup mingguan? [y/N]: " DO_BACKUP
if [ "${DO_BACKUP,,}" = "y" ]; then
  read -rp "Nama folder proyek di home [project]: " PROJECT_DIR
  PROJECT_DIR=${PROJECT_DIR:-project}
fi

read -rp "Jadwalkan pembersihan log harian? [y/N]: " DO_LOG

echo "[1/6] Memperbarui sistem..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl

echo "[2/6] Memasang code-server..."
curl -fsSL https://code-server.dev/install.sh | sh

echo "[3/6] Mengaktifkan layanan..."
sudo systemctl enable --now code-server@$USER
sleep 5   # beri waktu agar file konfigurasi default dibuat

echo "[4/6] Menulis konfigurasi..."
mkdir -p ~/.config/code-server
cat > ~/.config/code-server/config.yaml <<EOF
bind-addr: 127.0.0.1:${PORT}
auth: password
password: "${PASSWORD}"
cert: false
EOF

if [ -n "$MEMLIMIT" ]; then
  sudo mkdir -p /etc/systemd/system/code-server@${USER}.service.d
  sudo tee /etc/systemd/system/code-server@${USER}.service.d/override.conf > /dev/null <<EOF
[Service]
MemoryMax=${MEMLIMIT}
EOF
  sudo systemctl daemon-reload
fi
sudo systemctl restart code-server@$USER

echo "[5/6] Menyiapkan Cloudflare Tunnel..."
ARCH=$(dpkg --print-architecture)   # amd64 atau arm64
curl -fL -o /tmp/cloudflared.deb \
  "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb"
sudo dpkg -i /tmp/cloudflared.deb
rm -f /tmp/cloudflared.deb

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

echo "[6/6] Menyiapkan maintenance..."

if [ "${DO_BACKUP,,}" = "y" ]; then
  mkdir -p ~/"$PROJECT_DIR"

  cat > ~/backup-code-server.sh <<EOS
#!/bin/bash
BACKUP_DIR="\$HOME/backup"
PROJECT_DIR="${PROJECT_DIR}"
mkdir -p "\$BACKUP_DIR"

tar -czf "\$BACKUP_DIR/code-server-\$(date +%F).tar.gz" \\
  -C "\$HOME" .config/code-server .local/share/code-server "\$PROJECT_DIR"

# Hapus backup yang lebih lama dari 28 hari.
find "\$BACKUP_DIR" -name 'code-server-*.tar.gz' -mtime +28 -delete
EOS
  chmod +x ~/backup-code-server.sh

  ( crontab -l 2>/dev/null | grep -v 'backup-code-server.sh' || true
    echo "0 2 * * 0 $HOME/backup-code-server.sh" ) | crontab -
  echo "Backup mingguan dijadwalkan (Minggu pukul 02.00)."
else
  echo "Backup mingguan dilewati."
fi

if [ "${DO_LOG,,}" = "y" ]; then
  ( sudo crontab -l 2>/dev/null | grep -v 'journalctl --vacuum-time' || true
    echo "0 3 * * * /usr/bin/journalctl --vacuum-time=14d" ) | sudo crontab -
  echo "Pembersihan log harian dijadwalkan (pukul 03.00)."
else
  echo "Pembersihan log harian dilewati."
fi

echo
echo "Selesai. Buka: https://${HOSTNAME_CF}"
echo "Cek jadwal dengan: crontab -l  dan  sudo crontab -l"