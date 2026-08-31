-- =====================================================================
-- 02_PROFILING.SQL
-- Tujuan : Mengidentifikasi masalah kualitas data sebelum pembersihan
-- Sumber : stg_penduduk, stg_fasilitas, stg_ahh (43 baris masing-masing)
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Melihat struktur data mentah
-- ---------------------------------------------------------------------

-- Tabel penduduk: baris 1-4 berisi judul yang tersebar
--   Baris 1 : '38 Provinsi'
--   Baris 2 : judul tabel
--   Baris 3 : 'Laki-Laki', 'Perempuan', 'Jumlah'
--   Baris 4 : '2025'
--   Baris 5 : data pertama (ACEH)
SELECT * FROM stg_penduduk LIMIT 8;

-- Tabel AHH memiliki struktur yang sama
SELECT * FROM stg_ahh LIMIT 8;

-- Tabel fasilitas: judul di baris 1, data mulai baris 2,
-- catatan kaki pada tiga baris terakhir
SELECT * FROM stg_fasilitas LIMIT 5;
SELECT * FROM stg_fasilitas OFFSET 38;


-- ---------------------------------------------------------------------
-- 2. Memisahkan baris data dari baris judul dan catatan kaki
-- ---------------------------------------------------------------------
-- Digunakan dua syarat sekaligus:
--   provinsi ~ '[A-Za-z]'   -> kolom provinsi mengandung huruf
--   kolom_angka ~ '^[0-9]'  -> kolom numerik diawali angka
--
-- Kedua syarat diperlukan karena satu syarat saja tidak cukup:
--   Baris ['', '2025', '2025', '2025'] lolos syarat kedua
--   Baris ['38 Provinsi', '', '', ''] lolos syarat pertama
--
-- Tanda ^ berarti "di awal teks". Tanpa ^, pola [0-9] akan cocok
-- dengan angka di posisi mana pun.
--
-- Hasil: 39 baris (38 provinsi + 1 baris agregat INDONESIA)

SELECT provinsi, laki_laki
FROM stg_penduduk
WHERE provinsi ~ '[A-Za-z]'
  AND laki_laki ~ '^[0-9]';

SELECT provinsi, rs_umum
FROM stg_fasilitas
WHERE provinsi ~ '[A-Za-z]'
  AND rs_umum ~ '^[0-9]';


-- ---------------------------------------------------------------------
-- 3. Memeriksa tanda '–' pada tabel fasilitas
-- ---------------------------------------------------------------------
-- Temuan: 6 provinsi memiliki nilai '–' pada kolom rs_khusus, yaitu
-- Kalimantan Utara, Papua Barat, Papua Barat Daya, Papua Selatan,
-- Papua Tengah, dan Papua Pegunungan.
--
-- Menurut keterangan resmi BPS, simbol '–' berarti "tidak ada atau nol",
-- BUKAN "data tidak tersedia". BPS memakai simbol berbeda untuk arti
-- berbeda:
--   '–'   : tidak ada atau nol
--   '...' : data tidak tersedia
--   'NA'  : data tidak dapat ditampilkan
--
-- Karena itu nilai ini dikonversi menjadi 0, bukan NULL.
-- Jika keliru diperlakukan sebagai NULL, provinsi-provinsi tersebut
-- akan dikeluarkan dari perhitungan rata-rata, padahal justru merekalah
-- yang paling tertinggal ketersediaan fasilitasnya.

SELECT provinsi, rs_khusus
FROM stg_fasilitas
WHERE rs_khusus = '–';


-- ---------------------------------------------------------------------
-- 4. Memeriksa kecocokan nama provinsi antar tabel
-- ---------------------------------------------------------------------
-- Pemeriksaan paling penting sebelum penggabungan.
--
-- EXCEPT menampilkan baris yang ada pada query pertama tetapi tidak
-- ditemukan pada query kedua. Dipakai untuk menemukan nilai kunci yang
-- tidak akan cocok saat JOIN.
--
-- Temuan: 2 nama tidak cocok
--   Tabel penduduk        Tabel fasilitas
--   KEP. BANGKA BELITUNG  KEPULAUAN BANGKA BELITUNG
--   KEP. RIAU             KEPULAUAN RIAU
--
-- Konsekuensi jika tidak ditangani: kedua provinsi akan hilang saat
-- INNER JOIN, menghasilkan 36 baris alih-alih 38, TANPA pesan error
-- apa pun. Inilah sebabnya jumlah baris wajib diperiksa setiap kali
-- selesai melakukan JOIN.

SELECT UPPER(TRIM(provinsi)) AS nama
FROM stg_penduduk
WHERE provinsi ~ '[A-Za-z]' AND laki_laki ~ '^[0-9]'

EXCEPT

SELECT UPPER(TRIM(provinsi))
FROM stg_fasilitas
WHERE provinsi ~ '[A-Za-z]' AND rs_umum ~ '^[0-9]';


-- ---------------------------------------------------------------------
-- 5. Catatan: dataset yang dikeluarkan dari analisis
-- ---------------------------------------------------------------------
-- Dataset "Jumlah Tenaga Kesehatan Menurut Provinsi, 2025" semula
-- direncanakan menjadi tabel keempat, tetapi TIDAK DIGUNAKAN.
--
-- Alasan: nilai numerik pada sumbernya rusak. Angka dengan pemisah
-- ribuan terpotong sehingga hanya menyisakan bagian pertamanya.
--
-- Bukti kerusakan:
--   Total tenaga medis Indonesia tercatat 583
--   Aceh tercatat 21, Sumatera Utara 24, DKI Jakarta 39
--
-- Angka tersebut mustahil untuk skala nasional maupun provinsi.
-- Kerusakan terjadi pada sumber (bukan pada proses import), karena
-- nilai yang sama muncul pada unduhan CSV, unduhan XLSX, maupun
-- tampilan tabel di situs BPS.
--
-- Dataset dikeluarkan karena tidak dapat diverifikasi. Nilai aslinya
-- tidak direkonstruksi, karena hasil rekonstruksi hanya akan berupa
-- perkiraan yang tidak dapat dipertanggungjawabkan.
--
-- Sebagai gantinya digunakan Angka Harapan Hidup, yang memungkinkan
-- analisis membandingkan ketersediaan fasilitas (masukan) dengan
-- kondisi kesehatan penduduk (hasil).
