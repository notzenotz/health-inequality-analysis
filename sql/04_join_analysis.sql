-- =====================================================================
-- 04_JOIN_ANALYSIS.SQL
-- Tujuan : Menggabungkan tiga tabel, menghitung rasio, dan menganalisis
-- Hasil  : health_clean (38 baris)
-- =====================================================================


-- =====================================================================
-- BAGIAN A: PENGGABUNGAN DAN PEMBENTUKAN TABEL BERSIH
-- =====================================================================
--
-- Struktur JOIN:
--   FROM tabel_kiri x
--   INNER JOIN tabel_kanan y ON x.kunci = y.kunci
--
-- Alias (p, f, a) wajib digunakan karena ketiga tabel memiliki kolom
-- bernama 'provinsi'. Tanpa alias, database tidak dapat menentukan
-- kolom mana yang dimaksud.
--
-- Penggabungan tiga tabel dilakukan bertahap: tabel pertama digabung
-- dengan kedua, hasilnya digabung dengan ketiga.
--
-- INNER JOIN dipilih karena ketiga tabel seharusnya memuat provinsi
-- yang sama persis. Baris yang tidak cocok menandakan ada masalah,
-- bukan kondisi yang wajar.
--
-- PERINGATAN: INNER JOIN membuang baris yang tidak cocok tanpa pesan
-- error. Jumlah baris hasil WAJIB diverifikasi.
--
-- Tiga kemungkinan hasil JOIN:
--   Sesuai harapan -> penggabungan benar
--   Berkurang      -> ada nilai kunci yang tidak cocok
--   Bertambah      -> kunci tidak unik, terjadi penggandaan (fan-out)
--
-- Rasio dihitung pada tahap ini:
--   penduduk_per_rs        = jumlah penduduk / total rumah sakit
--   penduduk_per_puskesmas = jumlah penduduk / total puskesmas
--
-- Semakin BESAR angkanya, semakin BURUK keadaannya. Arah pembacaan ini
-- berlawanan dengan kebiasaan umum dan perlu dinyatakan eksplisit pada
-- setiap penyajian.
--
-- Tanda ::NUMERIC diperlukan karena pembagian antar bilangan bulat di
-- PostgreSQL membuang pecahannya (7 / 2 menghasilkan 3, bukan 3.5).

CREATE TABLE health_clean AS
WITH penduduk AS (
  SELECT UPPER(TRIM(provinsi)) AS provinsi,
         CAST(TRIM(jumlah) AS BIGINT) AS jumlah_penduduk
  FROM stg_penduduk
  WHERE provinsi ~ '[A-Za-z]' AND laki_laki ~ '^[0-9]'
    AND UPPER(TRIM(provinsi)) <> 'INDONESIA'
),
fasilitas AS (
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
  WHERE provinsi ~ '[A-Za-z]' AND rs_umum ~ '^[0-9]'
    AND UPPER(TRIM(provinsi)) <> 'INDONESIA'
),
ahh AS (
  SELECT UPPER(TRIM(provinsi)) AS provinsi,
         ROUND((CAST(TRIM(laki_laki) AS NUMERIC)
              + CAST(TRIM(perempuan) AS NUMERIC)) / 2, 2) AS ahh_rata2
  FROM stg_ahh
  WHERE provinsi ~ '[A-Za-z]' AND laki_laki ~ '^[0-9]'
    AND UPPER(TRIM(provinsi)) <> 'INDONESIA'
)
SELECT
  p.provinsi,
  p.jumlah_penduduk,
  f.rs_umum,
  f.rs_khusus,
  f.rs_umum + f.rs_khusus AS rs_total,
  f.puskesmas_total,
  a.ahh_rata2,
  ROUND(p.jumlah_penduduk::NUMERIC / (f.rs_umum + f.rs_khusus)) AS penduduk_per_rs,
  ROUND(p.jumlah_penduduk::NUMERIC / f.puskesmas_total)         AS penduduk_per_puskesmas
FROM penduduk p
INNER JOIN fasilitas f ON p.provinsi = f.provinsi
INNER JOIN ahh       a ON p.provinsi = a.provinsi;


-- Verifikasi hasil JOIN. Diharapkan: 38
SELECT COUNT(*) FROM health_clean;

-- Verifikasi silang terhadap tabel sumber. Harus menghasilkan angka
-- yang sama. Jika hasil JOIN lebih sedikit, berarti ada kunci yang
-- tidak cocok.
SELECT COUNT(*) FROM stg_penduduk
WHERE provinsi ~ '[A-Za-z]' AND laki_laki ~ '^[0-9]'
  AND UPPER(TRIM(provinsi)) <> 'INDONESIA';


-- ---------------------------------------------------------------------
-- Kolom tambahan untuk keperluan peta
-- ---------------------------------------------------------------------
-- Power BI mengirim nama lokasi ke layanan peta untuk dicarikan
-- koordinatnya (geocoding). Nama versi singkat 'KEP. RIAU' dan
-- 'KEP. BANGKA BELITUNG' tidak dikenali, sehingga dua provinsi tidak
-- muncul di peta TANPA pesan error.
--
-- Ditambahkan kolom terpisah berisi nama versi lengkap. Kolom
-- 'provinsi' tetap dipertahankan sebagai kunci penggabungan, karena
-- mengubahnya berisiko merusak JOIN.
--
-- INITCAP dipakai untuk sebagian besar nama, tetapi empat provinsi
-- ditulis manual karena INITCAP akan merusak singkatannya
-- ('DKI' menjadi 'Dki', 'DI' menjadi 'Di').

ALTER TABLE health_clean ADD COLUMN provinsi_peta TEXT;

UPDATE health_clean
SET provinsi_peta = CASE
    WHEN provinsi = 'KEP. BANGKA BELITUNG' THEN 'Kepulauan Bangka Belitung'
    WHEN provinsi = 'KEP. RIAU'            THEN 'Kepulauan Riau'
    WHEN provinsi = 'DI YOGYAKARTA'        THEN 'DI Yogyakarta'
    WHEN provinsi = 'DKI JAKARTA'          THEN 'DKI Jakarta'
    ELSE INITCAP(provinsi)
END;


-- =====================================================================
-- BAGIAN B: ANALISIS
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Sepuluh provinsi dengan beban rumah sakit terberat
-- ---------------------------------------------------------------------
-- Hasil:
--   PAPUA PEGUNUNGAN      1.486.352 penduduk    8 RS   185.794 per RS
--   NUSA TENGGARA BARAT   5.738.081            46      124.741
--   JAWA BARAT           50.942.801           436      116.841
--   LAMPUNG               9.531.282            83      114.835
--   PAPUA TENGAH          1.493.906            14      106.708
--   JAWA TENGAH          38.261.423           369      103.689
--   SUMATERA SELATAN      8.935.870            89      100.403
--   KALIMANTAN BARAT      5.771.745            59       97.826
--   SULAWESI BARAT        1.527.159            16       95.447
--   JAWA TIMUR           42.111.119           442       95.274
--
-- TEMUAN PENTING: Jawa Barat memiliki jumlah rumah sakit TERBANYAK
-- se-Indonesia (436), namun masuk lima besar dengan beban terberat.
-- Angka mentah menghasilkan kesimpulan yang berlawanan dengan rasio.
--
-- Terlihat pula dua jenis ketimpangan yang berbeda:
--   Papua Pegunungan : kelangkaan fasilitas (penduduk sedikit,
--                      fasilitas sangat sedikit)
--   Jawa Barat       : tekanan kepadatan (fasilitas banyak, penduduk
--                      jauh lebih banyak)
-- Keduanya menghasilkan rasio buruk, tetapi memerlukan penanganan
-- kebijakan yang berbeda.

SELECT provinsi, jumlah_penduduk, rs_total, penduduk_per_rs
FROM health_clean
ORDER BY penduduk_per_rs DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- 2. Sepuluh provinsi dengan beban rumah sakit teringan
-- ---------------------------------------------------------------------
-- Hasil (rasio / AHH):
--   PAPUA BARAT            42.027 / 67,10
--   KALIMANTAN UTARA       44.126 / 72,78
--   SULAWESI UTARA         45.384 / 72,75
--   DI YOGYAKARTA          47.291 / 75,53
--   PAPUA BARAT DAYA       53.099 / 67,85
--   KEP. BANGKA BELITUNG   53.531 / 71,54
--   BALI                   54.433 / 73,34
--   DKI JAKARTA            55.280 / 74,18
--   GORONTALO              56.519 / 69,14
--   PAPUA                  56.566 / 68,78
--
-- TEMUAN: empat provinsi Papua masuk sepuluh besar rasio terbaik,
-- namun angka harapan hidupnya justru termasuk yang terendah.
--
-- Penjelasannya: rasio bagus di wilayah tersebut disebabkan jumlah
-- penduduk yang sedikit, bukan jumlah fasilitas yang banyak.
--
-- Keterbatasan ukuran: rasio penduduk per fasilitas tidak
-- memperhitungkan luas wilayah dan jarak tempuh. Empat belas rumah
-- sakit yang tersebar di Papua Barat sangat berbeda kondisinya dari
-- 194 rumah sakit yang berdekatan di DKI Jakarta, meskipun rasionya
-- dapat terlihat setara.

SELECT provinsi, jumlah_penduduk, rs_total, penduduk_per_rs, ahh_rata2
FROM health_clean
ORDER BY penduduk_per_rs ASC
LIMIT 10;


-- ---------------------------------------------------------------------
-- 3. Ringkasan ketimpangan dan korelasi
-- ---------------------------------------------------------------------
-- Hasil:
--   Rata-rata nasional : 78.617 penduduk per rumah sakit
--   Terbaik            : 42.027  (Papua Barat)
--   Terburuk           : 185.794 (Papua Pegunungan)
--   Jurang             : 4,4 kali lipat
--   Korelasi rasio-AHH : -0,280
--
-- CARA MEMBACA KORELASI:
-- Nilai berkisar antara -1 dan 1.
--   mendekati +1 : dua hal naik bersamaan
--   mendekati  0 : tidak ada hubungan
--   mendekati -1 : satu naik, satu turun
--
-- Nilai -0,280 berarti arah hubungannya sesuai dugaan (semakin banyak
-- penduduk per rumah sakit, angka harapan hidup cenderung lebih rendah)
-- tetapi kekuatannya LEMAH.
--
-- Patokan kasar kekuatan korelasi:
--   0,0 - 0,3 lemah | 0,3 - 0,5 sedang | 0,5 - 0,7 cukup kuat
--   0,7 - 1,0 kuat
--
-- KESIMPULAN: ketersediaan rumah sakit hanya menjelaskan sebagian kecil
-- perbedaan angka harapan hidup antar provinsi. Faktor lain seperti
-- kualitas layanan, ketersediaan tenaga medis, gizi, sanitasi, tingkat
-- kemiskinan, dan akses transportasi kemungkinan berperan lebih besar.
--
-- CATATAN PENTING: korelasi bukan sebab-akibat. Terdapat tiga
-- kemungkinan penjelasan atas hubungan yang teramati:
--   (1) A menyebabkan B
--   (2) B menyebabkan A
--   (3) Ada faktor C yang menyebabkan keduanya (variabel perancu)
--
-- Kemungkinan ketiga sangat relevan di sini: provinsi dengan
-- perekonomian lebih kuat cenderung memiliki lebih banyak fasilitas
-- kesehatan DAN penduduk yang lebih sehat. Kekayaan daerah dapat
-- menjadi penyebab keduanya.

SELECT
  ROUND(AVG(penduduk_per_rs))                           AS rata_rata,
  MIN(penduduk_per_rs)                                  AS terbaik,
  MAX(penduduk_per_rs)                                  AS terburuk,
  ROUND(MAX(penduduk_per_rs) / MIN(penduduk_per_rs), 1) AS jurang_kali_lipat,
  ROUND(CORR(penduduk_per_rs, ahh_rata2)::NUMERIC, 3)   AS korelasi
FROM health_clean;
