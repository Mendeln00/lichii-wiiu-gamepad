# 0002: Moonlight‑Protokoll mit Apollo als Host

- Status: angenommen. Der Client ist seit [ADR 0005](0005-direktmodus-als-ziel.md) die Brücke, der Fork von moonlight‑wiiu nur noch Plan B.
- Datum: 2026-11-25

## Kontext

Für Bild und Ton vom Host zur Konsole braucht es Capture, Hardware‑Encoding, ein latenzarmes Transportprotokoll, Opus‑Ton und Pairing. Eine eigene Lösung wäre viel Arbeit. Sunshine/Moonlight bringen das alles schon mit. Der Fork **Apollo** ergänzt pro App ein virtuelles Display (SudoVDA) mit nativer Auflösung des Clients und eine Option für eine isolierte Anzeige. Auf dem Host ist Apollo bereits mit Lichii‑Spielprofilen eingerichtet. moonlight‑wiiu (GPL‑3.0) ist ein fertiger Moonlight‑Client für die Wii U.

## Entscheidung

- Host: **Apollo**, unverändert, nur konfiguriert. Wir patchen Apollo nicht.
- Client: **Fork von moonlight‑wiiu**. Änderungen landen dort und, wo sinnvoll, als PR upstream.

## Folgen

- Bild und Ton funktionieren schon mit dem unveränderten moonlight‑wiiu (Meilenstein M1).
- Encoder‑Einstellungen (854×480 bzw. 1280×720, Bitrate) sind reine Konfiguration.
- Wir hängen an Apollos Release‑Zyklus. Konfigurationsänderungen kapselt das Host‑Modul.
