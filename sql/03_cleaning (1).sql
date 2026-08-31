-- =====================================================================
-- 03_CLEANING.SQL
-- Tujuan : Membersihkan ketiga tabel dan menyeragamkan kunci penggabungan
-- Hasil  : 38 baris per tabel (39 baris data dikurangi 1 baris agregat)
-- =====================================================================
--
-- Metode: setiap tabel diuji terpisah terlebih dahulu, hasilnya
-- diverifikasi jumlah barisnya, baru digabungkan pada tahap berikutnya.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. TABEL PENDUDUK
-- ---------------------------------------------------------------------
-- Baris agregat 'INDONESIA' dikeluarkan.
--
-- Baris tersebut bukan provinsi, melainkan penjumlahan seluruh baris
-- di atasnya. Jika ikut terbawa:
--   - Pada grafik, muncul sebagai batang raksasa yang mengerdilkan
--     seluruh provinsi
--   - Pada rata-rata, terhitung sebagai satu "provinsi" sehingga
--     hasilnya melenceng
--   - Pada JOIN, tetap cocok dan ikut terbawa tanpa peringatan
--
-- Bagi database, 'INDONESIA' hanyalah teks biasa seperti 'ACEH'.
-- Tidak ada mekanisme yang memberitahu bahwa maknanya berbeda.
--
-- Verifikasi: 38 baris

SELECT
  UPPER(TRIM(provinsi)) AS provinsi,
  CAST(TRIM(jumlah) AS BIGINT) AS jumlah_penduduk
FROM stg_penduduk
WHERE provinsi ~ '[A-Za-z]'
  AND laki_laki ~ '^[0-9]'
  AND UPPER(TRIM(provinsi)) <> 'INDONESIA'
ORDER BY provinsi;


-- ---------------------------------------------------------------------
-- 2. TABEL FASILITAS
-- ---------------------------------------------------------------------
-- Tiga penanganan sekaligus:
--
-- (a) Penyeragaman nama provinsi sebagai kunci penggabungan.
--     Bentuk 'KEPULAUAN ...' diselaraskan menjadi 'KEP. ...' mengikuti
--     penulisan pada tabel penduduk. Arah penyeragaman ditetapkan satu
--     kali dan diterapkan konsisten.
--
-- (b) Konversi '–' menjadi 0, sesuai keterangan resmi BPS bahwa simbol
--     tersebut berarti "tidak ada atau nol".
--
-- (c) Penggabungan puskesmas rawat inap dan non rawat inap menjadi satu
--     kolom. Pertanyaan analisis adalah "berapa penduduk per puskesmas",
--     sehingga yang dibutuhkan adalah totalnya. Kolom aslinya tetap
--     tersimpan di tabel staging apabila diperlukan kemudian.
--
-- Verifikasi: 38 baris

SELECT
  CASE
    WHEN UPPER(TRIM(provinsi)) = 'KEPULAUAN BANGKA BELITUNG' THEN 'KEP. BANGKA BELITUNG'
    WHEN UPPER(TRIM(provinsi)) = 'KEPULAUAN RIAU'            THEN 'KEP. RIAU'
    ELSE UPPER(TRIM(provinsi))
  END AS provinsi,
  CAST(TRIM(rs_umum) AS INT) AS rs_umum,
  CASE WHEN TRIM(rs_khusus) = '–' THEN 0
       ELSE CAST(TRIM(rs_khusus) AS INT) END AS rs_khusus,
  CAST(TRIM(puskesmas_rawat_inap) AS INT)
    + CAST(TRIM(puskesmas_non_rawat) AS INT) AS puskesmas_total
FROM stg_fasilitas
WHERE provinsi ~ '[A-Za-z]'
  AND rs_umum ~ '^[0-9]'
  AND UPPER(TRIM(provinsi)) <> 'INDONESIA'
ORDER BY provinsi;


-- ---------------------------------------------------------------------
-- 3. TABEL ANGKA HARAPAN HIDUP
-- ---------------------------------------------------------------------
-- AHH laki-laki dan perempuan dirata-rata menjadi satu angka.
--
-- Catatan keterbatasan: ini rata-rata sederhana, bukan rata-rata
-- tertimbang berdasarkan jumlah penduduk tiap jenis kelamin. Selisihnya
-- kecil karena komposisi laki-laki dan perempuan relatif seimbang di
-- seluruh provinsi, tetapi keterbatasan ini tetap dicatat.
--
-- Verifikasi: 38 baris

SELECT
  UPPER(TRIM(provinsi)) AS provinsi,
  ROUND((CAST(TRIM(laki_laki) AS NUMERIC)
       + CAST(TRIM(perempuan) AS NUMERIC)) / 2, 2) AS ahh_rata2
FROM stg_ahh
WHERE provinsi ~ '[A-Za-z]'
  AND laki_laki ~ '^[0-9]'
  AND UPPER(TRIM(provinsi)) <> 'INDONESIA'
ORDER BY provinsi;
