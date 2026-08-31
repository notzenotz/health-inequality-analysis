# Ketimpangan Layanan Kesehatan Antar Provinsi Indonesia

Analisis ketersediaan fasilitas kesehatan di 38 provinsi Indonesia, menggabungkan tiga dataset BPS untuk menghitung rasio penduduk per fasilitas dan menguji hubungannya dengan angka harapan hidup.

**Alat:** PostgreSQL 17, pgAdmin 4, Power BI Desktop

![Dashboard](dashboard.png)

---

## Latar belakang

Keputusan pembangunan fasilitas kesehatan sering didasarkan pada jumlah fasilitas yang tersedia di suatu daerah. Angka mentah tersebut menyesatkan, karena tidak memperhitungkan jumlah penduduk yang harus dilayani.

Pertanyaan yang dijawab:

1. Berapa jumlah penduduk yang dilayani oleh satu rumah sakit di tiap provinsi?
2. Provinsi mana yang paling tertinggal, dan berapa besar jurangnya?
3. Apakah ketersediaan fasilitas berhubungan dengan angka harapan hidup penduduknya?

---

## Data

| Dataset | Tahun | Sumber |
|---------|-------|--------|
| Jumlah Penduduk menurut Provinsi | 2025 | BPS |
| Jumlah Rumah Sakit dan Puskesmas menurut Provinsi | 2025 | BPS |
| Angka Harapan Hidup menurut Provinsi | 2024 | BPS |

Cakupan: 38 provinsi. Ketiga tabel digabungkan menggunakan nama provinsi sebagai kunci.

Satu dataset tambahan (Jumlah Tenaga Kesehatan menurut Provinsi) **tidak digunakan** karena ditemukan rusak pada sumbernya. Penjelasan lengkap ada di bagian berikutnya.

---

## Alur pengerjaan

```
3 berkas CSV BPS
    ↓
stg_penduduk, stg_fasilitas, stg_ahh    Tabel staging, seluruh kolom TEXT
    ↓
Profiling                                Identifikasi masalah + cek kecocokan kunci
    ↓
Pembersihan                              Saring baris judul, seragamkan nama provinsi
    ↓
JOIN tiga tabel                          Hitung rasio penduduk per fasilitas
    ↓
health_clean (38 baris)                  Tabel siap analisis
    ↓
Dashboard Power BI                       Peta, batang peringkat, scatter
```

Seluruh kolom pada tabel staging dibuat bertipe `TEXT` secara sengaja, karena berkas sumber memuat baris judul dan catatan kaki yang tercampur dengan baris data.

Baris judul dan catatan kaki disaring melalui SQL, bukan diedit manual di Excel, agar seluruh proses tercatat dan dapat dijalankan ulang.

---

## Dataset yang dikeluarkan dari analisis

Dataset tenaga kesehatan semula direncanakan menjadi tabel keempat. Pemeriksaan menemukan nilainya rusak:

| Wilayah | Tenaga medis tercatat |
|---------|----------------------|
| **Indonesia (total nasional)** | **583** |
| Aceh | 21 |
| DKI Jakarta | 39 |

Total nasional 583 orang jelas mustahil. Penyebabnya: angka dengan pemisah ribuan terpotong pada proses ekspor.

Kerusakan dipastikan terjadi pada sumbernya, bukan pada proses import, dengan memeriksa tiga bentuk penyajian yang berbeda: unduhan CSV, unduhan XLSX, dan tampilan tabel di situs BPS. Ketiganya menunjukkan nilai yang sama.

**Dataset dikeluarkan, dan nilai aslinya tidak direkonstruksi.** Rekonstruksi secara teknis mungkin dilakukan dengan menebak, tetapi hasilnya tidak dapat diverifikasi. Memasukkan angka hasil tebakan ke dalam analisis lebih berbahaya daripada tidak memiliki datanya.

Berkas tersebut terbuka normal dan tidak menimbulkan pesan kesalahan apa pun. Yang mendeteksinya hanya pembandingan angka dengan pengetahuan umum sebelum data digunakan.

---

## Masalah kualitas data

| Masalah | Penanganan |
|---------|------------|
| Judul kolom tersebar di 4 baris | Import dengan Header dimatikan, saring melalui pola |
| Baris agregat `INDONESIA` | Dikeluarkan, karena bukan provinsi melainkan total |
| Nama provinsi berbeda antar tabel | Diseragamkan sebelum penggabungan |
| Simbol `–` pada kolom numerik | Dikonversi jadi 0, sesuai keterangan resmi BPS |
| Nama tidak dikenali layanan peta | Ditambahkan kolom nama versi lengkap |

Dua di antaranya perlu disorot karena keduanya **gagal tanpa pesan error**.

**Nama provinsi yang tidak cocok.** Pemeriksaan menggunakan `EXCEPT` menemukan `KEP. RIAU` pada satu tabel tertulis `KEPULAUAN RIAU` pada tabel lain, begitu pula Bangka Belitung. Tanpa penyeragaman, kedua provinsi akan hilang dari hasil `INNER JOIN`, menghasilkan 36 baris alih-alih 38, tanpa peringatan apa pun.

**Nama tidak dikenali layanan peta.** Nama versi singkat `KEP. RIAU` tidak dikenali oleh layanan geocoding Power BI, sehingga provinsi tersebut tidak muncul di peta, juga tanpa peringatan.

Keduanya hanya dapat dideteksi dengan menghitung jumlah hasil dan membandingkannya dengan angka yang diharapkan. Prosedur ini diterapkan pada setiap tahap.

Dokumentasi lengkap seluruh masalah beserta alasan tiap keputusan tersedia di [`docs/data_quality_report.md`](docs/data_quality_report.md).

---

## Temuan

### 1. Jurang 4,4 kali lipat antar provinsi

| Ukuran | Nilai |
|--------|-------|
| Rata-rata nasional | 78.617 penduduk per rumah sakit |
| Terbaik (Papua Barat) | 42.027 |
| Terburuk (Papua Pegunungan) | 185.794 |

### 2. Angka mentah menghasilkan kesimpulan yang berlawanan

**Jawa Barat memiliki jumlah rumah sakit terbanyak se-Indonesia (436), namun masuk lima besar dengan beban terberat.**

| Provinsi | Penduduk | Jumlah RS | Penduduk per RS |
|----------|----------|-----------|-----------------|
| Papua Pegunungan | 1.486.352 | 8 | 185.794 |
| Nusa Tenggara Barat | 5.738.081 | 46 | 124.741 |
| **Jawa Barat** | **50.942.801** | **436** | **116.841** |
| Lampung | 9.531.282 | 83 | 114.835 |
| Papua Tengah | 1.493.906 | 14 | 106.708 |

Terlihat pula dua jenis ketimpangan yang berbeda dan memerlukan penanganan berbeda:

- **Kelangkaan fasilitas** (Papua Pegunungan): penduduk sedikit, fasilitas sangat sedikit
- **Tekanan kepadatan** (Jawa Barat): fasilitas banyak, penduduk jauh lebih banyak

### 3. Ketersediaan fasilitas hanya berhubungan lemah dengan angka harapan hidup

Korelasi antara rasio penduduk per rumah sakit dengan angka harapan hidup: **−0,280**.

Arah hubungannya sesuai dugaan, yaitu semakin banyak penduduk per rumah sakit maka angka harapan hidup cenderung lebih rendah. Namun kekuatannya lemah, di bawah ambang 0,3.

Hal ini terlihat jelas pada empat provinsi Papua yang masuk sepuluh besar rasio terbaik, tetapi angka harapan hidupnya justru termasuk yang terendah:

| Provinsi | Penduduk per RS | Angka Harapan Hidup |
|----------|-----------------|---------------------|
| Papua Barat | 42.027 (terbaik) | 67,10 (rendah) |
| DI Yogyakarta | 47.291 | 75,53 (tertinggi) |
| Papua Barat Daya | 53.099 | 67,85 (rendah) |
| Papua | 56.566 | 68,78 (rendah) |

Rasio yang baik pada provinsi Papua disebabkan jumlah penduduk yang sedikit, bukan jumlah fasilitas yang banyak.

**Kesimpulan: menambah jumlah bangunan rumah sakit saja tidak cukup.** Faktor lain seperti kualitas layanan, ketersediaan tenaga medis, gizi, sanitasi, tingkat kemiskinan, dan akses transportasi kemungkinan berperan lebih besar.

**Catatan:** korelasi tidak membuktikan sebab-akibat. Terdapat kemungkinan variabel perancu, misalnya tingkat perekonomian daerah yang mempengaruhi ketersediaan fasilitas dan kondisi kesehatan penduduk sekaligus.

---

## Rekomendasi

1. **Gunakan rasio, bukan jumlah mentah, sebagai dasar alokasi anggaran.** Provinsi dengan jumlah fasilitas terbanyak dapat sekaligus menjadi provinsi dengan beban terberat.

2. **Bedakan penanganan untuk dua jenis ketimpangan.** Wilayah dengan kelangkaan fasilitas memerlukan pembangunan baru, sementara wilayah dengan tekanan kepadatan memerlukan peningkatan kapasitas fasilitas yang ada.

3. **Jangan menjadikan jumlah fasilitas sebagai satu-satunya indikator keberhasilan.** Hubungan yang lemah dengan angka harapan hidup menunjukkan bahwa ketersediaan bangunan hanya salah satu faktor.

4. **Perbaiki kualitas data tenaga kesehatan di sumbernya.** Data tersebut tidak dapat digunakan dalam kondisi saat ini, padahal merupakan komponen penting untuk menilai kesiapan layanan kesehatan.

---

## Struktur repositori

```
health-inequality-analysis/
├── README.md
├── dashboard.png
├── sql/
│   ├── 01_staging.sql          Tabel staging dan import
│   ├── 02_profiling.sql        Identifikasi masalah dan cek kecocokan kunci
│   ├── 03_cleaning.sql         Pembersihan per tabel
│   └── 04_join_analysis.sql    JOIN tiga tabel dan analisis
├── docs/
│   └── data_quality_report.md
└── dashboard/
    └── dashboard_health.pbix
```

Seluruh berkas SQL disertai komentar yang menjelaskan temuan dan alasan setiap keputusan.

---

## Keterbatasan

1. **Rasio per penduduk tidak memperhitungkan jarak dan luas wilayah.** Ukuran ini menjawab "berapa orang berbagi satu fasilitas", bukan "seberapa mudah menjangkaunya".

2. **Jumlah fasilitas tidak mencerminkan kapasitas maupun kualitas.** Satu rumah sakit dihitung sama, terlepas dari jumlah tempat tidur dan kelengkapan peralatannya.

3. **Korelasi bukan sebab-akibat.** Hubungan yang teramati tidak membuktikan arah pengaruhnya, dan terdapat kemungkinan variabel perancu.

4. **Data tenaga kesehatan tidak tersedia**, sehingga analisis tidak dapat membedakan kekurangan bangunan dari kekurangan tenaga medis.

5. **Data AHH berasal dari tahun 2024**, satu tahun lebih awal dari data lainnya. Dapat diterima karena angka harapan hidup berubah lambat dan analisis ini bersifat potret satu titik waktu, bukan analisis tren.
