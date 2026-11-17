# ADR-001: Izbor ugrađene baze podataka i strategija migracija

- **Status:** Prihvaćeno
- **Datum:** 2026-11-17
- **Povezani dokumenti:** SRS v1.1 (poglavlja 4, 5, 6, 8 i 13), `schema.sql`, `V2__seed_zakonski_podaci.sql`

## 1. Kontekst
SIN Base je samostalna JavaFX desktop aplikacija za Windows 10 (64-bit) koja radi potpuno offline, bez centralnog servera i mrežne sinhronizacije (NFR-01, NFR-03). Zbog jednokratne lokalne instalacije (jpackage/jlink) i potrebe za jednostavnim automatskim rezervnim kopijama (NFR-02, NFR-04), Docker i PostgreSQL iz ranijeg prijedloga su odbačeni u korist ugrađene (embedded) relacione baze podataka.

## 2. Razmatrane opcije: SQLite vs H2

| Kriterij | SQLite (`sqlite-jdbc`) | H2 Database |
| :--- | :--- | :--- |
| **Pohrana podataka** | Jedan prenosivi fajl (`sinbase.db`) | Jedan fajl (`.mv.db`), osjetljiv na verziju drajvera |
| **Backup i oporavak** | Trivijalno kopiranje/rotacija fajla pri zatvaranju | Zahtijeva poseban SQL `BACKUP` ili gašenje konekcije |
| **Uvid izvan aplikacije** | Bilo koji SQLite alat (npr. DB Browser) bez Jave | Zahtijeva pokretanje JVM procesa / H2 konzole |
| **Tipizacija podataka** | Slaba po defaultu, ali rješiva uz `STRICT` tabele (3.37+) | Stroga SQL tipizacija |
| **Zavisnosti i portabilnost** | Ugrađen native binarni kod za Windows x64 u JAR-u | Čista Java (bez native biblioteka) |

**Razlozi odbacivanja H2:** Iako je H2 pisan u čistoj Javi, historijski je imao nekompatibilnosti formata fajla između različitih verzija drajvera, što otežava dugoročno održavanje lokalne baze kod klijenta. Također, pregled i hitna popravka podataka kod klijenta zahtijevaju Java okruženje.

## 3. Odluka
Odabran je **SQLite** (putem `sqlite-jdbc` drajvera), uz lokaciju baze u `%LOCALAPPDATA%\SinBase\sinbase.db`.

Ključni razlozi za odluku:
1. **Jednostavan backup i integritet:** Jedan fajl omogućava pouzdanu rotaciju rezervnih kopija pri zatvaranju aplikacije i ugrađenu provjeru integriteta (`PRAGMA integrity_check`).
2. **Stroga kontrola podataka bez dodatnih tabela:** Korištenjem `STRICT` tabela (SQLite >= 3.37) i `CHECK` ograničenja postiže se sigurnost tipova (cijeli brojevi za feninge i enume, validni ISO-8601 datumi `YYYY-MM-DD`).
3. **Mogućnost naknadne enkripcije:** U slučaju potrebe za dodatnom zaštitom ličnih podataka (NFR-08), prelazak na SQLCipher ne zahtijeva promjenu šeme ni SQL upita.
4. **Napomena za konekciju:** Aplikacija mora otvarati svaku konekciju uz `PRAGMA foreign_keys=ON` (`jdbc:sqlite:<putanja>?foreign_keys=on`) kako bi se provodili strani ključevi.

## 4. Plan migracija (Flyway)
Upravljanje verzijama baze vrši se automatski pri pokretanju aplikacije putem alata **Flyway**:
- **`V1__sema.sql`:** Kreira strukturu svih tabela (`stranka`, `postavke`, `fiksna_naknada`, tabele putarine, zaštite okoline i AO premije), `STRICT` pravila, `CHECK` ograničenja i indekse za pretragu i upozorenja o isteku.
- **`V2__seed_zakonski_podaci.sql`:** Puni početne postavke (`prag_upozorenja_dana = 20`, `rezim_prikaza = 0`), podrazumijevane fiksne naknade i referentne zakonske tabele (tabele 1–16).
- **Buduće izmjene (`V3__*.sql`):** Svaka naknadna izmjena zakonskih tarifa ili strukture dodaje se kao nova migracija (`V3`, `V4`...), čime se čuvaju postojeći zapisi stranaka i korisničke postavke (NFR-12).

## 5. Uticaj otvorenih pitanja klijenta (šta se mijenja ako odgovori drugačije)
- **Osiguravajuće kuće — GRAWE i TRIGLAV (SRS pitanje 10):** Šema trenutno dozvoljava kodove `0–4` (ASA, EUROHERC, EUROS, GRAWE, TRIGLAV). Ako klijent potvrdi da radi isključivo s prve tri kuće, `CHECK` ograničenje u tabeli `stranka` sužava se na `IN (0, 1, 2)` (u `V1` prije produkcije ili kroz novu migraciju rekreiranjem tabele), a suvišne vrijednosti se uklanjaju iz Java enuma. Ako se naknadno doda nova kuća, `CHECK` lista se proširuje.
- **Obnova polise / Primarni ključ (SRS pitanje 11):** `broj_polise` je trenutno primarni ključ (svaka obnova je novi red). Ako klijent zatraži praćenje historije polisa po klijentu ili unos zapisa bez poznatog broja polise, uvodi se surogatni ključ `id INTEGER PRIMARY KEY AUTOINCREMENT`, dok `broj_polise` ostaje `UNIQUE`.
- **Putarina: Ukupno vs 60%/40% (SRS pitanje 1):** Tabela `putarina_razred` već čuva sve tri kolone (`ukupno_fening`, `dio60_fening`, `dio40_fening`), pa drugačiji odgovor klijenta ne mijenja šemu baze, već samo kolonu koju čita servis kalkulatora.
- **Dodatne kategorije i zapremine > 4000 cm³ (SRS pitanja 2, 5, 17):** Ako klijent potvrdi obračun zaštite okoline za teretna vozila ili zapremine iznad 4000 cm³, dodaju se novi redovi kroz `V3` seed migraciju (uz eventualno proširenje `CHECK (tabela_br ...)` ako se uvode nove tabele).
- **Izmjena zakonskih tabela iz Postavki (SRS pitanje 13):** Zakonske tabele su trenutno tretirane kao read-only seed podaci. Ako klijent zatraži njihovo uređivanje kroz UI, struktura tabela ostaje ista, a aplikaciji se dodaje forma za `UPDATE` postojećih redova.

## 6. Posljedice
- **Pozitivne:** Nulta konfiguracija za krajnjeg korisnika, brz lokalni rad, lak backup i potpuna sljedivost izmjena šeme kroz Flyway.
- **Negativne / Ograničenja:** SQLite ima ograničenu podršku za `ALTER TABLE` (npr. izmjena `CHECK` ograničenja zahtijeva kreiranje nove tabele i kopiranje podataka u Flyway skripti), te ne podržava višekorisnički istovremeni upis preko mreže (što je u skladu s ograničenjima sistema).
