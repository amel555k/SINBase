-- =====================================================================
-- SIN Base - šema baze (SQLite)                     docs/arhitektura/
-- Ulaz za SDD. Odgovara Flyway migraciji V1__sema.sql.
-- Izvor: ER dijagram "ShemaBazePodataka" (Visual Paradigm), SRS v1.1
--        poglavlja 4 i 6, Tabele_kalkulator_registracije.txt (tabele
--        1-21) i FiksneNaknade.txt. Odluka o bazi: ADR-001-baza.md.
--
-- IZMJENE U ODNOSU NA PRETHODNU VERZIJU (20.11.2026.)
--  1. fiksna_naknada: nova kolona pogon. Tehnički pregled ima tri
--     cijene (dizel 91, benzin 87, EV/hibrid/LPG 55 KM), AMK putničko
--     je 8 KM (teretno 15 KM).
--  2. zastita_okoline: nova kolona grupa_vozila (putnički, teretni,
--     autobus) za tabele 17 i 18; gorivo dobija vrijednost 2 =
--     elektromotor; zapremina_do može biti NULL ("veći od 16001");
--     tabela_br dozvoljava 12-15, 17 i 18.
--  3. ao_podskupina i ao_premija: nova kolona grupa (1 putnička,
--     2 teretna, 3 autobusi) za tabele 16, 19 i 20; kw_preko i kw_do
--     preimenovani u raspon_preko i raspon_do (jedinica zavisi od
--     grupe); nova kolona naziv.
--  4. Nova tabela porez_mv (tabela 21, porez na putnička vozila).
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
--  8. Rasponi su uključeni na oba kraja, osim kod premijskih podskupina
--     (AO) gdje je donja granica isključena ("preko X").
--
-- KODOVI ENUMA
--  osiguravajuca_kuca : 0 ASA, 1 EUROHERC, 2 EUROS, 3 GRAWE, 4 TRIGLAV
--  vrsta_vozila       : 0 putničko, 1 teretno, 2 moped, 3 motocikl,
--                       4 prikolica, 5 radna mašina
--  kategorija (putarina_tabela): 0 putnički (M1, mjeri se u cm3),
--                       1 N1, 2 N2, 3 N3, 4 autobus M2/M3 (1-4 u kg)
--  pogon_grupa        : 0 dizel/benzin, 1 LPG/CNG/hibrid (putarina)
--  pogon (fiksna_naknada, tehnički pregled): 0 dizel, 1 benzin,
--                       2 EV/hibrid/LPG; NULL = ne zavisi od pogona
--  grupa_vozila (zastita_okoline): 0 putnički (tabele 12-15),
--                       1 teretni (tabela 18), 2 autobus (tabela 17)
--  gorivo (zastita_okoline): 0 dizel, 1 benzin (samo putnički),
--                       2 elektromotor (samo teretni i autobusi)
--  grupa (ao_podskupina): 1 putnička (kW), 2 teretna (nosivost u kg),
--                       3 autobusi (fiksna premija + premija po mjestu)
--  tip (ao_razred)    : 0 malus (P14-P7), 1 osnovni (P6), 2 bonus (P5-P1)
--
-- MAPIRANJE POGONA (za SDD, sloj usluga)
--  Korisnik bira jedan pogon, a svaka tabela ga grupiše drugačije:
--    putarina (tabele 1-4)      : dizel/benzin ili LPG/CNG/hibrid
--    tehnički pregled           : dizel, benzin ili EV/hibrid/LPG
--    zaštita okoline putnički   : dizel ili benzin
--    zaštita okoline teretni i autobusi: dizel ili elektromotor
--  Izvor nema kolonu zaštite okoline za LPG/CNG i hibride; kako se oni
--  računaju treba potvrditi s klijentom.
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
--    Jedan red = jedna naknada (ili jedna varijanta naknade). Novu
--    naknadu dodaje INSERT, ne kod.
--    vrsta_vozila NULL = naknada vrijedi za putnička i teretna vozila.
--    pogon        NULL = naknada ne zavisi od pogona.
--    Računanje:
--      SELECT SUM(iznos_fening) FROM fiksna_naknada
--       WHERE (vrsta_vozila IS NULL OR vrsta_vozila = :vrsta)
--         AND (pogon        IS NULL OR pogon        = :pogon);
--    Naknade po vrsti vozila: AMK putničko 8 KM, teretno 15 KM.
--    Naknade po pogonu: tehnički pregled dizel 91, benzin 87,
--    EV/hibrid/LPG 55 KM. Za svaku kombinaciju (vrsta, pogon) upit
--    mora vratiti tačno jedan red tehničkog pregleda i tačno jedan AMK.
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
    pogon                 INTEGER
        CHECK (pogon IS NULL OR pogon IN (0, 1, 2)),             -- NULL = svi pogoni
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

-- 4c. Zaštita okoline: tabele 12-15 (putnički), 17 (autobusi) i 18
--     (teretni). zapremina_od/do u cm3 (uključeno), zapremina_do NULL =
--     "veći od" (autobusi i teretni, 16001 i više). starost_od/do u
--     godinama (uključeno), starost_do NULL = "iznad 30".
--     oldtajmer = 1 je zaseban red "iznad 30 (oldtajmeri)" (pitanja 3, 18).
--     Putnička vozila iznad 4000 cm3 nemaju red (pitanje 17), a teretna
--     ispod 1401 cm3 nisu u izvoru.
--     Za autobuse i teretna vozila uzete su samo kolone dizel i
--     elektromotor (po dogovoru s klijentom, većina vozila je dizel).
--     Pretraga: WHERE grupa_vozila = :g AND :zap >= zapremina_od
--                 AND (zapremina_do IS NULL OR :zap <= zapremina_do)
--                 AND :starost >= starost_od
--                 AND (starost_do IS NULL OR :starost <= starost_do)
--                 AND oldtajmer = :oldtajmer AND gorivo = :gorivo
CREATE TABLE zastita_okoline (
    tabela_br      INTEGER NOT NULL CHECK (tabela_br IN (12, 13, 14, 15, 17, 18)),
    grupa_vozila   INTEGER NOT NULL CHECK (grupa_vozila IN (0, 1, 2)),
    zapremina_od   INTEGER NOT NULL CHECK (zapremina_od >= 0),
    zapremina_do   INTEGER CHECK (zapremina_do IS NULL OR zapremina_do >= zapremina_od),
    starost_od     INTEGER NOT NULL CHECK (starost_od >= 0),
    starost_do     INTEGER CHECK (starost_do IS NULL OR starost_do >= starost_od),
    oldtajmer      INTEGER NOT NULL CHECK (oldtajmer IN (0, 1)),
    gorivo         INTEGER NOT NULL CHECK (gorivo IN (0, 1, 2)),
    iznos_fening   INTEGER NOT NULL CHECK (iznos_fening > 0),
    PRIMARY KEY (grupa_vozila, zapremina_od, starost_od, oldtajmer, gorivo),
    CHECK ((grupa_vozila = 0 AND tabela_br BETWEEN 12 AND 15)
        OR (grupa_vozila = 2 AND tabela_br = 17)
        OR (grupa_vozila = 1 AND tabela_br = 18)),
    CHECK ((grupa_vozila = 0 AND gorivo IN (0, 1))
        OR (grupa_vozila IN (1, 2) AND gorivo IN (0, 2)))
) STRICT;

-- 4d. AO premija: tabele 16 (grupa 1, putnička), 19 (grupa 2, teretna)
--     i 20 (grupa 3, autobusi).
--     Podskupina se bira po rasponu: vrijednost > raspon_preko AND
--     (raspon_do IS NULL OR vrijednost <= raspon_do).
--       grupa 1: raspon u kW (snaga motora)
--       grupa 2: raspon u kg nosivosti (0,5 t = 500)
--       grupa 3: bez raspona (raspon_preko i raspon_do su NULL); dvije
--                podskupine: 1 = fiksna premija, 2 = premija za svako
--                registrovano mjesto. Premija autobusa = iznos
--                podskupine 1 + broj mjesta x iznos podskupine 2.
--     osnovni_postotak_x100 je kolona "% osnovne premije" iz izvora
--     (58,10 -> 5810); informativna, kalkulator čita ao_premija.
CREATE TABLE ao_podskupina (
    grupa                  INTEGER NOT NULL CHECK (grupa IN (1, 2, 3)),
    podskupina             INTEGER NOT NULL CHECK (podskupina BETWEEN 1 AND 9),
    naziv                  TEXT    NOT NULL CHECK (length(trim(naziv)) BETWEEN 1 AND 60),
    raspon_preko           INTEGER CHECK (raspon_preko IS NULL OR raspon_preko >= 0),
    raspon_do              INTEGER CHECK (raspon_do IS NULL OR raspon_do > raspon_preko),
    osnovni_postotak_x100  INTEGER NOT NULL CHECK (osnovni_postotak_x100 > 0),
    PRIMARY KEY (grupa, podskupina),
    CHECK ((grupa = 1 AND podskupina <= 8) OR (grupa = 2 AND podskupina <= 9) OR (grupa = 3 AND podskupina <= 2)),
    CHECK ((grupa IN (1, 2) AND raspon_preko IS NOT NULL)
        OR (grupa = 3 AND raspon_preko IS NULL AND raspon_do IS NULL))
) STRICT;

-- Premijski razredi P14..P1: razred = broj iz oznake (P14 -> 14).
-- postotak je apsolutna vrijednost; smjer određuje tip (malus/bonus).
CREATE TABLE ao_razred (
    razred    INTEGER NOT NULL PRIMARY KEY CHECK (razred BETWEEN 1 AND 14),
    tip       INTEGER NOT NULL CHECK (tip IN (0, 1, 2)),
    postotak  INTEGER NOT NULL CHECK (postotak BETWEEN 0 AND 100)
) STRICT;

CREATE TABLE ao_premija (
    grupa         INTEGER NOT NULL,
    podskupina    INTEGER NOT NULL,
    razred        INTEGER NOT NULL REFERENCES ao_razred (razred),
    iznos_fening  INTEGER NOT NULL CHECK (iznos_fening > 0),
    PRIMARY KEY (grupa, podskupina, razred),
    FOREIGN KEY (grupa, podskupina) REFERENCES ao_podskupina (grupa, podskupina)
) STRICT;

-- 4e. Porez na putnička vozila (tabela 21). zapremina u cm3 (uključeno,
--     zapremina_do NULL = "preko 3000"), starost vozila u godinama
--     (0-7 i preko 7). Granice raspona (1600, 1800, 2000) se u izvoru
--     dodiruju; seedano je tako da gornja granica pripada nižem rasponu
--     (do 1600, 1601-1800, 1801-2000, 2001-3000). Potvrditi s klijentom.
CREATE TABLE porez_mv (
    zapremina_od  INTEGER NOT NULL CHECK (zapremina_od >= 0),
    zapremina_do  INTEGER CHECK (zapremina_do IS NULL OR zapremina_do >= zapremina_od),
    starost_od    INTEGER NOT NULL CHECK (starost_od >= 0),
    starost_do    INTEGER CHECK (starost_do IS NULL OR starost_do >= starost_od),
    iznos_fening  INTEGER NOT NULL CHECK (iznos_fening > 0),
    PRIMARY KEY (zapremina_od, starost_od)
) STRICT;
