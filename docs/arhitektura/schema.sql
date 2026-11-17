-- =====================================================================
-- SIN Base - šema baze (SQLite)                     docs/arhitektura/
-- Ulaz za SDD. Odgovara Flyway migraciji V1__sema.sql.
-- Izvor: ER dijagram "ShemaBazePodataka" (Visual Paradigm), SRS v1.1
--        poglavlja 4 i 6. Odluka o bazi: ADR-001-baza.md.
--
-- KONVENCIJE
--  1. Tabele su STRICT (SQLite >= 3.37): samo INTEGER i TEXT, a tip se
--     provjerava pri upisu (bez STRICT SQLite prihvata i tekst u INTEGER koloni).
--  2. Enumi: INTEGER + CHECK (... IN (...)). Značenje kodova je u Java
--     enumu i u komentaru ispod; u bazi nema tabela s nazivima enuma.
--  3. Datumi: ISO-8601 tekst 'YYYY-MM-DD' (bez vremena). CHECK odbija
--     neispravne datume (npr. '2026-02-30').
--  4. Iznosi: cijeli broj feninga (1 KM = 100 fening), kolone imaju sufiks
--     _fening. Nikad REAL: 12,15 KM je 1215.
--  5. Nazivi: snake_case bez dijakritika (broj_polise, ne "broj polise").
--  6. SQLite ne provodi dužinu iz VARCHAR(n), zato je dužina CHECK(length()).
--  7. Strani ključevi rade samo uz PRAGMA foreign_keys=ON na SVAKOJ vezi
--     (JDBC URL: jdbc:sqlite:<putanja>?foreign_keys=on).
--
-- KODOVI ENUMA
--  osiguravajuca_kuca : 0 ASA, 1 EUROHERC, 2 EUROS, 3 GRAWE, 4 TRIGLAV
--  vrsta_vozila       : 0 putničko, 1 teretno, 2 moped, 3 motocikl,
--                       4 prikolica, 5 radna mašina
--  kategorija (putarina_tabela): 0 putnički (M1, mjeri se u cm3),
--                       1 N1, 2 N2, 3 N3, 4 autobus M2/M3 (1-4 u kg)
--  pogon_grupa        : 0 dizel/benzin, 1 LPG/CNG/hibrid
--  gorivo (zastita_okoline): 0 dizel, 1 benzin
--  tip (ao_razred)    : 0 malus (P14-P7), 1 osnovni (P6), 2 bonus (P5-P1)
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. EVIDENCIJA: Stranka (ER dijagram, SRS poglavlje 6)
--    Primarni ključ je broj polise: obnova = novi zapis (pitanje 11).
-- ---------------------------------------------------------------------
CREATE TABLE stranka (
    broj_polise                 TEXT    NOT NULL PRIMARY KEY
        CHECK (length(broj_polise) BETWEEN 1 AND 30 AND broj_polise = trim(broj_polise)),
    ime                         TEXT    NOT NULL
        CHECK (length(trim(ime)) BETWEEN 1 AND 50),
    prezime                     TEXT    NOT NULL
        CHECK (length(trim(prezime)) BETWEEN 1 AND 60),
    broj_telefona               TEXT
        CHECK (broj_telefona IS NULL OR length(broj_telefona) BETWEEN 1 AND 20),
    osiguravajuca_kuca          INTEGER NOT NULL
        CHECK (osiguravajuca_kuca IN (0, 1, 2, 3, 4)),
    vrsta_vozila                INTEGER NOT NULL
        CHECK (vrsta_vozila IN (0, 1, 2, 3, 4, 5)),
    ime_vozila                  TEXT    NOT NULL
        CHECK (length(trim(ime_vozila)) BETWEEN 1 AND 255),
    pocetak_registracije        TEXT    NOT NULL
        CHECK (date(pocetak_registracije) IS NOT NULL AND date(pocetak_registracije) = pocetak_registracije),
    kraj_registracije           TEXT    NOT NULL
        CHECK (date(kraj_registracije) IS NOT NULL AND date(kraj_registracije) = kraj_registracije),
    cijena_registracije_fening  INTEGER NOT NULL
        CHECK (cijena_registracije_fening BETWEEN 0 AND 9999999999),   -- ER: iznos (10)
    napomena                    TEXT
        CHECK (napomena IS NULL OR length(napomena) <= 255),
    CHECK (kraj_registracije >= pocetak_registracije)
) STRICT;

-- Obavještenja o isteku (EVD-09, EVD-10): upit po kraju registracije.
CREATE INDEX idx_stranka_kraj_registracije ON stranka (kraj_registracije);
-- Pretraga i sortiranje po prezimenu/imenu (EVD-07, EVD-08).
CREATE INDEX idx_stranka_prezime_ime ON stranka (prezime, ime);


-- ---------------------------------------------------------------------
-- 2. POSTAVKE (key-value): samo skalarne postavke aplikacije.
--    Vrijednost je tekst; tip i opseg za svaki ključ provjerava
--    aplikacija, a za poznate ključeve i CHECK. Novi ključ je običan
--    INSERT, bez izmjene šeme.
--      prag_upozorenja_dana : cijeli broj 1-365 (zadano 20)   POS-02
--      rezim_prikaza        : 0 dnevni, 1 noćni (zadano 0)    POS-03
-- ---------------------------------------------------------------------
CREATE TABLE postavke (
    kljuc       TEXT NOT NULL PRIMARY KEY
        CHECK (length(kljuc) BETWEEN 1 AND 60),
    vrijednost  TEXT NOT NULL,
    opis        TEXT,
    CHECK (CASE kljuc
        WHEN 'prag_upozorenja_dana'
            THEN vrijednost NOT GLOB '*[^0-9]*' AND length(vrijednost) BETWEEN 1 AND 3
                 AND CAST(vrijednost AS INTEGER) BETWEEN 1 AND 365
        WHEN 'rezim_prikaza'
            THEN vrijednost IN ('0', '1')
        ELSE 1 END)
) STRICT;


-- ---------------------------------------------------------------------
-- 3. FIKSNE NAKNADE (POS-01, NFR-05): jedine tabele čije vrijednosti
--    korisnik mijenja u radu, pa nisu u "zakonskim" tabelama.
--    Jedan red = jedna naknada. Novu naknadu dodaje INSERT, ne kod.
--    Računanje: SELECT SUM(iznos_fening) FROM fiksna_naknada
--               WHERE vrsta_vozila IS NULL OR vrsta_vozila = :vrsta;
--    AMK ima dva reda (putničko 9 KM, teretno 15 KM).
--    zadani_iznos_fening se ne mijenja iz Postavki: omogućava
--    "Vrati na zadano" i razlikovanje ručno izmijenjenih redova.
-- ---------------------------------------------------------------------
CREATE TABLE fiksna_naknada (
    kod                   TEXT    NOT NULL PRIMARY KEY
        CHECK (length(kod) BETWEEN 1 AND 40 AND kod NOT GLOB '*[^a-z_]*'),
    naziv                 TEXT    NOT NULL
        CHECK (length(trim(naziv)) BETWEEN 1 AND 60),
    vrsta_vozila          INTEGER
        CHECK (vrsta_vozila IS NULL OR vrsta_vozila IN (0, 1)),  -- NULL = sve vrste
    iznos_fening          INTEGER NOT NULL CHECK (iznos_fening >= 0),
    zadani_iznos_fening   INTEGER NOT NULL CHECK (zadani_iznos_fening >= 0),
    redoslijed            INTEGER NOT NULL
) STRICT;


-- ---------------------------------------------------------------------
-- 4. ZAKONSKI PODACI (seed, samo za čitanje iz aplikacije).
--    Mijenjaju se isključivo novom Flyway migracijom (pitanje 13).
-- ---------------------------------------------------------------------

-- 4a. Putarina, zaglavlje: jedan red = jedna izvorna tabela (1-11).
--     Pretraga tabele: kategorija + pogon_grupa + broj_osovina.
--     pogon_grupa NULL = tabela ne razlikuje pogon (N2, N3, autobusi).
--     broj_osovina NULL = ne zavisi od osovina; 4 znači "četiri i više".
CREATE TABLE putarina_tabela (
    tabela_br     INTEGER NOT NULL PRIMARY KEY CHECK (tabela_br BETWEEN 1 AND 11),
    naziv         TEXT    NOT NULL,
    kategorija    INTEGER NOT NULL CHECK (kategorija IN (0, 1, 2, 3, 4)),
    pogon_grupa   INTEGER CHECK (pogon_grupa IS NULL OR pogon_grupa IN (0, 1)),
    broj_osovina  INTEGER CHECK (broj_osovina IS NULL OR broj_osovina IN (2, 3, 4))
) STRICT;

CREATE UNIQUE INDEX uq_putarina_tabela_kljuc
    ON putarina_tabela (kategorija, COALESCE(pogon_grupa, -1), COALESCE(broj_osovina, -1));

-- 4b. Putarina, razredi. Raspon je cm3 (kategorija 0) ili kg (ostalo),
--     oba kraja uključena; raspon_do NULL = "preko". Ukupno = 60% + 40%.
--     Pretraga: WHERE tabela_br = :t AND :v >= raspon_od
--                 AND (raspon_do IS NULL OR :v <= raspon_do)
--     Koja se kolona koristi u cijeni nije riješeno (pitanje 1), zato
--     se čuvaju sve tri.
CREATE TABLE putarina_razred (
    tabela_br      INTEGER NOT NULL REFERENCES putarina_tabela (tabela_br),
    raspon_od      INTEGER NOT NULL CHECK (raspon_od >= 0),
    raspon_do      INTEGER CHECK (raspon_do IS NULL OR raspon_do >= raspon_od),
    ukupno_fening  INTEGER NOT NULL CHECK (ukupno_fening > 0),
    dio60_fening   INTEGER NOT NULL CHECK (dio60_fening > 0),
    dio40_fening   INTEGER NOT NULL CHECK (dio40_fening > 0),
    PRIMARY KEY (tabela_br, raspon_od),
    CHECK (dio60_fening + dio40_fening = ukupno_fening)
) STRICT;

-- 4c. Zaštita okoline (tabele 12-15). Samo putnički automobili.
--     zapremina_od/do u cm3 (uključeno), starost_od/do u godinama
--     (uključeno), starost_do NULL = "iznad 30".
--     oldtajmer = 1 je zaseban red "iznad 30 (oldtajmeri)" (pitanja 3, 18).
--     Vozila iznad 4000 cm3 nemaju red (pitanje 17).
CREATE TABLE zastita_okoline (
    tabela_br      INTEGER NOT NULL CHECK (tabela_br BETWEEN 12 AND 15),
    zapremina_od   INTEGER NOT NULL CHECK (zapremina_od >= 0),
    zapremina_do   INTEGER NOT NULL CHECK (zapremina_do >= zapremina_od),
    starost_od     INTEGER NOT NULL CHECK (starost_od >= 0),
    starost_do     INTEGER CHECK (starost_do IS NULL OR starost_do >= starost_od),
    oldtajmer      INTEGER NOT NULL CHECK (oldtajmer IN (0, 1)),
    gorivo         INTEGER NOT NULL CHECK (gorivo IN (0, 1)),
    iznos_fening   INTEGER NOT NULL CHECK (iznos_fening > 0),
    PRIMARY KEY (zapremina_od, starost_od, oldtajmer, gorivo)
) STRICT;

-- 4d. AO premija (tabela 16), samo putnička vozila.
--     Podskupina se bira po snazi: kw > kw_preko AND (kw_do IS NULL OR kw <= kw_do).
--     osnovni_postotak_x100 je kolona "% osnovne premije" iz izvora
--     (58,10 -> 5810); informativna, kalkulator čita ao_premija.
CREATE TABLE ao_podskupina (
    podskupina             INTEGER NOT NULL PRIMARY KEY CHECK (podskupina BETWEEN 1 AND 8),
    kw_preko               INTEGER NOT NULL CHECK (kw_preko >= 0),
    kw_do                  INTEGER CHECK (kw_do IS NULL OR kw_do > kw_preko),
    osnovni_postotak_x100  INTEGER NOT NULL CHECK (osnovni_postotak_x100 > 0)
) STRICT;

-- Premijski razredi P14..P1: razred = broj iz oznake (P14 -> 14).
-- postotak je apsolutna vrijednost; smjer određuje tip (malus/bonus).
CREATE TABLE ao_razred (
    razred    INTEGER NOT NULL PRIMARY KEY CHECK (razred BETWEEN 1 AND 14),
    tip       INTEGER NOT NULL CHECK (tip IN (0, 1, 2)),
    postotak  INTEGER NOT NULL CHECK (postotak BETWEEN 0 AND 100)
) STRICT;

CREATE TABLE ao_premija (
    podskupina    INTEGER NOT NULL REFERENCES ao_podskupina (podskupina),
    razred        INTEGER NOT NULL REFERENCES ao_razred (razred),
    iznos_fening  INTEGER NOT NULL CHECK (iznos_fening > 0),
    PRIMARY KEY (podskupina, razred)
) STRICT;
