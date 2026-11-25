# Roadmap

Ziel ist der **Direktmodus**: Das GamePad wird ohne Wii U gekoppelt und von der Brücke bedient ([ADR 0005](adr/0005-direktmodus-als-ziel.md)). Jeder Meilenstein liefert für sich etwas Prüfbares. Die Tickets liegen als GitHub‑Issues im jeweiligen Milestone.

| # | Meilenstein | Ergebnis | Hängt ab von |
| --- | --- | --- | --- |
| M0 | **Fundament** ✅ | Repo, Skills, Doku, CI, Host‑Modul mit Diagnose | — |
| M1 | **Host bereit** | Apollo isoliert die Spielanzeige, Lichii nimmt DSU an, der Spielton ist getrennt | M0 |
| M2 | **GamePad koppeln ohne Wii U** | Die Brücke koppelt das GamePad ohne Konsole und zeigt ein Testbild. Das ist der riskanteste Teil und kommt deshalb zuerst. | M0 |
| M3 | **Bild und Ton zum GamePad** | Die Brücke holt den Stream von Apollo. Lichii läuft mit Ton auf dem GamePad. | M1, M2 |
| M4 | **Eingabe an Lichii** | Tasten, Sticks, Gyro und Touch gehen von der Brücke per DSU an Lichii | M2 |
| M5 | **Isolation und Komfort** | Abnahmetest „PC bleibt nutzbar“, Ein‑Klick‑Start, Spielprofile, Tastenbelegung | M3, M4 |
| M6 | **Upstream** | Verbesserungen als PRs an Lichii und an die Projekte, die wir forken | M4 |
| Plan B | **Wii U als Relay** | Ruht. Nur falls der Direktmodus scheitert: moonlight‑wiiu auf der Konsole, Fork mit DSU‑Server | — |

M1 und M2 laufen parallel: M1 ist reine Software auf dem Host, M2 braucht Hardware (Dongle, GamePad).

## Prinzipien

- **Risiko zuerst**: Erst beweisen, dass Kopplung und Testbild ohne Konsole klappen, dann alles andere darauf bauen.
- **Tracer Bullets**: Erst ein dünner Durchstich durch alle Schichten, dann verbreitern.
- **Upstream zuerst**: Apollo und Lichii nur konfigurieren. Wo ein Patch nötig ist, als PR upstream anbieten. Fremde Brücken‑Projekte forken wir und geben Verbesserungen zurück.
- **Testbar**: Logik ist reine Funktion mit Tests. Hardware‑Schritte stehen als Prüfliste im Issue oder als Wizard (`/wizard`).
