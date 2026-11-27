# 0007: Lichii fürs GamePad als eden-cli mit eigener Konfiguration

- Status: angenommen
- Datum: 2026-11-27

## Kontext

Das Host‑Modul schreibt die Einstellungen fürs GamePad in Lichiis globale `qt-config.ini`: DSU‑Server, Touch, Tongerät und Spieler 1. Wer Lichii auch am PC nutzt, hat danach auf Spieler 1 nicht mehr seinen Controller. Steht das Tongerät auf dem stillen Gerät, ist auch das normale Lichii stumm. Lichii wird nicht gepatcht (ADR 0002). Spike und Messwerte stehen in Issue #55.

## Entscheidung

Spielprofile starten fürs GamePad nicht `lichii.exe`, sondern `eden-cli.exe` aus demselben Ordner, mit einer eigenen Einstellungsdatei:

```text
eden-cli.exe --config "<GamePad-Konfiguration>" -f -g "<Spiel>"
```

- **Ort:** `%LOCALAPPDATA%\LichiiGamepad\lichii-gamepad.ini`. Die Datei gehört zu diesem PC (DSU‑Adresse, Tongerät), also nicht ins Roaming‑Profil. Sie liegt außerhalb von `%APPDATA%\lichii`.
- **Inhalt:** Das Host‑Modul übernimmt alle Abschnitte aus `qt-config.ini` außer `[UI]` und `[Controls]`. Dazu kommen die eigenen Werte in `[Controls]` und `[Audio]`. `[Controls]` bleibt außen vor: Die Qt‑Oberfläche speichert Tastaturtasten als Qt‑Tastencodes, `eden-cli` liest sie als SDL‑Scancodes.
- **Schreiben:** Alle Befehle, die heute in `qt-config.ini` schreiben, schreiben in die GamePad‑Konfiguration. `qt-config.ini` liest das Host‑Modul nur noch.
- **Geteilt:** Spielstände und Nutzer (`nand`), `keys`, Firmware und Shader‑Cache nutzen beide gemeinsam. Die Pfade dafür stehen in `[Data Storage]` und kommen mit aus `qt-config.ini`.

## Verworfene Wege

- **Portable Kopie:** ein Ordner `user` neben einer zweiten `lichii.exe`. Das ist eine zweite Installation von rund 400 MB, die `lichii-updater.exe` nicht pflegt, und `keys` muss man kopieren oder verknüpfen. Nur nötig, wenn `eden-cli` an etwas scheitert, für das es die Qt‑Oberfläche braucht. Im Spike kam das nicht vor.
- **Umschalten per `prep-cmd` und Rückstellen danach:** Lichii schreibt seine Einstellungen beim Beenden zurück. Nach einem Absturz bliebe die globale Datei verstellt.
- **`--input-profile`:** Die Qt‑Oberfläche wertet es nicht aus. `eden-cli` setzt damit nur den Namen des Profils, nicht die Belegung.

## Folgen

- Am GamePad fehlt die Qt‑Oberfläche:
  - **Bildschirmtastatur:** `eden-cli` gibt ohne Rückfrage „Eden“ ein.
  - **Nutzerauswahl:** `eden-cli` nimmt den aktuellen Nutzer (`current_user`), mit `-u` einen anderen.
  - **Fehlermeldungen** stehen nur im Log. Laut Code meldet die Fehleranzeige dem Spiel kein Ende, das Spiel wartet dann vermutlich.
  - **Beenden** geht nur über das Fenster: Alt+F4 oder Apollo. Apollo bittet erst ums Schließen und wartet bis `exit-timeout` (Standard 5 s). `eden-cli` fährt darauf in unter 1 s sauber herunter.
- Spieleinstellungen aus `config\custom` liest `eden-cli` nicht. Lichiis eingebaute Anpassungen pro Spiel gelten weiter. Dafür trifft das festgelegte Tongerät aus zortos293/Lichii#2590 das GamePad nicht.
- Änderungen im normalen Lichii (Grafik, Sprache, Add‑ons) kommen erst in die GamePad‑Konfiguration, wenn das Host‑Modul sie neu übernimmt.
- `eden-cli` schreibt die GamePad‑Konfiguration beim Start und beim Beenden. Das Host‑Modul darf sie nur ändern, solange `eden-cli` nicht läuft.
- Beide teilen das Log `log\eden_log.txt`. Jeder Start schiebt das vorige Log nach `eden_log.txt.old.txt`. Die Spielzeit zählt nur die Qt‑Oberfläche.
- `ConvertFrom-ApolloAppList` erkennt Lichii heute nur an `^lichii.*\.exe$` und muss künftig auch `eden-cli.exe` erkennen.
