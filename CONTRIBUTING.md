# Contributing: kako radimo na SIN Base

Ovaj dokument vrijedi za sve članove tima. Kratak je, pročitaj ga cijelog prije prvog commita.

## 1. Grane

| Grana | Namjena |
|---|---|
| `main` | Stabilne verzije (release). Direktan push je zabranjen. |
| `dev` | Integracija gotovog rada. Direktan push je zabranjen. |
| `feature/SIN-XX-kratki-opis` | Rad na jednom tiketu |

Format naziva: `feature/SIN-<broj tiketa>-<kratki-opis-malim-slovima-s-crticama>`

Primjeri:
- `feature/SIN-12-kalkulator-putarina`
- `feature/SIN-20-ui-tabela-stranaka`
- `feature/SIN-3-srs-ispravke`

Za dokumentaciju i dizajn koristi isti oblik (`feature/SIN-8-ui-vodic`), a fajlovi idu u `docs/`.

Grana se uvijek pravi iz `dev`, nikad iz `main`.

## 2. Commit poruke

Poruka počinje ID-em tiketa, pa tipom, pa kratkim opisom:

`SIN-<broj> <tip>: <opis>`

| Tip | Kada |
|---|---|
| `feat` | Nova funkcionalnost |
| `fix` | Ispravka greške |
| `docs` | Dokumentacija |
| `test` | Testovi |
| `refactor` | Preuređenje koda bez promjene ponašanja |
| `chore` | Postavke, build, .gitignore i slično |

Primjeri:
- `SIN-12 feat: dodana kalkulacija putarine za putnička vozila`
- `SIN-14 fix: ispravljen raspon u tabeli 5`
- `SIN-3 docs: ažuriran SRS na verziju 1.1`

Zašto ID u poruci: tako se commit automatski veže za tiket u YouTrack-u. Poruka bez ID-a se ne veže.

Jedan commit = jedna smislena cjelina. Ne piši poruke tipa "izmjene" ili "popravke".

## 3. Rad korak po korak

```bash
# 1. Osvježi dev i napravi granu
git checkout dev
git pull
git checkout -b feature/SIN-12-kalkulator-putarina

# 2. Radi, pa dodaj tačno one fajlove koje želiš
git add putanja/do/fajla
git commit -m "SIN-12 feat: dodana kalkulacija putarine"

# 3. Pošalji granu na GitHub
git push -u origin feature/SIN-12-kalkulator-putarina
```

Pravila:
- Koristi `git add <fajl>`, ne `git add .`, da u commit ne uđu IDE fajlovi (`.idea/`) ili tuđe izmjene.
- Prije commita provjeri `git status`.
- Na `main` i `dev` se ne pusha direktno. Server to odbija.
- Nikad ne commituj lične podatke stranaka, popunjene obrasce, tokene ni lozinke.

## 4. Pull request

1. Na GitHubu otvori PR iz svoje grane prema `dev` (provjeri da je base grana `dev`).
2. Naslov počinje ID-em: `SIN-12 Kalkulacija putarine`
3. U opis napiši šta si uradio i kako si provjerio.
4. U YouTrack-u prebaci tiket u **In Review**.
5. Obavijesti Amela da je PR spreman.

## 5. Merge

Merge radi **Amel** na GitHubu, za svaki PR.

| PR | Metoda |
|---|---|
| `feature/*` -> `dev` | **Squash and merge** |
| `dev` -> `main` | **Create a merge commit** |

Nakon merge-a se grana briše (**Delete branch**), a tiket ide u **Done** kad je ispunjen Definition of Done (vidi članak u YouTrack Knowledge Base).

Poslije merge-a očisti lokalno:

```bash
git checkout dev
git pull
git branch -d feature/SIN-12-kalkulator-putarina
```

Ako git ne dozvoli `-d` zbog squasha, koristi `-D`.

## 6. Prije svakog novog rada

Uvijek prvo `git checkout dev` i `git pull`. Tako izbjegavaš konflikte sa tuđim izmjenama.

## 7. Ako nešto pođe po zlu

- Commit na pogrešnoj grani: javi Amelu prije nego išta brišeš.
- Konflikt pri spajanju: ne rješavaj na silu, javi u grupu.
- Greškom pušan tajni podatak: odmah javi cijelom timu.