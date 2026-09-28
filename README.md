<div align="center">

# Mise-Kal

**Sistem manajemen restoran yang di-host sendiri — kasir, layar dapur, dan manajemen dalam satu perangkat lunak.**

Gratis selamanya · Tanpa lisensi · Tanpa langganan · Tanpa telemetri · Data tetap di mesin Anda

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Android%20%7C%20iOS-blue)]()
[![Tests](https://img.shields.io/badge/tests-155%20passing-brightgreen)]()
[![Flutter](https://img.shields.io/badge/Flutter-3.47.5-02569B?logo=flutter)](https://flutter.dev)
[![PocketBase](https://img.shields.io/badge/PocketBase-0.40.1-000000)](https://pocketbase.io)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

[Fitur](#fitur) · [Instalasi](#instalasi) · [Pengembangan](#pengembangan) · [Arsitektur](#arsitektur) · [Roadmap](#roadmap)

</div>

---

## Apa ini

Mise-Kal adalah turunan dari **[Mise](https://github.com/devShakib015/mise)**, dikembangkan
secara independen sebagai proyek jangka panjang. Sistem ini menjalankan seluruh operasional
restoran di perangkat milik restoran itu sendiri — tanpa server cloud, tanpa akun, tanpa
biaya bulanan.

Karena servernya berjalan di lokasi, **kasir tetap bisa menerima pesanan saat internet mati.**
Untuk restoran, itu lebih penting daripada hampir semua hal lain.

> **Status:** pra-1.0, pengembangan aktif. Enam suite backend (101 pemeriksaan) dan
> 63 tes Dart lulus di Windows. Lokalisasi Indonesia sedang dikerjakan.

---

## Fitur

<table>
<tr><td width="50%" valign="top">

### 🧾 Kasir (POS)
- Denah meja dengan total bon langsung
- Pesan-antar ke dapur sekali sentuh
- Modifier, catatan dapur, jumlah
- Pembayaran sebagian dan pelunasan
- Diskon dengan alasan, tercatat di audit
- **Bekerja saat internet mati** — antrian lokal

</td><td width="50%" valign="top">

### 👨‍🍳 Layar Dapur (KDS)
- Pesanan muncul seketika, tanpa refresh
- Ketuk item: antre → dimasak → siap
- Timer menua: netral → kuning → merah
- Warna status dan warna umur **terpisah**, jadi tiket telat tetap terbaca

</td></tr>
<tr><td valign="top">

### 📊 Manajemen
- Menu: kategori, foto, modifier, stok habis
- Meja dan zona
- Staf: lima peran, reset PIN oleh manajer
- Laporan: per item, per pelayan, per jam
- Ekspor CSV untuk pembukuan

</td><td valign="top">

### 🖨️ Perangkat Keras
- Printer termal ESC/POS lewat TCP 9100
- Tanpa driver — hanya alamat dan lebar kertas
- Struk dan tiket dapur
- Fallback PDF

</td></tr>
</table>

### 📱 Pesanan dari Meja

Tamu memindai QR di mejanya dan memesan dari ponsel sendiri — halaman web, bukan aplikasi.
Hanya tiga rute publik yang terbuka; empat belas koleksi lainnya tetap khusus staf.
**Tidak ada harga yang datang dari permintaan** — semuanya diambil dari basis data.
Pesanan tamu masuk ke bon meja dalam keadaan **belum dikirim**; pelayan yang meneruskan,
sehingga orang asing di wi-fi tidak bisa menaruh makanan di pass.

---

## Empat aturan yang dijaga kode

Ini bukan preferensi gaya. Masing-masing ditegakkan di kode dan diuji.

| Aturan | Kenapa |
|---|---|
| **Uang hanya dihitung di server** | Kasir tidak boleh membiarkan klien yang dimanipulasi menentukan harga bon. Total palsu ditimpa. |
| **Nama dan harga menu di-snapshot ke baris pesanan** | Mengubah menu besok tidak boleh menulis ulang bon kemarin. |
| **Pendapatan dihitung saat bon ditutup**, bukan saat dibuka | Meja yang duduk sebelum shift berganti dan dibayar saat shift berjalan adalah pendapatan shift itu. |
| **Warna umur dan warna status terpisah** | Menggabungkannya membuat tiket telat yang penuh item dimasak jadi tidak terbaca. |

---

## Stack

| Lapisan | Pilihan | Alasan |
|---|---|---|
| Backend | [PocketBase](https://pocketbase.io) 0.40.1 | Satu biner: basis data, auth, realtime, penyimpanan berkas, UI admin |
| Aplikasi | Flutter 3.47.5 | Satu biner, tiga shell berbasis peran (POS / KDS / Manajer) |
| Basis data | SQLite (via PocketBase) | Tidak ada yang perlu dipasang |
| Cetak | ESC/POS lewat TCP 9100 | Yang dipakai hampir semua printer restoran |

---

## Instalasi

### Menjalankan dari sumber

Butuh **Flutter 3.47+** dan **Git Bash** (Windows) atau shell POSIX. Tidak ada yang lain —
PocketBase diunduh otomatis.

```bash
git clone https://github.com/thewoldaa/mise-kal.git
cd mise-kal

# Terminal 1 — server
./server/scripts/dev.sh

# Terminal 2 — aplikasi
cd app && flutter run -d windows    # atau -d macos / -d linux
```

Saat pertama dibuka, arahkan aplikasi ke `127.0.0.1:8090`.

### Membangun untuk Windows

```bash
installer/windows/build_windows.sh
```

> **Prasyarat:** Developer Mode harus aktif (Flutter butuh symlink untuk plugin native).
> Sekali saja, sebagai administrator: `start ms-settings:developers`
> Script akan memeriksa ini lebih dulu dan menjelaskan perbaikannya.

### Membangun untuk macOS

```bash
./installer/macos/build_dmg.sh
```

Menghasilkan DMG. Tidak ditandatangani kecuali `CODESIGN_IDENTITY` diatur — pengguna
membukanya lewat klik-kanan pertama kali, dan itu didokumentasikan di
[docs/install-macos.md](docs/install-macos.md).

---

## Pengembangan

```bash
# Sekali saja: unduh PocketBase dan jq ke cache
.harness/scripts/setup-tools.sh
.harness/scripts/worktree.sh doctor

# Buat worktree terisolasi untuk pekerjaan Anda
.harness/scripts/worktree.sh create --agent namaku --task t-001

# Jalankan semua suite
.harness/scripts/test.sh --agent namaku --all
```

### Harness multi-agent

Beberapa sub-agent dapat bekerja **bersamaan tanpa saling menimpa**. Setiap agent
mendapat worktree git sendiri, branch sendiri, blok port sendiri, dan direktori scratch
sendiri. Tidak ada yang dibagi kecuali object store git.

Pekerjaan diintegrasikan dalam **gelombang** terkontrol:

```
Gelombang 1   alpha: tugas A    beta: tugas B    gamma: tugas C
                    \                |                /
                     +---- integrasi ke main ------+
Gelombang 2   delta: membaca hasil Gelombang 1
```

Integrasi menolak mulai dari `main` yang kotor, menjalankan merge percobaan untuk
mendeteksi konflik **sebelum** apa pun mendarat, menjalankan seluruh suite pada hasil
merge, lalu memverifikasi setiap branch benar-benar menjadi leluhur `main`.

Selengkapnya di [`.harness/README.md`](.harness/README.md).

### Tes

```bash
.harness/scripts/test.sh --agent namaku --all       # semuanya
.harness/scripts/test.sh --agent namaku --suite smoke
.harness/scripts/test.sh --agent namaku --app
```

| Suite | Cakupan |
|---|---|
| `smoke` | Penomoran pesanan, harga modifier, pajak/layanan, void, total palsu |
| `setup` | Endpoint pertama-kali, bootstrap tidak bisa jalan dua kali |
| `kitchen` | Status bon mengikuti barisnya |
| `payments` | Pembayaran sebagian, pelunasan, diskon |
| `staff` | Reset PIN, penjagaan hak akses, restoran tidak bisa kehilangan pemilik terakhir |
| `guest` | Pesanan dari meja: harga dari basis data, isolasi rute |
| `app` | Dart: cetak, laporan, antrian offline, lokalisasi |

**101 + 63 = 164 pemeriksaan.**

---

## Arsitektur

```
                    ┌─────────────────────────────────────┐
                    │  PocketBase (satu biner, di lokasi) │
                    │  ┌───────────────┐ ┌─────────────┐  │
   Aplikasi Flutter │  │  migrasi      │ │   hooks     │  │
   (POS/KDS/Manajer)│  │  skema        │ │ no. pesanan │  │
        │           │  │               │ │ SEMUA UANG  │  │
        │           │  └───────────────┘ │ penjagaan   │  │
        │           │        SQLite       │ audit       │  │
        │           │                     └─────────────┘  │
        │           │  langganan realtime                 │
        │           └─────────────────────────────────────┘
        │                          ▲
        │                          │ HTTP (LAN saja)
   ESC/POS TCP 9100                │
   (printer termal)      ponsel tamu (QR, peramban)
```

Penjelasan lengkap ada di **[docs/architecture.md](docs/architecture.md)**.

---

## Roadmap

| Fase | Fokus | Status |
|---|---|---|
| 1 | Stabilkan implementasi + tes + installer | 🔄 Berjalan |
| 2 | Lokalisasi Indonesia | 🔄 Berjalan |
| 3 | Lapisan integrasi pembayaran/QRIS | 📋 Direncanakan |
| 4 | Notifikasi WhatsApp/bisnis | 📋 Direncanakan |
| 5 | Inventaris & stok | 📋 Direncanakan |
| 6 | Multi-cabang | 📋 Direncanakan |
| 7 | Dasbor pemilik | 📋 Direncanakan |
| 8 | Arsitektur backup/sinkronisasi | 📋 Direncanakan |
| 9 | Analitik / wawasan bisnis berbantuan AI | 📋 Direncanakan |
| 10 | Pengerasan produksi | 📋 Direncanakan |

Definisi tugas ada di [`.harness/tasks/`](.harness/tasks/).

---

## Berkontribusi

Baca **[CONTRIBUTING.md](CONTRIBUTING.md)** lebih dulu. Versi singkatnya:

```
inspeksi → rencana → implementasi → tes → commit → laporan
```

- Jangan pernah commit ke `main` — pakai branch `agent/<nama>/<tugas>`
- Jalankan suite sebelum commit
- Commit konvensional, isi pesan menjelaskan **kenapa**, bukan apa
- Jangan pernah menghapus fitur upstream yang berfungsi untuk menyederhanakan
- Jangan pernah commit kredensial — repo ini publik

---

## Keamanan

Model ancaman, jaminan yang dijaga kode, dan tabel tes yang membuktikan masing-masing
ada di **[SECURITY.md](SECURITY.md)**.

Laporkan kerentanan lewat
[private security advisory](https://github.com/thewoldaa/mise-kal/security/advisories/new),
bukan issue publik.

---

## Menghargai proyek asal

Mise-Kal berdiri di atas **[Mise](https://github.com/devShakib015/mise)** karya
**K M Shahriar Hossain**, yang menyusun postur keamanan dan keputusan desain yang
diwarisi proyek ini — terutama aturan bahwa uang hanya dihitung di server.

Lisensi MIT dipertahankan apa adanya; notice hak cipta upstream ada di [LICENSE](LICENSE).
Upstream tetap terpasang sebagai git remote sehingga perbaikan dapat diambil
secara sengaja:

```bash
git fetch upstream
git log --oneline main..upstream/main     # apa yang upstream punya, kita belum
git merge upstream/main                    # kalau memang layak diambil
```

---

## Lisensi

MIT — pakai, ubah, jalankan di restoran Anda, jual layanan di sekitarnya.
Yang penting: pertahankan notice hak cipta. Lihat [LICENSE](LICENSE).

<div align="center">

**Dibuat untuk restoran Indonesia** 🇮🇩

</div>
