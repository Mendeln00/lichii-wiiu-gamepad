# 0004: Isolation durch eigene Kanäle für Bild, Ton und Eingabe

- Status: angenommen (Ton: zu verifizieren, siehe Issue in M3)
- Datum: 2026-11-25

## Kontext

Der Host soll beim Spielen nutzbar bleiben. In der vorhandenen Apollo‑Konfiguration steht `dd_configuration_option = ensure_primary`. Damit wird die Spielanzeige zum **primären** Bildschirm, und Fenster und Taskleiste springen dorthin. Standardmäßig nimmt Apollo außerdem den gesamten Host‑Ton auf.

## Entscheidung

- **Bild**: `dd_configuration_option = ensure_active` plus `isolated_virtual_display_option = enabled`. Die Spielanzeige ist aktiv, aber nicht primär, und liegt ganz rechts unten im Layout.
- **Ton**: Lichii gibt auf ein eigenes Ausgabegerät aus, Apollo nimmt per `audio_sink` genau dieses auf. Der Client fordert „Ton auf Host behalten“ an, damit Apollo das Standardgerät nicht umstellt.
- **Eingabe**: siehe ADR 0003. Zusätzlich `mouse = disabled`, `keyboard = disabled` in Apollo.

## Folgen

- Zusätzlicher virtueller Audiotreiber (VB‑CABLE o. ä.) nötig, falls kein passendes Gerät vorhanden ist.
- Das Host‑Modul muss die Konfiguration prüfen (`Test-LichiiGamepadHost`) und setzen können.
