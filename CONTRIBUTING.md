# Mitmachen

Schön, dass du helfen willst. Jede Hilfe zählt, auch ganz ohne Code.

## Vorab: 100 % KI‑Code

Code und Doku in diesem Repo schreibt eine KI ([Claude Code](https://claude.com/claude-code)). Der Maintainer gibt die Richtung vor, prüft die Ergebnisse und testet auf echter Hardware. Deshalb trägt jeder Commit die Zeile `Co-Authored-By: Claude …`.

Wenn du KI‑Code grundsätzlich ablehnst, ist dieses Projekt vermutlich nichts für dich, und das ist in Ordnung. Wenn du trotzdem hilfst, freuen wir uns.

Deine eigenen Beiträge darfst du von Hand oder mit KI schreiben. Wichtig ist nur, dass du sie verstehst und selbst geprüft hast.

## So kannst du helfen

| Was | Wo |
| --- | --- |
| **Hardware testen**: WLAN‑Dongle, GamePad, Rechner für den Direktmodus | Issue [Hardware‑Bericht](https://github.com/Mendeln00/lichii-wiiu-gamepad/issues/new?template=hardware.yml). Wird am dringendsten gebraucht, auch Berichte über das, was **nicht** geht. |
| **Wissen teilen**: GamePad‑Protokoll, Pairing, Treiber, Kernel | [Discussions](https://github.com/Mendeln00/lichii-wiiu-gamepad/discussions) oder ein PR nach `research/` |
| **Fragen stellen, Ideen besprechen** | [Discussions](https://github.com/Mendeln00/lichii-wiiu-gamepad/discussions) |
| **Fehler melden** | Issue [Fehler](https://github.com/Mendeln00/lichii-wiiu-gamepad/issues/new?template=bug.yml) |
| **Code oder Doku verbessern** | Pull Request, gern zu Issues mit [`help wanted`](https://github.com/Mendeln00/lichii-wiiu-gamepad/labels/help%20wanted) oder [`good first issue`](https://github.com/Mendeln00/lichii-wiiu-gamepad/labels/good%20first%20issue) |
| **Reviews** | Offene PRs lesen und kommentieren |

Du kannst auf **Deutsch oder Englisch** schreiben. _English is welcome everywhere._ Die Doku im Repo ist auf Deutsch, Code und Code‑Kommentare auf Englisch.

## Ablauf für Code und Doku

1. Ein Issue suchen oder anlegen. Größere Dinge vorher im Issue oder in den Discussions abstimmen.
2. Das Repo forken und einen Branch anlegen: `feat/…`, `fix/…` oder `docs/…`.
3. In kleinen Schritten arbeiten, testgetrieben, wo es geht (`host/tests`).
4. Einen PR mit [Conventional‑Commit](https://www.conventionalcommits.org/)‑Titel öffnen und das Issue mit `Closes #…` verknüpfen. CI muss grün sein. Gemergt wird per Squash.
5. Bei Änderungen, die Hardware betreffen, im PR sagen, womit du getestet hast.

## Mit Agent‑Skills arbeiten

Unter `.claude/skills` liegen die [Skills von Matt Pocock](https://github.com/mattpocock/skills). Wer mit Claude Code mitarbeitet, nutzt damit denselben Ablauf wie der Maintainer:

| Schritt | Skill |
| --- | --- |
| Neues Issue oder fremden PR einordnen | `/triage` |
| Großes, unklares Vorhaben kartieren | `/wayfinder` |
| Idee schärfen, dabei ADR und Glossar pflegen | `/grill-with-docs` |
| Fakten aus Primärquellen sammeln | `/research` |
| Plan in Tickets zerlegen | `/to-tickets` |
| Umsetzen, testgetrieben | `/implement`, `/tdd` |
| Schritte, die nur ein Mensch am Gerät machen kann | `/wizard` |
| Prüfen gegen Regeln und Issue | `/code-review` |
| PR‑Text schreiben | `/pr` |

Die Konventionen für Agents stehen in [CLAUDE.md](CLAUDE.md), die Begriffe in [GLOSSARY.md](GLOSSARY.md).

## Labels

| Label | Bedeutung |
| --- | --- |
| `good first issue`, `help wanted` | Guter Einstieg, Hilfe gesucht |
| `ready-for-agent` | Vollständig beschrieben. Kann ein Agent oder du direkt umsetzen. |
| `ready-for-human`, `hardware-test` | Braucht einen Menschen oder echte Hardware |
| `hardware-report` | Bericht über getestete Hardware |
| `needs-triage`, `needs-info` | Noch nicht eingeordnet, oder es fehlen Angaben |

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

- Lade keine Spiele, Keys, Firmware oder Dumps hoch, auch nicht in Issues, Logs oder Screenshots. Das gilt besonders für `prod.keys` und `title.keys`: Sie stammen aus der eigenen Switch und sind privat. Ist doch etwas davon gepostet, lösch den Beitrag oder bitte die Maintainer, ihn samt Bearbeitungsverlauf zu entfernen. Bearbeiten allein reicht nicht, GitHub hebt alte Fassungen auf.
- Mit deinem Beitrag stimmst du zu, dass er unter [GPL‑3.0‑or‑later](LICENSE) steht.
- Fremden Code übernehmen wir nur, wenn seine Lizenz zu GPL‑3.0‑or‑later passt (z. B. MIT, BSD, Apache‑2.0, GPL‑2.0‑or‑later). Hat ein Projekt keine Lizenz, fragen wir zuerst die Autorin oder den Autor, ob sie eine ergänzen.

## Umgang und Sicherheit

Es gilt unser [Verhaltenskodex](CODE_OF_CONDUCT.md). Sicherheitslücken meldest du bitte vertraulich, wie in [SECURITY.md](SECURITY.md) beschrieben.
