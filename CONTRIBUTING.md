# Mitmachen

1. Ein Issue suchen oder anlegen. Größere Ideen vorher im Issue abstimmen.
2. Einen Branch von `main` anlegen: `feat/…`, `fix/…` oder `docs/…`.
3. Kleine Schritte gehen, testgetrieben, wo es geht (`host/tests`).
4. Einen PR mit [Conventional-Commit](https://www.conventionalcommits.org/)-Titel öffnen. CI muss grün sein.

## Lokal testen

```powershell
./host/tests/Invoke-Tests.ps1
Invoke-ScriptAnalyzer -Path host -Recurse -Settings host/PSScriptAnalyzerSettings.psd1
```

Benötigt [Pester](https://pester.dev) ≥ 5.6 und PSScriptAnalyzer:

```powershell
Install-Module Pester, PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck
```

## Rechtliches

Lade keine Spiele, Keys, Firmware oder Dumps hoch, auch nicht in Issues. Code aus Projekten ohne Lizenz übernehmen wir nicht.
