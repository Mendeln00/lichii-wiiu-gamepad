# Roadmap

Das Projekt ist in Meilensteine geteilt. Jeder Meilenstein liefert für sich etwas Nutzbares. Die einzelnen Tickets liegen als GitHub‑Issues im jeweiligen Milestone.

| # | Meilenstein | Ergebnis | Hängt ab von |
| --- | --- | --- | --- |
| M0 | **Fundament** | Repo, Skills, Doku, CI, Host‑Modul mit Diagnose | — |
| M1 | **Erster Stream** | Lichii läuft mit dem unveränderten moonlight‑wiiu auf dem GamePad, mit Bild, Ton und Tasten über den virtuellen Xbox‑Controller | M0 |
| M2 | **Eigener Client mit DSU** | Fork von moonlight‑wiiu mit DSU‑Server: Tasten, Sticks, Gyro und Touch gehen direkt an Lichii | M1 |
| M3 | **Isolation** | Spielanzeige isoliert, nur Spielton im Stream, keine globalen Eingaben. Der Host bleibt nutzbar. | M1 (Bild/Ton), M2 (Eingabe) |
| M4 | **Komfort** | Ein‑Klick‑Einrichtung, Spielprofile automatisch aus dem Spieleordner, Touch‑Kalibrierung, Client‑Einstellungsmenü | M2, M3 |
| M5 | **Direktmodus (Forschung)** | Machbarkeit ohne Konsole: Linux‑Bridge (Raspberry Pi oder Mini‑PC) mit WLAN‑Dongle, auf Basis von libdrc/pc2drc | unabhängig |
| M6 | **Upstream** | Verbesserungen als PRs an moonlight‑wiiu und Lichii, z. B. DSU‑Touch‑Standardwerte | M2 |

## Prinzipien

- **Tracer Bullets**: Erst ein dünner Durchstich durch alle Schichten, dann verbreitern.
- **Upstream zuerst**: Apollo und Lichii nur konfigurieren. Wo ein Patch nötig ist, als PR upstream anbieten.
- **Testbar**: Logik im Host‑Modul ist reine Funktion und hat Pester‑Tests. Hardware‑Schritte stehen als Prüfliste im Issue.
