<div align="center">
  <img src="./images/logo.webp" alt="VS Code Logo" width="300">
  <h1>Aplikasi code-server</h1>
  <nav aria-label="Navigation">
    <a href="#sekilas-tentang">Sekilas Tentang</a> |
    <a href="#instalasi">Instalasi</a> |
    <a href="#opsi-akses">Opsi Akses</a> |
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
- Linux atau macOS (64-bit). Pada proyek ini digunakan Ubuntu Server 22.04 LTS.
- Akun pengguna non-root dengan hak `sudo`.
- `curl` terpasang dan koneksi internet aktif.
- RAM minimal 1 GB (disarankan 2 GB atau lebih), CPU 2 core.
- Browser modern di sisi klien (Chrome, Firefox, Edge, atau Safari).

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

5. Atur `~/.config/code-server/config.yaml`. Nilai `bind-addr` bergantung pada opsi akses:

   | Opsi | `bind-addr` |
   | --- | --- |
   | Lokal | `0.0.0.0:8080` |
   | Quick Tunnel | `127.0.0.1:8080` |
   | Domain sendiri | `127.0.0.1:8080` |

   Contoh untuk Opsi 1:

   ```yaml
   bind-addr: 0.0.0.0:8080
   auth: password
   password: GantiDenganPasswordKuat
   cert: false
   ```

   Restart layanan:

   ```bash
   sudo systemctl restart code-server@$USER
   ```

6. Lanjutkan ke salah satu opsi akses di bawah.

### Opsi Akses

#### Opsi 1: Secara lokal (*localhost*)

Pada server VirtualBox dengan mode **NAT** (ciri: IP `10.0.2.15`), VM tidak dapat dijangkau langsung dari laptop sehingga diperlukan *port forwarding*.

1. Pastikan code-server mendengarkan di semua antarmuka:

   ```bash
   ss -tlnp | grep 8080
   ```

   Hasilnya harus menampilkan `0.0.0.0:8080`. Jika masih `127.0.0.1`, ulangi langkah 5.

2. Tambahkan aturan *port forwarding* di VirtualBox. Melalui GUI, buka **Settings > Network > Adapter 1 > Advanced > Port Forwarding**, lalu isi:

   | Name | Protocol | Host IP | Host Port | Guest IP | Guest Port |
   | --- | --- | --- | --- | --- | --- |
   | code-server | TCP | `127.0.0.1` | `8080` | `10.0.2.15` | `8080` |

   Atau melalui CLI di laptop host, ganti `NAMA_VM` dengan nama VM:

   ```bash
   VBoxManage controlvm "NAMA_VM" natpf1 "code-server,tcp,127.0.0.1,8080,,8080"
   ```

   Jika VM sedang mati, gunakan:

   ```bash
   VBoxManage modifyvm "NAMA_VM" --natpf1 "code-server,tcp,127.0.0.1,8080,,8080"
   ```

3. Jika `ufw` aktif di server, izinkan port tersebut:

   ```bash
   sudo ufw allow 8080/tcp
   ```

4. Di laptop host, buka `http://localhost:8080` lalu masukkan password. Karena alamatnya `localhost`, browser menganggapnya sebagai *secure context*, sehingga clipboard dan webview ekstensi dapat berfungsi.

   Karena Host IP diisi `127.0.0.1`, hanya laptop tersebut yang dapat mengaksesnya, bukan perangkat lain di jaringan.

**Jika bukan VirtualBox NAT:**

- *VirtualBox Bridged Adapter* atau server fisik tidak memerlukan *port forwarding*. Buka `http://<ip_server>:8080` dari laptop, cek IP dengan `hostname -I`, lalu jalankan `sudo ufw allow 8080/tcp`. Akses ini menggunakan HTTP biasa, sehingga password tidak terenkripsi dan sebagian fitur browser dapat terbatas.
- Alternatif tanpa membuka port: ubah `bind-addr` menjadi `127.0.0.1:8080`, lalu dari **laptop** (bukan dari dalam server) jalankan:

  ```bash
  ssh -L 8080:localhost:8080 <username>@<ip_server>
  ```

#### Opsi 2: Cloudflare Tunnel (*Quick Tunnel*)
Opsi ini bertujuan agar aplikasi dapat diakses dari internet tanpa domain dan tanpa membuka port.

1. Pasang `cloudlared`

 ```bash
 curl -fL -o cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
 sudo dpkg -i cloudflared.deb
  ```
2. Lakukan *Quick Tunnel*
```bash
cloudflared tunnel --url http://localhost:8080
```

Cloudflare akan menampilkan URL seperti `https://xxxx.trycloudflare.com`. URL ini berubah setiap kali tunnel dijalankan ulang dan tunnel berhenti jika terminal ditutup, sehingga cocok untuk uji coba atau demo.

#### Opsi 3: Domain sendiri (*named tunnel* Cloudflare)

URL tetap, HTTPS, dan tunnel berjalan otomatis sebagai layanan. Pada VirtualBox NAT, *port forwarding* juga tidak diperlukan.

1. Pasang `cloudflared` menggunakan perintah yang sama seperti pada Opsi 2.
2. Login, lalu buka URL yang muncul di browser laptop dan pilih domain Anda:

   ```bash
   cloudflared tunnel login
   ```

3. Buat tunnel dan arahkan subdomain ke tunnel tersebut:

   ```bash
   cloudflared tunnel create codeserver
   cloudflared tunnel route dns codeserver code.namaanda.eu.org
   ```

4. Siapkan konfigurasi di `/etc/cloudflared/`. Ganti `<ID_TUNNEL>` dengan ID dari langkah sebelumnya:

   ```bash
   sudo mkdir -p /etc/cloudflared
   sudo cp ~/.cloudflared/<ID_TUNNEL>.json /etc/cloudflared/
   sudo tee /etc/cloudflared/config.yml > /dev/null <<EOF
   tunnel: <ID_TUNNEL>
   credentials-file: /etc/cloudflared/<ID_TUNNEL>.json
   ingress:
     - hostname: code.namaanda.eu.org
       service: http://localhost:8080
     - service: http_status:404
   EOF
   ```

5. Jalankan sebagai layanan:

   ```bash
   sudo cloudflared service install
   sudo systemctl status cloudflared
   ```

6. Buka `https://code.namaanda.eu.org` dan masukkan password.

## Konfigurasi

### Batas memori

code-server tidak memiliki pengaturan batas memori sendiri, sehingga batasnya dipasang lewat *systemd*:

```bash
sudo systemctl edit code-server@$USER
```

Isi dengan:

```ini
[Service]
MemoryMax=<BATAS-MEMORI> # Contoh 1G
```

Simpan, lalu terapkan:

```bash
sudo systemctl daemon-reload
sudo systemctl restart code-server@$USER
```

### Ekstensi

Plugin pada code-server berupa ekstensi VS Code yang diambil dari registry [Open VSX](https://open-vsx.org), sehingga sebagian ekstensi dari Microsoft Marketplace tidak tersedia. Ekstensi dapat dipasang lewat panel **Extensions** atau CLI:

```bash
code-server --install-extension yzhang.markdown-all-in-one
code-server --list-extensions
```

## Maintenance

code-server tidak menggunakan database. Program code-server dapat dipasang
ulang dengan skrip instalasi. Hal yang perlu di-*backup* adalah
konfigurasi, ekstensi, dan folder proyek.

### Backup konfigurasi, ekstensi, dan proyek

Buat skrip `~/backup-code-server.sh` berikut. Ganti nilai `PROJECT_DIR` jika
nama folder proyek di home berbeda:

```bash
#!/bin/bash
BACKUP_DIR="$HOME/backup"
PROJECT_DIR="project"
mkdir -p "$BACKUP_DIR"

tar -czf "$BACKUP_DIR/code-server-$(date +%F).tar.gz" \
  -C "$HOME" .config/code-server .local/share/code-server "$PROJECT_DIR"
```
Selanjutnya, hapus file *backup* yang sudah lebih dari 28 hari (angka ini dapat disesuaikan dengan keinginan)
```bash
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

* Jadwal CRON dapat diganti sesuai keinginan. Panduan terkait *syntax* CRON dapat diakses [di sini](https://docs.gitlab.com/topics/cron/)

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
5. https://developers.cloudflare.com/cloudflare-one/identity/idp-integration/google/
6. https://docs.gitlab.com/topics/cron/
7. https://open-vsx.org