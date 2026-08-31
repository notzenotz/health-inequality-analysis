# Laporan Kualitas Data

**Project:** Analisis Ketimpangan Layanan Kesehatan Antar Provinsi Indonesia
**Sumber:** Badan Pusat Statistik (BPS)
**Cakupan:** 38 provinsi
**Alat:** PostgreSQL 17, Power BI Desktop

---

## Sumber data

| Dataset | Tahun | Baris mentah | Status |
|---------|-------|--------------|--------|
| Jumlah Penduduk menurut Provinsi dan Jenis Kelamin | 2025 | 43 | Digunakan |
| Jumlah Rumah Sakit Umum, RS Khusus, dan Puskesmas menurut Provinsi | 2025 | 43 | Digunakan |
| Angka Harapan Hidup menurut Provinsi dan Jenis Kelamin | 2024 | 43 | Digunakan |
| Jumlah Tenaga Kesehatan menurut Provinsi | 2025 | 43 | **Tidak digunakan** |

### Catatan perbedaan tahun

Data penduduk dan fasilitas kesehatan sama-sama tahun 2025. Kesesuaian ini penting karena kedua tabel tersebut yang dibagi untuk menghasilkan rasio. Rasio antar tahun yang berbeda akan menghasilkan angka yang keliru.

Data Angka Harapan Hidup berasal dari 2024, satu tahun lebih awal. Perbedaan ini dinilai dapat diterima karena angka harapan hidup berubah sangat lambat, dalam kisaran sepersepuluh tahun per tahun, dan hanya digunakan untuk analisis korelasi.

Perlu dicatat bahwa pencampuran tahun **tidak dapat diterima** untuk analisis tren antar waktu. Analisis ini bersifat potret satu titik waktu, sehingga perbedaan satu tahun tidak mengganggu.

---

## Dataset yang dikeluarkan dari analisis

> **Temuan paling penting dalam project ini**

### Masalah

Dataset "Jumlah Tenaga Kesehatan Menurut Provinsi, 2025" semula direncanakan menjadi tabel keempat. Pemeriksaan awal menemukan bahwa nilai numeriknya rusak.

| Wilayah | Tenaga medis tercatat | Kewajaran |
|---------|----------------------|-----------|
| Indonesia (total nasional) | 583 | Mustahil |
| Aceh | 21 | Mustahil |
| Sumatera Utara | 24 | Mustahil |
| DKI Jakarta | 39 | Mustahil |

Total tenaga medis nasional yang tercatat 583 orang jelas tidak masuk akal untuk negara berpenduduk lebih dari 280 juta jiwa.

Kejanggalan juga terlihat pada kolom lain. Nilai "Tenaga Kesehatan Lingkungan" tercatat 1 untuk Aceh, 986 untuk Sumatera Utara, dan 487 untuk Riau. Lompatan sebesar itu tidak menunjukkan pola yang wajar, melainkan pecahan angka yang tergeser antar kolom.

### Penyebab

Angka aslinya menggunakan pemisah ribuan. Pada proses ekspor, angka tersebut terpotong sehingga hanya menyisakan bagian pertamanya, dan sebagian kolom bergeser posisinya.

Kerusakan terjadi **pada sumbernya**, bukan pada proses import. Hal ini dipastikan dengan memeriksa tiga bentuk penyajian yang berbeda:

1. Unduhan CSV: nilai rusak
2. Unduhan XLSX: nilai rusak, dan tersimpan sebagai teks alih-alih angka
3. Tampilan tabel di situs BPS: nilai rusak

Ketiganya menunjukkan nilai yang sama.

### Keputusan

Dataset dikeluarkan dari analisis.

**Nilai aslinya tidak direkonstruksi.** Secara teknis, pasangan angka yang terbelah mungkin dapat disusun ulang dengan menebak. Namun hasil tebakan tidak dapat diverifikasi, dan memasukkan angka hasil tebakan ke dalam analisis jauh lebih berbahaya daripada tidak memiliki datanya sama sekali.

### Dampak pada ruang lingkup

Pertanyaan awal "apakah suatu provinsi memiliki banyak fasilitas tetapi kekurangan tenaga medis" tidak dapat dijawab.

Sebagai penggantinya digunakan Angka Harapan Hidup. Pergantian ini justru memperkuat analisis, karena memungkinkan perbandingan antara **masukan** (ketersediaan fasilitas) dengan **hasil** (kondisi kesehatan penduduk), bukan sekadar perbandingan antar masukan.

### Pelajaran

Berkas tersebut terbuka normal, jumlah kolomnya benar, dan tidak menimbulkan pesan kesalahan apa pun. Apabila digunakan tanpa pemeriksaan, seluruh analisis akan salah tanpa ada mekanisme yang memberi peringatan.

Yang mendeteksinya hanya satu kebiasaan: **membandingkan angka dengan pengetahuan umum sebelum memakainya.** Total tenaga medis nasional 583 orang langsung terasa keliru karena skalanya jauh dari yang diketahui secara umum.

---

## Masalah pada dataset yang digunakan

### 1. Baris judul tersebar di beberapa baris

**Temuan**

| Berkas | Baris judul | Data mulai | Catatan kaki |
|--------|-------------|------------|--------------|
| Penduduk | 1–4 | baris 5 | tidak ada |
| AHH | 1–4 | baris 5 | tidak ada |
| Fasilitas | 1 | baris 2 | 3 baris terakhir |

Berkas penduduk dan AHH memuat judul yang terbagi ke dalam empat baris: nama tabel, judul kolom, dan tahun.

**Keputusan**

Import dilakukan dengan pengaturan Header dimatikan, sehingga seluruh baris masuk apa adanya. Baris judul dan catatan kaki kemudian disaring melalui SQL.

**Alasan tidak dirapikan manual di Excel**

Perubahan manual tidak meninggalkan catatan, tidak dapat diulang apabila data diperbarui, dan tidak dapat diperiksa oleh orang lain. Penyaringan melalui SQL membuat setiap langkah tersimpan sebagai query yang dapat dijalankan ulang.

**Cara penyaringan**

Digunakan dua syarat sekaligus:

```sql
WHERE provinsi ~ '[A-Za-z]'      -- kolom provinsi mengandung huruf
  AND kolom_angka ~ '^[0-9]'     -- kolom numerik diawali angka
```

Satu syarat saja tidak memadai. Baris `['', '2025', '2025', '2025']` memenuhi syarat kedua, sementara baris `['38 Provinsi', '', '', '']` memenuhi syarat pertama. Kedua syarat bersama-sama baru menangkap seluruh bentuk baris sampah.

---

### 2. Baris agregat nasional

**Temuan**

Ketiga berkas memuat baris `INDONESIA` yang berisi total nasional.

**Keputusan**

Dikeluarkan dari analisis.

**Alasan**

Baris tersebut bukan provinsi, melainkan penjumlahan seluruh baris di atasnya. Apabila ikut terbawa:

- Pada grafik, muncul sebagai batang raksasa yang mengerdilkan seluruh provinsi
- Pada perhitungan rata-rata, terhitung sebagai satu "provinsi" sehingga hasilnya melenceng
- Pada penggabungan tabel, tetap cocok dan ikut terbawa

Bagi database, `INDONESIA` merupakan teks biasa seperti `ACEH`. Tidak ada mekanisme yang memberitahu bahwa maknanya berbeda.

**Dampak**

39 baris data menjadi 38 baris provinsi.

---

### 3. Perbedaan penulisan nama provinsi

> **Masalah paling berisiko dalam project ini**

**Temuan**

Pemeriksaan menggunakan `EXCEPT` menemukan dua nama yang tidak cocok antar tabel:

| Tabel penduduk & AHH | Tabel fasilitas |
|----------------------|-----------------|
| KEP. BANGKA BELITUNG | KEPULAUAN BANGKA BELITUNG |
| KEP. RIAU | KEPULAUAN RIAU |

**Keputusan**

Bentuk `KEPULAUAN ...` diselaraskan menjadi `KEP. ...` melalui `CASE WHEN`, mengikuti penulisan pada tabel penduduk.

Arah penyeragaman ditetapkan satu kali dan diterapkan konsisten. Pilihan bentuk mana yang dijadikan acuan tidak penting, yang penting konsistensinya.

**Kenapa berbahaya**

Apabila tidak ditangani, kedua provinsi tersebut **hilang dari hasil INNER JOIN tanpa pesan error**. Hasilnya 36 baris alih-alih 38, dan tidak ada mekanisme yang memberi peringatan.

**Prosedur pencegahan yang diterapkan**

1. Sebelum JOIN: periksa kecocokan kunci menggunakan `EXCEPT`
2. Setelah JOIN: hitung jumlah baris hasil
3. Bandingkan dengan jumlah baris tabel sumber

Tiga kemungkinan hasil JOIN dan artinya:

| Hasil | Arti |
|-------|------|
| Sesuai harapan | Penggabungan benar |
| Berkurang | Ada nilai kunci yang tidak cocok |
| Bertambah | Kunci tidak unik, terjadi penggandaan |

---

### 4. Simbol untuk nilai nol

**Temuan**

Enam provinsi memuat simbol `–` pada kolom jumlah rumah sakit khusus: Kalimantan Utara, Papua Barat, Papua Barat Daya, Papua Selatan, Papua Tengah, dan Papua Pegunungan.

**Keputusan**

Dikonversi menjadi **0**, bukan NULL.

**Alasan**

Keterangan resmi BPS menyatakan bahwa simbol `–` berarti "tidak ada atau nol". BPS menggunakan simbol berbeda untuk arti yang berbeda:

| Simbol | Arti |
|--------|------|
| `–` | tidak ada atau nol |
| `...` | data tidak tersedia |
| `NA` | data tidak dapat ditampilkan |

Provinsi-provinsi tersebut benar-benar tidak memiliki rumah sakit khusus. Itu merupakan fakta, bukan data yang hilang.

**Dampak apabila keliru diperlakukan sebagai NULL**

Provinsi-provinsi tersebut akan dikeluarkan dari perhitungan rata-rata, padahal justru merekalah yang paling tertinggal ketersediaan fasilitasnya. Gambaran nasional yang dihasilkan akan lebih optimistis daripada kenyataannya.

**Prinsip**

Keterangan resmi sumber data harus dibaca sebelum menafsirkan simbol. Penafsiran berdasarkan bentuk simbol saja berisiko keliru.

---

### 5. Penggabungan kolom puskesmas

**Keputusan**

Kolom puskesmas rawat inap dan puskesmas non rawat inap dijumlahkan menjadi satu kolom `puskesmas_total`.

**Alasan**

Pertanyaan analisis adalah "berapa penduduk yang dilayani satu puskesmas", sehingga yang dibutuhkan adalah jumlah seluruh puskesmas.

Kolom aslinya tetap tersimpan pada tabel staging. Apabila pertanyaannya berubah, misalnya menjadi "apakah daerah terpencil kekurangan puskesmas rawat inap", pemisahan kolom dapat dilakukan kembali tanpa perlu mengimpor ulang.

**Prinsip**

Bentuk data mengikuti pertanyaan yang ingin dijawab, bukan sebaliknya.

---

### 6. Rata-rata angka harapan hidup

> **Keputusan berbasis penilaian**

**Keputusan**

AHH laki-laki dan perempuan dirata-rata menjadi satu angka menggunakan rata-rata sederhana.

**Keterbatasan**

Cara yang lebih tepat adalah rata-rata tertimbang berdasarkan jumlah penduduk masing-masing jenis kelamin. Selisihnya kecil karena komposisi laki-laki dan perempuan relatif seimbang di seluruh provinsi, tetapi keterbatasan ini tetap perlu dinyatakan.

---

### 7. Nama lokasi tidak dikenali layanan peta

**Temuan**

Setelah visualisasi peta dibuat, jumlah titik yang muncul kurang dari 38.

**Penyebab**

Power BI mengirim nama lokasi ke layanan peta untuk dicarikan koordinatnya (proses geocoding). Nama versi singkat `KEP. RIAU` dan `KEP. BANGKA BELITUNG` tidak dikenali, sehingga kedua provinsi tidak ditampilkan **tanpa pesan error apa pun**.

**Keputusan**

Ditambahkan kolom `provinsi_peta` berisi nama versi lengkap dengan penulisan Title Case, khusus untuk keperluan tampilan.

Kolom `provinsi` tetap dipertahankan sebagai kunci penggabungan. Mengubah kolom kunci demi keperluan tampilan berisiko merusak JOIN yang sudah terverifikasi.

Fungsi `INITCAP` digunakan untuk sebagian besar nama, tetapi empat provinsi ditulis manual karena `INITCAP` akan merusak singkatannya: `DKI` menjadi `Dki` dan `DI` menjadi `Di`.

**Pelajaran**

Kegagalan yang tidak menimbulkan pesan error muncul dalam dua bentuk berbeda pada project ini: pada JOIN dan pada geocoding. Keduanya hanya dapat dideteksi dengan menghitung jumlah hasil dan membandingkannya dengan angka yang diharapkan.

---

## Ringkasan transformasi

| Tahap | Jumlah baris |
|-------|--------------|
| Data mentah per berkas | 43 |
| Setelah baris judul dan catatan kaki disaring | 39 |
| Setelah baris agregat INDONESIA dikeluarkan | 38 |
| Hasil penggabungan tiga tabel | **38** |

Tidak ada baris yang hilang pada proses penggabungan.

---

## Keterbatasan analisis

1. **Rasio per penduduk tidak memperhitungkan jarak dan luas wilayah.** Dua provinsi dengan rasio yang sama dapat memiliki kondisi akses yang sangat berbeda. Empat belas rumah sakit yang tersebar di Papua Barat berbeda kondisinya dari 194 rumah sakit yang berdekatan di DKI Jakarta. Ukuran ini menjawab "berapa orang berbagi satu fasilitas", bukan "seberapa mudah menjangkaunya".

2. **Jumlah fasilitas tidak mencerminkan kapasitas maupun kualitas.** Satu rumah sakit dihitung sama, terlepas dari jumlah tempat tidur, kelengkapan peralatan, dan ketersediaan tenaga medisnya.

3. **Korelasi bukan sebab-akibat.** Hubungan lemah antara rasio fasilitas dan angka harapan hidup tidak membuktikan bahwa penambahan rumah sakit akan meningkatkan angka harapan hidup. Terdapat kemungkinan variabel perancu, misalnya tingkat perekonomian daerah yang mempengaruhi keduanya sekaligus.

4. **Data tenaga kesehatan tidak tersedia**, sehingga analisis tidak dapat membedakan provinsi yang kekurangan bangunan dari provinsi yang kekurangan tenaga medis.

5. **Perbedaan tahun sumber** satu tahun antara data AHH dengan data lainnya, sebagaimana dijelaskan di atas.
