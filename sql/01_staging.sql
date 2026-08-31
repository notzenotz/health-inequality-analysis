-- =====================================================================
-- 01_STAGING.SQL
-- Tujuan  : Membuat tabel penampung dan memuat tiga dataset BPS
-- Database: health_project (PostgreSQL 17)
-- =====================================================================
--
-- Sumber data:
--   1. Jumlah Penduduk menurut Provinsi dan Jenis Kelamin, 2025 (BPS)
--   2. Jumlah Rumah Sakit Umum, Rumah Sakit Khusus, Puskesmas Rawat Inap,
--      dan Puskesmas Non Rawat Inap Menurut Provinsi, 2025 (BPS)
--   3. Angka Harapan Hidup (AHH) Menurut Provinsi dan Jenis Kelamin, 2024 (BPS)
--
-- Ketiga berkas berisi 43 baris: 4 baris judul, 38 provinsi,
-- 1 baris agregat nasional, dan beberapa baris catatan kaki.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Membuat tabel staging
-- ---------------------------------------------------------------------
-- Seluruh kolom bertipe TEXT secara sengaja.
--
-- Alasan: data mentah memuat baris judul dan catatan kaki yang tercampur
-- dengan baris data. Jika kolom langsung diberi tipe numerik, proses
-- import akan gagal saat menemui baris non-numerik tersebut.
--
-- Jumlah kolom mengikuti struktur berkas masing-masing (4, 5, dan 3).

CREATE TABLE stg_penduduk (
    provinsi   TEXT,
    laki_laki  TEXT,
    perempuan  TEXT,
    jumlah     TEXT
);

CREATE TABLE stg_fasilitas (
    provinsi              TEXT,
    rs_umum               TEXT,
    rs_khusus             TEXT,
    puskesmas_rawat_inap  TEXT,
    puskesmas_non_rawat   TEXT
);

CREATE TABLE stg_ahh (
    provinsi   TEXT,
    laki_laki  TEXT,
    perempuan  TEXT
);


-- ---------------------------------------------------------------------
-- 2. Import data
-- ---------------------------------------------------------------------
-- Dimuat melalui fitur Import/Export pgAdmin dengan pengaturan:
--   Format    : csv
--   Header    : DIMATIKAN
--   Delimiter : ,
--   Encoding  : UTF8
--
-- Header sengaja dimatikan. Dua dari tiga berkas memiliki judul kolom
-- yang tersebar di empat baris, sementara pgAdmin hanya dapat
-- memperlakukan satu baris sebagai judul. Jika Header diaktifkan, tiga
-- baris judul sisanya tetap masuk sebagai data.
--
-- Baris judul dan catatan kaki dibuang pada tahap pembersihan melalui
-- SQL, bukan diedit manual di Excel, agar seluruh proses tercatat dan
-- dapat dijalankan ulang (reproducible).


-- ---------------------------------------------------------------------
-- 3. Perbaikan nama kolom
-- ---------------------------------------------------------------------
-- Terdapat kesalahan pengetikan pada pembuatan tabel awal
-- ("puskemas" tanpa huruf s). Diperbaiki tanpa menghapus data.

ALTER TABLE stg_fasilitas
RENAME COLUMN puskemas_rawat_inap TO puskesmas_rawat_inap;

-- Memeriksa struktur tabel melalui metadata
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'stg_fasilitas'
ORDER BY ordinal_position;


-- ---------------------------------------------------------------------
-- 4. Verifikasi jumlah baris
-- ---------------------------------------------------------------------
-- Hasil yang diharapkan: 43 untuk ketiga tabel.
--
-- UNION ALL dipakai agar ketiga tabel dapat diperiksa dalam satu query.
-- Berbeda dengan JOIN yang menggabungkan ke samping (menambah kolom),
-- UNION menggabungkan ke bawah (menambah baris).

SELECT 'penduduk'  AS tabel, COUNT(*) FROM stg_penduduk
UNION ALL
SELECT 'fasilitas', COUNT(*) FROM stg_fasilitas
UNION ALL
SELECT 'ahh',       COUNT(*) FROM stg_ahh;
