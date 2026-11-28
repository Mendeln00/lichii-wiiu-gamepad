# Brücke

Die Brücke gibt sich dem GamePad gegenüber als Konsole aus. Sie koppelt das GamePad ohne Wii U, zeigt Bild und Ton darauf und schickt die Eingaben per DSU an Lichii ([ADR 0005](../docs/adr/0005-direktmodus-als-ziel.md)).

Welche Software die Brücke wird, klären zwei Spikes in Meilenstein M2:

| Spike | Hardware | Software |
| --- | --- | --- |
| A, zuerst | ESP32‑C5‑Board am USB‑Port des Hosts, z. B. Waveshare ESP32‑C5‑Zero | [Toffee](https://github.com/Gavwalsh15/toffee_wiiu) |
| B, Rückfall | USB‑WLAN‑Dongle mit RTL8811AU, z. B. der TP‑Link „Nano AC600“, mit dem Barista testet | [Barista](https://github.com/BetaZay/Barista) unter Linux (Live‑USB, dann WSL2 oder Mini‑PC) |

Welche DSU‑Taste die Brücke für jede Taste des GamePads sendet und was HOME und TV auslösen, steht in [docs/input-mapping.md](../docs/input-mapping.md).

Hier landen danach Einrichtung, Konfiguration und Verweise auf unsere Forks. Fremder Code unter GPL‑2.0‑only oder GPL‑3.0‑only kommt nicht in dieses Repo, sondern bleibt in eigenen Forks.

Bevor du einen Dongle kaufst: Hersteller wechseln den Chipsatz manchmal zwischen Revisionen. Prüfe die USB‑ID mit `lsusb`. Erfahrungen bitte als [Hardware‑Bericht](https://github.com/Mendeln00/lichii-wiiu-gamepad/issues/new?template=hardware.yml).
