# Verwandte Projekte

Lizenzen laut Lizenzdatei, Stand 2026-11-25. Details und Belege stehen in [research/direct-mode.md](../research/direct-mode.md#3-projekte-und-lizenzen).

## Host

| Projekt | Lizenz | Was es macht | Nutzen für uns |
| --- | --- | --- | --- |
| [zortos293/Lichii](https://github.com/zortos293/Lichii) | GPL‑3.0 | Switch/Switch‑2‑Emulator (yuzu/Eden‑Erbe) | Ziel‑App. Hat einen DSU‑Client mit Touch und Gyro und lässt Hintergrundeingaben zu. |
| [ClassicOldSong/Apollo](https://github.com/ClassicOldSong/Apollo) | GPL‑3.0 | Sunshine‑Fork mit virtueller Anzeige pro App | Host. Liefert Spielanzeige, Encoding und Ton. |
| [v1993/cemuhook-protocol](https://github.com/v1993/cemuhook-protocol) | — | Beschreibung des DSU‑Protokolls | Referenz für den DSU‑Server |

## Brücke (Direktmodus)

| Projekt | Lizenz | Was es macht | Nutzen für uns |
| --- | --- | --- | --- |
| [Gavwalsh15/toffee_wiiu](https://github.com/Gavwalsh15/toffee_wiiu) | GPL‑3.0‑only | Windows‑App und ESP32‑C5‑Firmware: Desktop auf das GamePad, Kopplung ohne Wii U, DSU‑Server | Spike A. Eigener Fork neben diesem Repo, Verbesserungen upstream. |
| [BetaZay/Barista](https://github.com/BetaZay/Barista) | GPL‑2.0 (Version offen) | Komplette Linux‑Brücke: Kopplung, Bild, Ton, Eingabe | Spike B. Als eigenes Programm nutzen, Code nicht einmischen. |
| [wozt/rtw88_TSF](https://github.com/wozt/rtw88_TSF) | GPL‑2.0 OR BSD‑3‑Clause (Dateiköpfe) | RTL8821CU‑Treiber mit TSF, Anleitung mit Messwerten | Treiber und Protokoll‑Stolpersteine |
| [libdrc](https://bitbucket.org/memahaxx/libdrc), Spiegel [opencma/libdrc](https://github.com/opencma/libdrc) | BSD‑2‑Clause | GamePad‑Protokoll mit Doku | Protokollwissen, Code übernehmbar |
| [drc-hostap](https://github.com/vanilla-wiiu/drc-hostap) | BSD‑3‑Clause | hostapd mit Nintendos WPS und WPA2 | Kopplung im Linux‑Weg |
| [wozt/drc-x264](https://github.com/wozt/drc-x264) | GPL‑2.0‑or‑later | x264 mit Modus für das GamePad | Encoder im Linux‑Weg |
| [DTRHnet/WiiU-GP-RE](https://github.com/DTRHnet/WiiU-GP-RE) | MIT | Analysen und Messungen zum Bildpfad | Wissen zu TSF und Encoder |
| [ravensclawx/wup-homebrew](https://github.com/ravensclawx/wup-homebrew) | GPL‑3.0‑or‑later | Eigene Software auf dem GamePad, normales WLAN | Nicht verfolgt: ändert die Firmware und braucht einmal eine Wii U |
| [pancreations/ZiiUScreen](https://github.com/pancreations/ZiiUScreen) | MIT | Windows‑Treiber für das GamePad | Braucht Kopplungsdaten einer Konsole |
| [thefloppydriver/pc2drc](https://github.com/thefloppydriver/pc2drc) | GPL‑2.0, archiviert | Desktop zum GamePad unter Linux | Historisch. Braucht eine Wii U zum Koppeln. |
| [vanilla-wiiu/vanilla](https://github.com/vanilla-wiiu/vanilla) | GPL‑2.0 | PC tritt gegenüber der Konsole als GamePad auf | Umgekehrte Richtung. Wiki zu Chipsätzen und WSL2. |

## Plan B: Relay über die Konsole

| Projekt | Lizenz | Was es macht | Nutzen für uns |
| --- | --- | --- | --- |
| [GaryOderNichts/moonlight-wiiu](https://github.com/GaryOderNichts/moonlight-wiiu) | GPL‑3.0 | Moonlight‑Client für die Wii U | Basis des Clients im Plan B |
| [Kneemund/RWUG-Client](https://github.com/Kneemund/RWUG-Client) | keine | Wii‑U‑App, die GamePad‑Daten per DSU sendet | Vorbild. Code erst, wenn der Autor eine Lizenz ergänzt. |
| [rw-r-r-0644/RemotePad](https://github.com/rw-r-r-0644/RemotePad) | — | Wii‑U‑App, die Eingaben an den PC sendet (2017) | Historische Referenz |
| [UsendMii](https://wiiubrew.org/wiki/UsendMii) / MiisendU | — | GamePad als PC‑Controller, mit Touch | Referenz für Touch‑Mapping |
| [Matojeje/Wii-U-Websocket](https://github.com/Matojeje/Wii-U-Websocket) | Unlicense | Touch über den Wii‑U‑Browser als PC‑Maus | Rückfall ganz ohne Homebrew |
