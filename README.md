# dev-heart

`dev-heart` adalah sistem automasi commit harian berbasis GitHub Actions yang dirancang untuk menjaga konsistensi kontribusi (GitHub contribution graph / green streak) secara stabil, teratur, dan bebas konflik.

---

## Fitur Utama

- **Jadwal Harian Otomatis**: Berjalan setiap malam pukul **23:00 WIB** (`16:00 UTC` / `0 16 * * *`).
- **Pola Alami & Dinamis**: Melakukan **8–12 commit acak** setiap harinya dengan interval antar-commit.
- **Anti-Konflik & Anti-Rejected**: Menggunakan mekanisme `git pull --rebase` sebelum `git push` di dalam workflow runner.
- **Trigger Terisolasi**: Hanya berjalan via scheduler cron dan `workflow_dispatch` (manual run dari tab Actions), tanpa trigger `push` agar tidak memicu dobel commit saat push manual dari komputer lokal.
- **Skrip Tambal Streak Manual (`patch.ps1`)**: Alat CLI PowerShell untuk menambal tanggal-tanggal lampau yang kosong atau terlewat.

---

## Skrip Patch Manual (`patch.ps1`)

Jika ada hari yang terlewat (misalnya repo sempat terjeda atau GitHub Actions mengalami maintenance), Anda dapat menambal tanggal tersebut secara manual dari komputer lokal.

### Cara Penggunaan

Buka PowerShell di direktori repositori:

1. **Menambal 1 Hari Tertentu:**
   ```powershell
   .\patch.ps1 -Start "2026-11-16"
   ```

2. **Menambal Rentang Tanggal:**
   ```powershell
   .\patch.ps1 -Start "2026-11-14" -End "2026-11-16"
   ```

### Alur Kerja `patch.ps1`:
1. Memeriksa status working tree lokal. Jika ada file yang belum dicommit, otomatis melakukan `git stash` agar aman.
2. Melakukan `git pull --rebase origin main` untuk menyelaraskan dengan commit terbaru di remote.
3. Melakukan loop pada setiap tanggal yang ditentukan, membuat **8–12 commit acak** dengan timestamp jam **23:00 WIB** (`+0700`).
4. Mengatur `GIT_AUTHOR_DATE` dan `GIT_COMMITTER_DATE` secara seragam agar tercatat sempurna di grafik kontribusi GitHub.
5. Melakukan `git pull --rebase` akhir dan `git push origin main`.
6. Memulihkan file dari stash (jika sebelumnya ada file yang distash).

---

## Konfigurasi GitHub Actions

Workflow terletak di [`.github/workflows/daily-commit.yml`](.github/workflows/daily-commit.yml):
- **Cron:** `0 16 * * *` (Pukul 23:00 WIB / 16:00 UTC)
- **Permissions:** `contents: write`
- **Actions Version:** `actions/checkout@v4` dengan `fetch-depth: 0`

> **Catatan GitHub Actions:**
> GitHub secara otomatis dapat menonaktifkan workflow berjadwal (cron) jika repositori tidak memiliki aktivitas commit sama sekali selama 60 hari berturut-turut. Karena `dev-heart` melakukan commit setiap hari ke branch utama, workflow akan selalu aktif. Jika sewaktu-waktu dinonaktifkan, cukup jalankan **Run workflow** dari tab **Actions** di GitHub atau jalankan `patch.ps1` dari lokal.
