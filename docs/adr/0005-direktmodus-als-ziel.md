# 0005: Direktmodus als Ziel, Relay nur als Plan B

- Status: angenommen. Löst [ADR 0001](0001-konsole-als-relay.md) ab.
- Datum: 2026-11-25

Das GamePad soll ganz ohne Wii U laufen. Eine **Brücke** gibt sich ihm gegenüber als Konsole aus: Sie koppelt das GamePad selbst, betreibt den Access Point mit Zeitstempeln aus dem TSF und spricht das GamePad‑Protokoll für Bild, Ton und Eingabe. ADR 0001 hatte das Relay zum Standard gemacht, weil wir annahmen, die Kopplung brauche eine Konsole. Das stimmt 2026 nicht mehr: Barista, rtw88_TSF und Toffee koppeln GamePads ohne Konsole ([research/direct-mode.md](../../research/direct-mode.md)). Das Relay über moonlight‑wiiu ruht als Plan B.

## Erwogene Wege für die Brücke

| Weg | Kurz | Rolle |
| --- | --- | --- |
| [Toffee](https://github.com/Gavwalsh15/toffee_wiiu): Windows‑App und ESP32‑C5 am USB | Kein Linux, kein Kernel‑Patch. Der Host kodiert, das ESP32 macht Kopplung, Funk und TSF. DSU‑Server eingebaut. Sehr jung, GPL‑3.0‑only. | Spike A, zuerst |
| Linux mit USB‑WLAN‑Dongle, z. B. [Barista](https://github.com/BetaZay/Barista) | Mit RTL8811AU belegt. Empfängt den Stream von Apollo und kodiert ihn für das GamePad neu. Erst als Live‑USB, dann in WSL2, sonst auf einem Mini‑PC. | Spike B, Rückfall |
| [wup-homebrew](https://github.com/ravensclawx/wup-homebrew): eigene Software auf dem GamePad, normales WLAN | Ändert die GamePad‑Firmware und braucht dafür einmal eine Wii U | nicht verfolgt |

Welcher Weg die Brücke wird, entscheidet ein eigenes ADR nach den Spikes.

## Folgen

- Hardware: ein ESP32‑C5‑Board für Spike A, ein USB‑WLAN‑Dongle mit RTL8811AU für Spike B.
- Das Bild muss eigens für das GamePad kodiert werden (fester Kopf, QP 32). Den Stream von Apollo kann man nicht durchreichen.
- ADR 0002 (Apollo) gilt für den Linux‑Weg weiter. Im Toffee‑Weg liest der Host die Spielanzeige selbst, Apollo wäre dann nicht mehr im Bildpfad. Das klärt das Plattform‑ADR.
- ADR 0003 (DSU) und ADR 0004 (Isolation) gelten unverändert. Den DSU‑Server stellt die Brücke.
- Code aus Projekten unter GPL‑2.0‑only oder GPL‑3.0‑only mischen wir nicht in dieses Repo. Wir nutzen sie als eigene Programme oder in eigenen Forks und geben Verbesserungen upstream zurück.
- Eine Kopplung mit der Brücke ersetzt vermutlich die mit der Wii U. Für Plan B koppelt man dann an der Konsole neu.
