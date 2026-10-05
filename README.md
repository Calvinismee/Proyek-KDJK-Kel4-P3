<div align="center">
  <img src="./images/code-server.svg" alt="code-server logo" width=500 style="margin-bottom: 2rem;"/>
  <h1>Aplikasi code-server</h1>
  <nav aria-label="Navigation">
    <a href="#sekilas-tentang">Sekilas Tentang</a> |
    <a href="#instalasi">Instalasi</a> |
    <a href="#konfigurasi">Konfigurasi</a> |
    <a href="#maintenance">Maintenance</a> |
    <a href="#otomatisasi">Otomatisasi</a> |
    <a href="#cara-pemakaian">Cara Pemakaian</a> |
    <a href="#pembahasan">Pembahasan</a> |
    <a href="#referensi">Referensi</a>
  </nav>
</div>
 
 
## Sekilas Tentang
 
<p><strong><a href="https://github.com/coder/code-server">code-server</a></strong> adalah aplikasi web open source yang menjalankan Visual Studio Code di server, sehingga bisa diakses lewat browser dari perangkat apa pun (laptop, tablet, atau Chromebook) tanpa menginstal VS Code di sisi klien. Proyek ini dikembangkan oleh <strong><a href="https://github.com/coder/">Coder</a></strong>.
Seluruh proses berat seperti kompilasi, menjalankan terminal, dan debugging dijalankan di server, sedangkan browser hanya menampilkan antarmukanya. Karena itu lingkungan pengembangan menjadi seragam dan terpusat. Spesifikasi perangkat klien juga tidak terlalu berpengaruh, selama server cukup kuat.
 
 
## Instalasi
 
### Prasyarat
- Linux atau macOS (64-bit). Pada proyek ini digunakan Ubuntu Server 26.04 LTS.
- Akun pengguna non-root dengan hak `sudo`.
- `curl` terpasang dan koneksi internet aktif.
- Server dengan RAM 1 GB (disarankan 2 GB atau lebih), CPU 2 core.
- Browser (Chrome, Firefox, Edge, atau Safari).
- Domain

Catatan: record domain di-*set* dengan bantuan Cloudflare dan domain akan diarahkan ke Cloudflare Tunnel

### Langkah Instalasi
 
Langkah di bawah berlaku untuk Ubuntu/Debian.
 
1. Perbarui sistem dan pasang `curl`:
```bash
   sudo apt update && sudo apt upgrade -y
   sudo apt install -y curl
```
 
2. Pasang code-server dengan skrip resmi. Di Ubuntu, skrip ini akan memasang paket `.deb`:
```bash
   curl -fsSL https://code-server.dev/install.sh | sh
```
 
3. Periksa hasil instalasi:
```bash
   code-server --version
```
 
4. Aktifkan code-server sebagai layanan agar berjalan otomatis:
```bash
   sudo systemctl enable --now code-server@$USER
```
 
5. Atur `~/.config/code-server/config.yaml`. **code-server** cukup mendengarkan di `127.0.0.1` karena akses dari internet dilewatkan melalui Cloudflare Tunnel yang berjalan di server yang sama:
```yaml
   bind-addr: 127.0.0.1:8080
   auth: password
   password: "<YOUR-PASSWORD>"
   cert: false
```
 
   Restart layanan:
 
```bash
   sudo systemctl restart code-server@$USER
```
 
6. Pasang `cloudflared`:
```bash
   curl -fL -o cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
   sudo dpkg -i cloudflared.deb
```
 
7. Login ke Cloudflare. Salin URL yang ditampilkan di terminal dan buka di browser. Lalu pilih domain Anda:
```bash
   cloudflared tunnel login
```
 
8. Buat tunnel dan arahkan subdomain ke tunnel tersebut (ganti `<YOUR-DOMAIN>` dengan hostname Anda):
```bash
   cloudflared tunnel create codeserver
   cloudflared tunnel route dns codeserver <YOUR-DOMAIN>
```
 
9. Siapkan konfigurasi di `/etc/cloudflared/`. Ganti `<ID_TUNNEL>` dengan ID dari langkah sebelumnya. Ganti juga `<YOUR-DOMAIN>`:
```bash
   sudo mkdir -p /etc/cloudflared
   sudo cp ~/.cloudflared/<ID_TUNNEL>.json /etc/cloudflared/
   sudo tee /etc/cloudflared/config.yml > /dev/null <<EOF
   tunnel: <ID_TUNNEL>
   credentials-file: /etc/cloudflared/<ID_TUNNEL>.json
   ingress:
     - hostname: <YOUR-DOMAIN>
       service: http://localhost:8080
     - service: http_status:404
   EOF
```
 
10. Jalankan sebagai layanan agar berjalan otomatis:
```bash
    sudo cloudflared service install
    sudo systemctl status cloudflared
```
 
11. Buka `https://<YOUR-DOMAIN>` dan masukkan password.
Catatan:
- Untuk uji coba tanpa domain, gunakan *Quick Tunnel*: `cloudflared tunnel --url http://localhost:8080`. Cloudflare menampilkan URL sementara `https://xxxx.trycloudflare.com` yang berubah setiap tunnel dijalankan ulang dan berhenti jika terminal ditutup.

## Konfigurasi
 
### Batas memori
 
code-server tidak memiliki pengaturan batas memori sendiri, sehingga batasnya dipasang lewat *systemd*. Ganti `1G` sesuai kebutuhan.
 
```bash
sudo mkdir -p /etc/systemd/system/code-server@$USER.service.d
sudo tee /etc/systemd/system/code-server@$USER.service.d/override.conf > /dev/null <<'EOF'
[Service]
MemoryMax=1G
EOF
```

 
Simpan, lalu terapkan:
 
```bash
sudo systemctl daemon-reload
sudo systemctl restart code-server@$USER
```
Untuk memeriksa apakah perubahan sudah diterapkan, jalankan:
```bash
systemctl show code-server@$USER -p MemoryMax
```

### Ekstensi
 
Plugin pada code-server berupa ekstensi VS Code yang diambil dari registry [Open VSX](https://open-vsx.org), sehingga sebagian ekstensi dari Microsoft Marketplace tidak tersedia. Ekstensi dapat dipasang lewat panel **Extensions** atau CLI:
 
```bash
code-server --install-extension yzhang.markdown-all-in-one
code-server --list-extensions
```
 
## Maintenance
 
code-server tidak menggunakan database. Program code-server dapat dipasang
ulang dengan skrip instalasi, sehingga yang perlu dicadangkan adalah
konfigurasi, ekstensi, dan folder proyek.
 
### Backup konfigurasi, ekstensi, dan proyek (mingguan)
 
Buat skrip `~/backup-code-server.sh` berikut. Ganti nilai `PROJECT_DIR` jika
nama folder proyek di home berbeda:
 
```bash
#!/bin/bash
BACKUP_DIR="$HOME/backup"
PROJECT_DIR="project"
mkdir -p "$BACKUP_DIR"
 
tar -czf "$BACKUP_DIR/code-server-$(date +%F).tar.gz" \
  -C "$HOME" .config/code-server .local/share/code-server "$PROJECT_DIR"
 
# Hapus backup yang lebih lama dari 28 hari.
find "$BACKUP_DIR" -name 'code-server-*.tar.gz' -mtime +28 -delete
```
 
Beri izin eksekusi pada skrip:
 
```bash
chmod +x ~/backup-code-server.sh
```
 
Pastikan folder proyek sudah ada sebelum skrip dijalankan karena `tar` akan
gagal jika folder tersebut tidak ditemukan. Jadwalkan backup setiap Minggu
pukul 02.00 dengan `crontab -e`:
 
```cron
0 2 * * 0 /home/<username>/backup-code-server.sh
```
 
Untuk memulihkan konfigurasi, jalankan kembali skrip instalasi code-server,
lalu ekstrak arsip backup ke home:
 
```bash
tar -xzf code-server-<tanggal>.tar.gz -C ~
```
 
### Pembersihan log (harian)
 
Gunakan `sudo crontab -e` untuk menambahkan pembersihan journal setiap hari
pukul 03.00. Perintah ini menyimpan log selama 14 hari terakhir:
 
```cron
0 3 * * * /usr/bin/journalctl --vacuum-time=14d
```
 
### Pembaruan dan pemantauan
 
Perbarui sistem secara berkala, lalu periksa status layanan dan log
code-server:
 
```bash
sudo apt update && sudo apt upgrade -y
systemctl status code-server@$USER
journalctl -u code-server@$USER -n 50
```
 
Jika muncul pesan *System restart required*, jalankan `sudo reboot`.
**code-server** akan aktif kembali secara otomatis karena layanannya sudah
di-*enable* melalui systemd.

## Otomatisasi
Terdapat cara alternatif yang lebih mudah untuk melakukan instalasi aplikasi, yakni menggunakan script shell yang otomatis akan menjalankan semua perintah instalasi pada terminal. Script shell yang dapat digunakan adalah [install.sh](install.sh)

Cara pemakaian skrip adalah sebagai berikut.
```bash
chmod +x install.sh
./install.sh
```

## Cara Pemakaian
- Tampilan aplikasi web
- Fungsi-fungsi utama
- Isi dengan data real/dummy (jangan kosongan) dan sertakan beberapa screenshot

## Pembahasan
- Pendapat anda tentang aplikasi web ini
  - kelebihan
  - kekurangan
- Bandingkan dengan aplikasi web lain yang sejenis
 
## Referensi
1. https://coder.com/docs/code-server/install
2. https://github.com/coder/code-server
3. https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/
4. https://developers.cloudflare.com/cloudflare-one/applications/
5. https://docs.gitlab.com/topics/cron/
6. https://open-vsx.org
