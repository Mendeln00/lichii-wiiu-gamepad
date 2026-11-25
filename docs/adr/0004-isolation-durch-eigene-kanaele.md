# 0004: Isolation durch eigene Kanäle für Bild, Ton und Eingabe

- Status: angenommen (Ton: Weg korrigiert, Upstream‑PRs nötig, siehe Issue #15)
- Datum: 2026-11-25

## Kontext

Der Host soll beim Spielen nutzbar bleiben. In der vorhandenen Apollo‑Konfiguration steht `dd_configuration_option = ensure_primary`. Damit wird die Spielanzeige zum **primären** Bildschirm, und Fenster und Taskleiste springen dorthin. Standardmäßig nimmt Apollo außerdem den gesamten Host‑Ton auf.

## Entscheidung

- **Bild**: `dd_configuration_option = ensure_active` plus `isolated_virtual_display_option = enabled`. Die Spielanzeige ist aktiv, aber nicht primär, und liegt ganz rechts unten im Layout.
- **Ton**: Lichii gibt auf ein eigenes Ausgabegerät aus, etwa VB‑CABLE. Die Brücke nimmt genau dieses Gerät auf und ändert das Windows‑Standardgerät nicht. Heute kann das weder Apollo noch Toffee: Beide nehmen nur das Standardgerät auf, und Apollo stellt `audio_sink` dabei als Standardgerät ein. Nötig sind deshalb PRs upstream: an Toffee eine Option für das Aufnahmegerät, an Apollo die Übernahme von Sunshines `external_audio`. Details in [research/audio-isolation.md](../../research/audio-isolation.md).
  - _Korrektur 2026‑11‑25_: Bisher stand hier, der Client fordere „Ton auf Host behalten“ an, damit Apollo das Standardgerät nicht umstellt. Das stimmt nicht. Das Flag wählt nur zwischen `audio_sink` und `virtual_sink`, umgestellt wird trotzdem.
- **Eingabe**: siehe ADR 0003. Zusätzlich `mouse = disabled`, `keyboard = disabled` in Apollo.

## Folgen

- Zusätzlicher virtueller Audiotreiber (VB‑CABLE o. ä.) nötig, falls kein passendes Gerät vorhanden ist.
- Das Host‑Modul muss die Konfiguration prüfen (`Test-LichiiGamepadHost`) und setzen können.
