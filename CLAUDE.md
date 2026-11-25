# CLAUDE.md

Lichii (Switch‑Emulator) über das Wii U GamePad spielen, isoliert vom restlichen PC. Überblick: `README.md`, `docs/architecture.md`, `docs/roadmap.md`.

## Konventionen

- Doku, Issues und Commit‑Beschreibungen auf **Deutsch**. Code, Bezeichner und Code‑Kommentare auf **Englisch**. PRs an Upstream‑Projekte auf Englisch.
- Begriffe aus `GLOSSARY.md` verwenden (GamePad, Konsole, Host, Client, Spielanzeige, Spielton, Eingabekanal, DSU, Isolation, Spielprofil).
- Commits nach [Conventional Commits](https://www.conventionalcommits.org/) (`feat(host): …`, `docs: …`). Jede Änderung läuft über Branch und PR, nicht direkt auf `main`.
- Host‑Modul (`host/LichiiGamepad`): Windows PowerShell 5.1 kompatibel. Logik als reine Funktionen mit Pester‑5‑Tests (`host/tests`). Dateizugriffe in dünnen Wrappern.
- Tests: `pwsh -NoProfile -File host/tests/Invoke-Tests.ps1` (oder `powershell`). Lint: PSScriptAnalyzer mit `host/PSScriptAnalyzerSettings.psd1`.
- Keine Spiele, Keys, Firmware oder persönlichen Pfade ins Repo. Beispiele nutzen Platzhalter.
- Apollo und Lichii werden nur konfiguriert, nicht gepatcht (ADR 0002). Patches gehen als PR upstream.

## Agent skills

Arbeitsablauf (welcher Skill bei welchem Schritt, von Triage bis PR): Tabelle „Mit Agent‑Skills arbeiten“ in `CONTRIBUTING.md`.

### Issue tracker

Issues liegen in den GitHub Issues von `Mendeln00/lichii-wiiu-gamepad` (über die `gh` CLI), gegliedert in Milestones M0–M6. See `docs/agents/issue-tracker.md`.

### Triage labels

Die fünf Standard‑Rollen (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`) mit identischen Label‑Namen. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` und `docs/adr/` im Repo‑Root. See `docs/agents/domain.md`.
