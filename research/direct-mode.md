# Direktmodus: GamePad ohne Konsole

Stand: 2026-11-25. Betrifft die Meilensteine M2 bis M4 der [Roadmap](../docs/roadmap.md). Diese Fassung ersetzt den ersten Entwurf.

Kennzeichnung: **(belegt)** heißt, die verlinkte Primärquelle sagt das so. **(Schluss)** heißt, das ist unsere Ableitung aus den Quellen. Sie ist nicht getestet.

## Ergebnis

- **Kopplung ohne Konsole funktioniert.** Drei unabhängige Projekte koppeln 2026 ein GamePad ganz ohne Wii U: [Barista](https://github.com/BetaZay/Barista/blob/main/README.md?plain=1#L13), [rtw88_TSF](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md?plain=1#L3-L5) und [Toffee](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/docs/setup.md?plain=1#L10). (belegt) Das „NOT EASY“ aus dem [pc2drc-README](https://github.com/thefloppydriver/pc2drc) ist damit überholt.
- **Den Stream von Apollo kann man nicht durchreichen.** Das GamePad hat SPS und PPS fest eingebaut und bekommt keinen Slice-Header ([libdrc h264-encoder.cpp L136-L190](https://github.com/opencma/libdrc/blob/master/src/h264-encoder.cpp#L136-L190), [rtw88_TSF L63-L69](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md?plain=1#L63-L69)). (belegt) Das Bild muss also eigens für das GamePad kodiert werden. (Schluss)
- **Die Zeitstempel müssen aus dem TSF des Access Points kommen.** Mit falscher Zeitbasis zeigt das GamePad kein Bild ([WiiU-GP-RE DISPLAY-WORKS.md L19-L48](https://github.com/DTRHnet/WiiU-GP-RE/blob/main/WiiU-tk/00-docs/research/DISPLAY-WORKS.md?plain=1#L19-L48)). (belegt)
- **Hardware-Encoder (NVENC, QSV) scheiden praktisch aus.** Alle funktionierenden Projekte kodieren in Software: x264 mit DRH-Patch oder ein eigener Encoder. Das kostet wenig CPU. (Schluss, Details in Abschnitt 2)

Empfehlung (Schluss):

1. **Spike A zuerst: Toffee mit einem ESP32-C5.** Eine Windows-App plus ein kleines ESP32-C5-Board am USB-Port. Kein Linux, kein Kernel-Patch, kein WLAN-Dongle. Der Host kodiert, das ESP32 macht Kopplung, Funk und TSF ([Toffee README L7-L10](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/README.md?plain=1#L7-L10)). Ein DSU-Server auf `127.0.0.1:26760` ist eingebaut ([framework.md L67-L80](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/docs/framework.md?plain=1#L67-L80)). Risiko: Das Projekt ist sehr jung (erste Version am 2026-11-15, [Releases](https://github.com/Gavwalsh15/toffee_wiiu/releases)) und steht unter GPL-3.0-only.
2. **Spike B als Rückfall: Linux-Brücke mit USB-Dongle.** Software-Stack von Barista oder von rtw88_TSF. Dongle mit RTL8811AU/RTL8821AU (von Barista getestet) oder RTL8821CU (von rtw88_TSF gemessen). Erst mit einem Ubuntu-Live-USB am Host prüfen, dann WSL2 versuchen, sonst ein x86-Mini-PC.
3. **Spike C als Alternative: wup-homebrew mit wup-stream.** Eigene Software auf dem GamePad. Das GamePad geht damit ins normale WLAN. Kein Dongle, kein TSF-Problem. Aber: braucht einmal eine Wii U mit Aroma oder UART und ändert die GamePad-Firmware ([wup-homebrew README L11-L20](https://github.com/ravensclawx/wup-homebrew/blob/main/README.md?plain=1#L11-L20)).
4. **Plan B bleibt das Relay** über moonlight-wiiu.

## 1. Kopplung ohne Konsole

### Ablauf im Protokoll

| Schritt | Was passiert | Beleg |
| --- | --- | --- |
| 1 | Die Brücke wählt einen Code aus vier Symbolen: ♠ = 0, ♥ = 1, ♦ = 2, ♣ = 3. Die WPS-PIN ist dieser Code plus `5678`. Koppelt man ein GamePad an den eigenen Rechner, darf man den Code frei wählen. | [wifi.rst L26-L32](https://github.com/opencma/libdrc/blob/master/web/docs/re/wifi.rst?plain=1#L26-L32) (belegt) |
| 2 | Die Brücke packt die vier Symbole als ein Byte (je 2 Bit) in das letzte Byte ihrer AP-MAC. | [Barista pairing.cpp L37-L44, L85-L95](https://github.com/BetaZay/Barista/blob/main/core/drh/pairing.cpp#L37-L95), [Toffee pairing_ap.cpp L68-L78](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/firmware/src/network/pairing_ap.cpp#L68-L78) (belegt) |
| 3 | Sie startet einen offenen Kopplungs-AP mit der SSID `WiiU<MAC ohne letztes Halbbyte><MAC>_STA1` und einem WPS-Registrar. | [wifi.rst L11-L16](https://github.com/opencma/libdrc/blob/master/web/docs/re/wifi.rst?plain=1#L11-L16), [Barista pairing.cpp L97-L105](https://github.com/BetaZay/Barista/blob/main/core/drh/pairing.cpp#L97-L105) (belegt) |
| 4 | Der Nutzer drückt SYNC am GamePad und gibt die Symbole ein. Das GamePad startet WPS als Enrollee. Dass es den richtigen AP über den Code in MAC und SSID findet, ist naheliegend, aber nicht dokumentiert. | [Barista user-guide.md L81-L88](https://github.com/BetaZay/Barista/blob/main/docs/user-guide.md?plain=1#L81-L88) (belegt), Suchlogik (Schluss) |
| 5 | WPS läuft mit Nintendos Änderung: Der KDK wird vor der Schlüsselableitung um 3 Byte nach links rotiert. | [wifi.rst L18-L22](https://github.com/opencma/libdrc/blob/master/web/docs/re/wifi.rst?plain=1#L18-L22), [Toffee esp-idf-nintendo-pairing.patch](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/patches/esp-idf-nintendo-pairing.patch) (belegt) |
| 6 | Am Ende von WPS hat das GamePad SSID, BSSID und PSK des normalen AP. | [wifi.rst L34-L35](https://github.com/opencma/libdrc/blob/master/web/docs/re/wifi.rst?plain=1#L34-L35) (belegt) |
| 7 | Die Brücke wechselt sofort auf den normalen AP: versteckte SSID `WiiU<MAC>`, WPA2-PSK mit Nintendo-Selektoren `a4:c0:e1`, PTK um 3 Byte rotiert. | [wifi.rst L40-L54](https://github.com/opencma/libdrc/blob/master/web/docs/re/wifi.rst?plain=1#L40-L54), [rtw88_TSF L45-L57](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md?plain=1#L45-L57) (belegt) |
| 8 | Das GamePad holt per DHCP `192.168.1.11`. Die Brücke hat `192.168.1.10`. | [wifi.rst L56-L57](https://github.com/opencma/libdrc/blob/master/web/docs/re/wifi.rst?plain=1#L56-L57), [network.rst L127-L139](https://github.com/opencma/libdrc/blob/master/web/docs/network.rst?plain=1#L127-L139) (belegt) |

Korrektur zum Entwurf: Das GamePad zeigt keine PIN an. Die Brücke zeigt die Symbole, der Nutzer tippt sie am GamePad ein ([Barista user-guide.md L57-L60](https://github.com/BetaZay/Barista/blob/main/docs/user-guide.md?plain=1#L57-L60)). (belegt)

### Wer die Registrar-Seite umsetzt

| Projekt | Umsetzung | Beleg |
| --- | --- | --- |
| Barista | hostapd aus dem Vanilla-Fork von drc-hostap als Registrar, PIN per `WPS_PIN any`. Code zufällig oder per `--code` wählbar. | [pairing.cpp L107-L111](https://github.com/BetaZay/Barista/blob/main/core/drh/pairing.cpp#L107-L111), [COMPILING.md L53](https://github.com/BetaZay/Barista/blob/main/COMPILING.md?plain=1#L53), [user-guide.md L57-L60](https://github.com/BetaZay/Barista/blob/main/docs/user-guide.md?plain=1#L57-L60) |
| rtw88_TSF (wozt) | eigener Fork von drc-hostap „plus fresh pairing“, Vorlagen für Kopplungs-AP und normalen AP | [WIIU_GAMEPAD.md L12-L17, L59](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md?plain=1#L12-L59) |
| Toffee | WPS-Registrar im ESP-IDF mit Nintendo-Patch (KDK, Selektoren, PTK) | [pairing_ap.cpp L99-L116](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/firmware/src/network/pairing_ap.cpp#L99-L116), [Patch](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/patches/esp-idf-nintendo-pairing.patch) |
| memahaxx drc-hostap (2013) | hatte schon eine Vorlage `wiiu_ap_pairing.conf`, um das Koppeln zu simulieren. Die SSID ist dort nur ein Platzhalter. | [README.DRC in drc-hostap](https://bitbucket.org/memahaxx/drc-hostap) |
| libdrc-Doku | nennt „Computer als WPS-Host“ nur als TODO | [network.rst L97-L98](https://github.com/opencma/libdrc/blob/master/web/docs/network.rst?plain=1#L97-L98) |

`get_psk` ist kein Weg ohne Konsole. Dabei verbindet sich der PC als Client mit einer Wii U und holt die Zugangsdaten per WPS ab ([network.rst L43-L95](https://github.com/opencma/libdrc/blob/master/web/docs/network.rst?plain=1#L43-L95)). Auch pc2drc setzt eine Wii U voraus ([pc2drc README](https://github.com/thefloppydriver/pc2drc)). (belegt) Wir nehmen den anderen Weg: Die Brücke ist selbst der Registrar.

### Ablauf für den Nutzer

1. An der Brücke die Kopplung starten. Barista: „GamePads → Pair a GamePad“ ([user-guide.md L81-L88](https://github.com/BetaZay/Barista/blob/main/docs/user-guide.md?plain=1#L81-L88)). Toffee: „Pair new GamePad“ oder `toffee-cli pair` ([setup.md L66-L67](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/docs/setup.md?plain=1#L66-L67)).
2. Barista fragt dabei nach einer Freigabe, weil es den WLAN-Adapter übernimmt ([user-guide.md L84-L85](https://github.com/BetaZay/Barista/blob/main/docs/user-guide.md?plain=1#L84-L85)).
3. Warten, bis die Brücke vier Symbole zeigt. Mit dem TP-Link Nano AC600 dauert das einige Sekunden ([hardware.md L21-L25](https://github.com/BetaZay/Barista/blob/main/docs/hardware.md?plain=1#L21-L25)).
4. GamePad einschalten. Den roten SYNC-Knopf auf der Rückseite drücken, etwa mit dem Stift ([Nintendo-Hilfe](https://en-americas-support.nintendo.com/app/answers/detail/a_id/1131/~/how-to-sync-a-wii-u-gamepad-with-a-wii-u-console), [Toffee setup.md L58](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/docs/setup.md?plain=1#L58)).
5. Die Symbole von links nach rechts am GamePad eingeben ([user-guide.md L87-L88](https://github.com/BetaZay/Barista/blob/main/docs/user-guide.md?plain=1#L87-L88)).
6. Fertig, wenn die Brücke das GamePad als bereit meldet. Danach verbindet es sich von selbst ([Toffee setup.md L61-L64](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/docs/setup.md?plain=1#L61-L64), [Barista user-guide.md L90-L91](https://github.com/BetaZay/Barista/blob/main/docs/user-guide.md?plain=1#L90-L91)).

Vermutlich ersetzt die neue Kopplung die bisherige mit einer Wii U. Für das Relay müsste man dann an der Konsole neu koppeln. (Schluss, im Spike prüfen)

### Stolpersteine

- **PSK als 64 Hex-Zeichen** (`wpa_psk=`), nie als Passphrase. Sonst sucht das GamePad die SSID, authentifiziert sich aber nie ([rtw88_TSF L51-L53](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md?plain=1#L51-L53), [Barista backend_linux.cpp L515-L540](https://github.com/BetaZay/Barista/blob/main/core/drh/server/backend_linux.cpp#L515-L540)). (belegt)
- **Schneller Wechsel** vom Kopplungs-AP zum normalen AP: deutlich unter den etwa 4 s, die das GamePad nach M8 wartet. hostapd mit SIGTERM beenden, nicht mit SIGKILL ([rtw88_TSF L54-L57](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md?plain=1#L54-L57)). (belegt)
- **AP-MAC mit Nintendo-OUI**, das GamePad filtert darauf ([rtw88_TSF L33](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md?plain=1#L33)). (belegt)
- **Nintendo-Selektoren** `a4:c0:e1` im RSN-Element. Ein normales hostapd kann das nicht, dafür gibt es drc-hostap ([wifi.rst L40-L51](https://github.com/opencma/libdrc/blob/master/web/docs/re/wifi.rst?plain=1#L40-L51), [README.DRC](https://bitbucket.org/memahaxx/drc-hostap)). (belegt)
- **WPS-Prüfziffer**: Barista hat einen Rückfall mit korrigierter Prüfziffer, falls hostapd die PIN ablehnt ([backend_linux.cpp L2618-L2690](https://github.com/BetaZay/Barista/blob/main/core/drh/server/backend_linux.cpp#L2618-L2690)). (belegt)
- **Funkregeln**: nur 5 GHz. Kanal 36 bis 48 braucht den Indoor-Wert `country3=0x49`, sonst lehnt der Treiber den AP ab ([rtw88_TSF L31-L32](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md?plain=1#L31-L32)). (belegt) Für Deutschland `country_code=DE` setzen. (Schluss)
- **NetworkManager** muss den Adapter freigeben. Internet läuft dann über Kabel oder einen zweiten Adapter ([network.rst L118-L119](https://github.com/opencma/libdrc/blob/master/web/docs/network.rst?plain=1#L118-L119), [Barista hardware.md L5-L13](https://github.com/BetaZay/Barista/blob/main/docs/hardware.md?plain=1#L5-L13)). (belegt)
- **Netz 192.168.1.0/24** darf sonst nirgends benutzt werden. MTU 1800 ([network.rst L127-L131](https://github.com/opencma/libdrc/blob/master/web/docs/network.rst?plain=1#L127-L131)). (belegt) Viele Heimrouter nutzen genau dieses Netz. (Schluss)
- **rtw88**: Modul mit `disable_ips=1` laden. Sonst liefert jedes TSF-Lesen `0xEAEAEAEA` ([rtw88_TSF L39-L41](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md?plain=1#L39-L41)). (belegt)
- **Intel iwlwifi**: Die Firmware kann im AP-Modus alle Kopplungskanäle auf NO-IR setzen ([Barista hardware.md L27-L35](https://github.com/BetaZay/Barista/blob/main/docs/hardware.md?plain=1#L27-L35)). (belegt)

## 2. Protokoll zwischen Brücke und GamePad

### Kanäle und Ports

| Dienst | Port Brücke | Port GamePad | Richtung | Inhalt | Beleg |
| --- | --- | --- | --- | --- | --- |
| msg | 50010 | 50110 | beide | Nachrichten, auch als Broadcast | [services.rst L41-L43](https://github.com/opencma/libdrc/blob/master/web/docs/re/services.rst?plain=1#L41-L43) |
| vstrm | 50020 | 50120 | zum GamePad | Bild (zurück: Kamera) | [sc-vstrm.rst L4-L13](https://github.com/opencma/libdrc/blob/master/web/docs/re/sc-vstrm.rst?plain=1#L4-L13) |
| astrm | 50021 | 50121 | zum GamePad | Ton und Videoformat (zurück: Mikrofon) | [sc-astrm.rst L4-L17](https://github.com/opencma/libdrc/blob/master/web/docs/re/sc-astrm.rst?plain=1#L4-L17) |
| input | 50022 | 50122 | zur Brücke | Eingabe, 128 Byte, 180-mal pro Sekunde | [sc-input.rst L4-L13](https://github.com/opencma/libdrc/blob/master/web/docs/re/sc-input.rst?plain=1#L4-L13) |
| cmd | 50023 | 50123 | beide | Befehle, UVC/UAC, Zeit | [rtw88_TSF L37](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md?plain=1#L37) |

Alle Angaben (belegt).

### Bild (vstrm)

- **Paket**: 8 Byte Kopf mit Sequenz, Flags (`frame_begin`, `chunk_end`, `frame_end`), Länge und 32-Bit-Zeitstempel. Dazu 8 Byte Optionen, etwa IDR, Bildrate und Zeilen pro Chunk ([sc-vstrm.rst L15-L70](https://github.com/opencma/libdrc/blob/master/web/docs/re/sc-vstrm.rst?plain=1#L15-L70)). (belegt)
- **Chunks**: Jedes Bild wird in 5 Teile zu je 6 Makroblock-Zeilen geteilt ([sc-vstrm.rst L77-L89](https://github.com/opencma/libdrc/blob/master/web/docs/re/sc-vstrm.rst?plain=1#L77-L89)). Das GamePad setzt sie wieder zu einem einzigen CABAC-Slice zusammen. Die Grenzen sind also nur Transport ([ENCODER-VERDICT.md L13-L21](https://github.com/DTRHnet/WiiU-GP-RE/blob/main/WiiU-tk/00-docs/research/ENCODER-VERDICT.md?plain=1#L13-L21)). (belegt)
- **SPS und PPS** stecken fest im GamePad. libdrc sendet sie nie ([h264-encoder.cpp L55-L57, L171-L173](https://github.com/opencma/libdrc/blob/master/src/h264-encoder.cpp#L55-L57)). (belegt) Unsere Dekodierung dieser Bytes ergibt: High Profile, Level 3.2, 864×480 mit Beschnitt auf 854, POC-Typ 2, ein Referenzbild, CABAC, `pic_init_qp` 32, eingeschränkte Intra-Prädiktion, kein 8×8-Transform. (Schluss, nachprüfbar) WiiU-GP-RE bestätigt „854x480 High/L3.2“ ([ENCODER-VERDICT.md L15-L17](https://github.com/DTRHnet/WiiU-GP-RE/blob/main/WiiU-tk/00-docs/research/ENCODER-VERDICT.md?plain=1#L15-L17)).
- **Kein Slice-Header**: Das GamePad nimmt einen festen Kopf an. Deshalb ist der QP fest 32. Nur `mb_qp_delta` pro Makroblock geht ([rtw88_TSF L63-L69, L137-L140](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md?plain=1#L63-L69)). (belegt)
- **x264-Parameter in libdrc**: CQP 32, keine B-Frames, ein Referenzbild, eingeschränkte Intra-Prädiktion, kein Weighted Prediction, kein 8×8, kein PSUB16x16, Intra-Refresh mit Keyint 10 bis 30, Profil main, `b_drh_mode` ([h264-encoder.cpp L136-L190](https://github.com/opencma/libdrc/blob/master/src/h264-encoder.cpp#L136-L190)). (belegt)
- **Keine planare Intra-Prädiktion**: Das muss im Encoder selbst abgeschaltet sein ([h264-encoder.cpp L176-L178](https://github.com/opencma/libdrc/blob/master/src/h264-encoder.cpp#L176-L178), [Barista MINIH264_UPSTREAM.md L13-L19](https://github.com/BetaZay/Barista/blob/main/core/drh/encoder/x264/MINIH264_UPSTREAM.md?plain=1#L13-L19)). (belegt)
- **Preset**: libdrc nutzt `slow` ([h264-encoder.cpp L40](https://github.com/opencma/libdrc/blob/master/src/h264-encoder.cpp#L40)). Bei echtem Video fordert das GamePad dann ständig Keyframes an. `medium` oder schneller nehmen ([rtw88_TSF L70](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md?plain=1#L70)). (belegt)
- **Format**: 864×480 einspeisen, sonst bleibt ein grauer Streifen. 59,94 Bilder pro Sekunde ([rtw88_TSF L75-L76](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md?plain=1#L75-L76)). (belegt)
- **Takt**: Die Pakete eines Bildes über das Bildintervall verteilen, nicht als Block senden ([rtw88_TSF L80-L84](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md?plain=1#L80-L84), [Toffee architecture.md L104-L106](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/docs/architecture.md?plain=1#L104-L106)). (belegt)
- **Videoformat-Paket**: Vor jedem Bild geht über astrm ein Formatpaket mit demselben Zeitstempel raus ([sc-astrm.rst L59-L71](https://github.com/opencma/libdrc/blob/master/web/docs/re/sc-astrm.rst?plain=1#L59-L71), [video-streamer.cpp L99-L116, L197](https://github.com/opencma/libdrc/blob/master/src/video-streamer.cpp#L99-L116)). (belegt)
- **Messwerte**: Die Bank von rtw88_TSF lief 98 s mit 60 Bildern pro Sekunde, 2,76 Mbit/s und null Keyframe-Anfragen. Der Player brauchte etwa 30 % eines CPU-Kerns ([rtw88_TSF L93-L102](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md?plain=1#L93-L102)). (belegt)

### Ton (astrm)

- PCM mit 48 kHz ist Format 1 ([sc-astrm.rst L39-L46](https://github.com/opencma/libdrc/blob/master/web/docs/re/sc-astrm.rst?plain=1#L39-L46)). libdrc sendet 16 Bit Stereo: 384 Samples als ein Paket zu 1536 Byte alle 8 ms ([audio-streamer.cpp L46-L47](https://github.com/opencma/libdrc/blob/master/src/audio-streamer.cpp#L46-L47)). (belegt)
- Ein Tonpaket ist 1572 Byte groß. Bei MTU 1500 wird es fragmentiert, das führte zu Hängern. Daher MTU 1800 ([rtw88_TSF L34](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md?plain=1#L34)). (belegt)
- Auch der Ton trägt TSF-Zeitstempel. Zu späte Pakete verwirft das GamePad ohne Meldung ([rtw88_TSF L86-L89](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md?plain=1#L86-L89)). (belegt)
- Das Vibrations-Flag steckt im astrm-Kopf ([sc-astrm.rst L27-L35](https://github.com/opencma/libdrc/blob/master/web/docs/re/sc-astrm.rst?plain=1#L27-L35), [Toffee architecture.md L106](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/docs/architecture.md?plain=1#L106)). (belegt)

### Eingabe

- Das GamePad sendet einen 128-Byte-Block 180-mal pro Sekunde: Tasten, Sticks, Akku, Beschleunigung, Gyro, Magnetometer und Touch ([sc-input.rst L11-L13, L25-L43](https://github.com/opencma/libdrc/blob/master/web/docs/re/sc-input.rst?plain=1#L11-L43)). (belegt)
- Für den Eingabekanal zu Lichii muss das in DSU übersetzt werden. Toffee macht das schon: Slot 0, Touch auf das DS4-Touchpad skaliert, nur auf `127.0.0.1`. Die Achsen hat Toffee noch nicht mit einem echten DSU-Client geprüft ([framework.md L77-L86](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/docs/framework.md?plain=1#L77-L86)). (belegt)
- Barista bietet unter Linux einen virtuellen Controller über uinput ([README L15](https://github.com/BetaZay/Barista/blob/main/README.md?plain=1#L15)). (belegt) Ein DSU-Server fehlt dort, den müssten wir auf der Brücke ergänzen. (Schluss)

### Befehle und Zeit (cmd)

- Ein UVC/UAC-Befehl geht jede Sekunde raus. Neuere GamePad-Firmware zeigt erst danach überhaupt ein Bild ([sc-cmd.rst L304-L305](https://github.com/opencma/libdrc/blob/master/web/docs/re/sc-cmd.rst?plain=1#L304-L305)). (belegt)
- Wechselt der Stream, sollte die Brücke das GamePad abmelden (`hostapd_cli deauthenticate`). Sonst bleibt der Decoder auf dem letzten Bild stehen ([rtw88_TSF L118-L120](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md?plain=1#L118-L120)). (belegt)

### Hardware-Encoder und der Stream von Apollo

- Apollo liefert normales H.264, HEVC oder AV1 mit eigenen Parameter-Sätzen, Slice-Headern und Ratenregelung. Das GamePad ignoriert all das und erwartet QP 32 ohne Kopf. Ein Durchreichen geht deshalb nicht. Apollo patchen wir laut ADR 0002 nicht. (Schluss)
- Es bleiben zwei Wege. (Schluss)
  - **Neu kodieren auf der Brücke**: Die Brücke empfängt den Moonlight-Stream, dekodiert ihn und kodiert für das GamePad neu. Das kostet einen zusätzlichen Schritt und Latenz.
  - **Direkt auf dem Host abgreifen**: Toffee liest eine Anzeige per Desktop Duplication, skaliert auf der GPU und kodiert mit x264 in einem eigenen Prozess ([architecture.md L69-L71, L88-L98](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/docs/architecture.md?plain=1#L69-L98)). (belegt) Apollo wäre im Bildpfad dann nicht mehr nötig. (Schluss)
- NVENC oder QSV müssten exakt den festen SPS/PPS treffen: ein Slice, Slice-QP 32, keine planare Prädiktion, eingeschränkte Intra-Prädiktion, POC-Typ 2. Eine Option zum Abschalten der planaren Prädiktion ist uns nicht bekannt. (Schluss, Herstellerdoku nicht geprüft)
- Software-Kodierung ist billig: Baristas Encoder braucht 4,5 ms pro Bild auf einem Ryzen 5 7600 ([VALIDATION.md L25-L30](https://github.com/BetaZay/Barista/blob/main/core/drh/encoder/x264/VALIDATION.md?plain=1#L25-L30)). (belegt) Hardware-Encoder lohnen sich also nicht. (Schluss)
- Ein früherer Versuch kodierte auf Windows und reichte fertiges H.264 über einen Raspberry Pi weiter. Das Bild fror nach 5 bis 10 s ein. Der Autor vermutet TSF-Drift seines Adapters ([libdrc-streaming README L1-L12, L43-L48](https://github.com/ywh233/libdrc-streaming/blob/master/README.md?plain=1#L1-L48)). (belegt) Toffee nutzt dieselbe Teilung und stempelt den TSF auf dem ESP32. (belegt, siehe Abschnitt 4)

## 3. Projekte und Lizenzen

Lizenz nach Lizenzdatei und GitHub-API (belegt). Die Spalte „Für uns“ ist unsere Bewertung (Schluss, keine Rechtsberatung).

| Projekt | Lizenz (SPDX) | „or later“ | Zuletzt aktiv | Archiviert | Sprache | Was es kann | Für uns |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [libdrc (memahaxx)](https://bitbucket.org/memahaxx/libdrc), Spiegel [opencma/libdrc](https://github.com/opencma/libdrc) (früher rolandoislas), [GaryOderNichts/libdrc](https://github.com/GaryOderNichts/libdrc) | BSD-2-Clause ([LICENSE](https://github.com/opencma/libdrc/blob/master/LICENSE)) | – | 2014-02-06, Spiegel 2017-07-14, Gary 2025-01-24 (Doku) | nein | C++ | Protokoll für Bild, Ton, Eingabe, cmd; TSF lesen | Code übernehmbar |
| [drc-hostap (memahaxx)](https://bitbucket.org/memahaxx/drc-hostap), [vanilla-wiiu/drc-hostap](https://github.com/vanilla-wiiu/drc-hostap), [wozt/drc-hostap](https://github.com/wozt/drc-hostap) | BSD-3-Clause (hostap) | – | 2026-08-26 (Vanilla, hostap 2.12) | nein | C | Nintendo-WPS und -WPA2 in hostapd | Code übernehmbar |
| [drc-x264 (memahaxx)](https://bitbucket.org/memahaxx/drc-x264), [wozt/drc-x264](https://github.com/wozt/drc-x264) | GPL-2.0-or-later (x264) | ja | 2026-09-14 (wozt) | nein | C | DRH-Modus, keine planare Prädiktion | Code übernehmbar |
| [drc-mac80211 (memahaxx)](https://bitbucket.org/memahaxx/drc-mac80211), [pc2drc-Kernelpatch](https://github.com/thefloppydriver/pc2drc/blob/main/kernel-patch-files/patches/kernel_above_5_11_mac80211.patch) | GPL-2.0-only (Linux-Kernel) | nein | 2013-12-25 / 2026-04-05 | pc2drc ja | C | sysfs-Datei `tsf` | nur als getrennter Kernel-Patch |
| [pc2drc](https://github.com/thefloppydriver/pc2drc) | GPL-2.0, nur Lizenztext | unklar | 2026-04-05 | ja | C, Shell | Skripte und Patch, braucht eine Wii U | Ideen, Code nicht einmischen |
| [Vanilla](https://github.com/vanilla-wiiu/vanilla) | GPL-2.0, nur Lizenztext | unklar | 2026-11-21 | nein | C | PC als GamePad an der Konsole (umgekehrte Richtung) | Wissen und Wiki |
| [Barista](https://github.com/BetaZay/Barista) | GPL-2.0, nur Lizenztext | unklar | 2026-11-07 | nein | C++ | komplette Linux-Brücke: Kopplung, Bild, Ton, Eingabe, Monitor-TSF, eigener Encoder | als eigenes Programm nutzen, Code nicht einmischen |
| [rtw88_TSF](https://github.com/wozt/rtw88_TSF) | Dateiköpfe „GPL-2.0 OR BSD-3-Clause“, keine Lizenzdatei | – | 2026-09-14 | nein | C | RTL8821CU-Treiber mit TSF, Anleitung mit Messwerten | als getrenntes Kernelmodul |
| [Toffee](https://github.com/Gavwalsh15/toffee_wiiu) | GPL-3.0-only ([README L62-L68](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/README.md?plain=1#L62-L68)) | nein | 2026-11-16 (v0.1.1) | nein | C++ | Windows-App und ESP32-C5-Firmware, DSU-Server | als eigener Fork, nicht einmischen |
| [wup-homebrew](https://github.com/ravensclawx/wup-homebrew), [wup-stream](https://github.com/ravensclawx/wup-stream) | GPL-3.0-or-later, Installer GPL-2.0-or-later | ja | 2026-11-19 | nein | C | Software auf dem GamePad, Host-Bibliothek für Windows, Linux, macOS | Code übernehmbar |
| [opencma/drc-sim](https://github.com/opencma/drc-sim), [opencma/drc-sim-c](https://github.com/opencma/drc-sim-c), [rodolforg/drc-sim](https://github.com/rodolforg/drc-sim) | GPL-2.0-or-later | ja | 2023-02-10, 2024-05-02, 2022-09-04 | nein | Python, C++ | PC als GamePad an der Konsole (umgekehrte Richtung) | übernehmbar, aber falsche Richtung |
| [WiiU-GP-RE](https://github.com/DTRHnet/WiiU-GP-RE) | MIT (Lizenztext, GitHub erkennt ihn nicht eindeutig) | – | 2026-11-04 | nein | Python | Analysen und Messungen zum Bildpfad | Code übernehmbar |
| [ZiiUScreen](https://github.com/pancreations/ZiiUScreen) | MIT | – | 2026-10-17 | nein | C++ | Windows-Treiber, braucht Kopplungsdaten einer Konsole, konsolenfreie Kopplung unfertig | übernehmbar, löst aber die Kopplung nicht |
| [libdrc-streaming (ywh233)](https://github.com/ywh233/libdrc-streaming) | keine | – | 2020-12-13 | nein | C++ | Windows kodiert, Pi reicht weiter | kein Code |

Was das für unser Repo unter GPL-3.0-or-later heißt (Schluss):

- **Übernehmbar** sind libdrc (BSD-2-Clause), hostap und drc-hostap (BSD-3-Clause), x264 und drc-x264 (GPL-2.0-or-later), wup-homebrew und wup-stream (GPL-3.0-or-later), drc-sim (GPL-2.0-or-later), WiiU-GP-RE und ZiiUScreen (MIT). Hinweise und Lizenztexte müssen erhalten bleiben. Der Encoder in Barista basiert auf [minih264](https://github.com/lieff/minih264) (CC0-1.0), Baristas Änderungen daran stehen aber unter Baristas Lizenz.
- **Nur getrennt**: Kernel-Patches und Kernelmodule bleiben GPL-2.0. Sie gehören als eigene Patch-Dateien oder in ein eigenes Repo, nicht in unseren Code. Bei rtw88_TSF erlaubt die BSD-3-Option eine Übernahme.
- **Nicht einmischen**: pc2drc, Vanilla und Barista legen nur den GPL-2.0-Text bei, ohne Versionshinweis in den Dateien (bei Barista stichprobenhaft geprüft). Nach [GPL-2.0 Abschnitt 9](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html) darf man ohne Versionsangabe jede Version wählen. Ob der beigelegte Text schon als Versionsangabe gilt, ist umstritten. Sicher ist: wie GPL-2.0-only behandeln. Diese Programme also nur als eigenständige Werkzeuge nutzen oder die Autoren um „or later“ bitten.
- **Toffee** ist GPL-3.0-only. Code daraus würde unser Gesamtwerk auf GPL-3.0-only festlegen. Besser: ein eigener Fork von Toffee neben unserem Repo, Verbesserungen als PR upstream.

## 4. WLAN-Hardware und TSF

### Warum der TSF zählt

- Der TSF ist der 64-Bit-Mikrosekundenzähler des Access Points. Er steht in jedem Beacon. Das GamePad richtet seine Wiedergabe nach dem TSF aus, den es aus unseren Beacons lernt. Die Zeitstempel in vstrm und astrm müssen daher im TSF-Bereich liegen ([DISPLAY-WORKS.md L21-L24](https://github.com/DTRHnet/WiiU-GP-RE/blob/main/WiiU-tk/00-docs/research/DISPLAY-WORKS.md?plain=1#L21-L24)). (belegt)
- Liegen sie daneben, verwirft das GamePad jedes Bild und fordert ständig Keyframes an. Es zeigt nichts ([DISPLAY-WORKS.md L29-L48](https://github.com/DTRHnet/WiiU-GP-RE/blob/main/WiiU-tk/00-docs/research/DISPLAY-WORKS.md?plain=1#L29-L48)). (belegt)
- libdrc liest den TSF aus `/sys/class/net/<if>/device/tsf` oder `/sys/class/net/<if>/tsf` ([tsf-linux.cpp L75-L99](https://github.com/opencma/libdrc/blob/master/src/tsf-linux.cpp#L75-L99)). Linux bietet diese Datei von Haus aus nicht an, daher der Kernel-Patch ([network.rst L9-L36](https://github.com/opencma/libdrc/blob/master/web/docs/network.rst?plain=1#L9-L36)). (belegt)

### Wege zum TSF

| Weg | Wie | Beleg |
| --- | --- | --- |
| mac80211-Patch | Legt eine sysfs-Datei `tsf` an, die `drv_get_tsf` aufruft. Hilft nur, wenn der Treiber `get_tsf` hat. | [pc2drc-Patch L8-L44](https://github.com/thefloppydriver/pc2drc/blob/main/kernel-patch-files/patches/kernel_above_5_11_mac80211.patch#L8-L44) (belegt), Einschränkung (Schluss aus dem Code) |
| Monitor-Interface | Zweites Interface im Monitor-Modus auf demselben Funkchip. Der TSF kommt aus dem Radiotap-Feld empfangener Frames. Kein Kernel-Patch. rtw88 liefert dort nur 32 Bit. | [Barista backend_linux.cpp L1479-L1520](https://github.com/BetaZay/Barista/blob/main/core/drh/server/backend_linux.cpp#L1479-L1520), [monitor_tsf_clock.h L10-L12](https://github.com/BetaZay/Barista/blob/main/core/drh/monitor_tsf_clock.h#L10-L12) (belegt) |
| Treiber mit eigener TSF-Datei | rtw88_TSF legt den TSF des RTL8821CU offen | [rtw88_TSF README](https://github.com/wozt/rtw88_TSF/blob/master/README.md), [WIIU_GAMEPAD.md L12-L17](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md?plain=1#L12-L17) (belegt) |
| ESP32-C5 | `esp_wifi_get_tsf_time` direkt in der Firmware, für Bild und Ton | [video_stream.cpp L276-L282](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/firmware/src/video/video_stream.cpp#L276-L282), [audio_stream.cpp L64](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/firmware/src/audio/audio_stream.cpp#L64) (belegt) |
| Versatz zur Systemuhr | Monotone Uhr plus gemessener Versatz. Fehleranfällig. rtw88_TSF rät davon ab. | [DISPLAY-WORKS.md L24-L33](https://github.com/DTRHnet/WiiU-GP-RE/blob/main/WiiU-tk/00-docs/research/DISPLAY-WORKS.md?plain=1#L24-L33), [rtw88_TSF L86-L89](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md?plain=1#L86-L89) (belegt) |

### Chipsätze

Die Liste im [Vanilla-Wiki](https://github.com/vanilla-wiiu/vanilla/wiki/Wireless-Compatibility) gilt für die umgekehrte Richtung: PC als Client an der Konsole. Für unseren AP-Modus ist sie nur ein Hinweis. (Schluss)

| Chipsatz (Treiber) | 5-GHz-AP | TSF-Weg | GamePad ohne Konsole | Hinweis |
| --- | --- | --- | --- | --- |
| RTL8811AU, RTL8821AU (rtw88_8821au) | ja, in Linux ab 6.14 ([morrownr](https://github.com/morrownr/USB-WiFi/blob/main/home/USB_WiFi_Chipsets.md)) | Monitor | belegt, Barista mit TP-Link Nano AC600 ([hardware.md L21-L25](https://github.com/BetaZay/Barista/blob/main/docs/hardware.md?plain=1#L21-L25)) | Kopplungs-AP braucht einige Sekunden |
| RTL8821CU (rtw88_8821cu, rtw88_TSF) | ja | eigene TSF-Datei | belegt, mit Messwerten ([WIIU_GAMEPAD.md L21-L25](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md?plain=1#L21-L25)) | `disable_ips=1`; morrownr rät für den Alltag ab |
| RTL8852BE (rtw89, PCIe) | ja | Monitor | belegt, Baristas Entwicklungskarte ([hardware.md L15-L19](https://github.com/BetaZay/Barista/blob/main/docs/hardware.md?plain=1#L15-L19)) | nur intern (M.2), nicht USB |
| MT7921AU (mt7921u) | ja, ab Linux 5.19 (morrownr) | `get_tsf` im Treiber ([main.c L1574](https://github.com/torvalds/linux/blob/4dce97c6c265544342e716e62fd24bbb232590c5/drivers/net/wireless/mediatek/mt76/mt7921/main.c#L1574), [mt792x_core.c L331](https://github.com/torvalds/linux/blob/4dce97c6c265544342e716e62fd24bbb232590c5/drivers/net/wireless/mediatek/mt76/mt792x_core.c#L331)), also mac80211-Patch möglich | nicht belegt | Kandidat für einen Spike |
| RT5572 (rt2800usb) | ja | `get_tsf` ([rt2800usb.c L655](https://github.com/torvalds/linux/blob/4dce97c6c265544342e716e62fd24bbb232590c5/drivers/net/wireless/ralink/rt2x00/rt2800usb.c#L655)) | nur mit Konsolen-Kopplung belegt (libdrc, pc2drc) | alt, kaum noch zu kaufen; ein Nutzer sah TSF-Drift ([libdrc-streaming L43-L48](https://github.com/ywh233/libdrc-streaming/blob/master/README.md?plain=1#L43-L48)) |
| ath9k, carl9170 | ja | `get_tsf` ([htc_drv_main.c L1893](https://github.com/torvalds/linux/blob/4dce97c6c265544342e716e62fd24bbb232590c5/drivers/net/wireless/ath/ath9k/htc_drv_main.c#L1893)) | nicht belegt | libdrc meldet TSF-Drift ([network.rst L21-L23](https://github.com/opencma/libdrc/blob/master/web/docs/network.rst?plain=1#L21-L23)) |
| MT7610U, MT7612U (mt76x0u, mt76x2u) | ja | kein `get_tsf` gefunden (Schluss aus dem Kernel-Code) | nicht belegt | MT7612U im Vanilla-Wiki nur teilweise |
| Intel iwlwifi (AX200, AX201, AX210) | eingeschränkt | kein `get_tsf` in mvm gefunden (Schluss) | AX200 lief bei Barista, AX201 scheiterte an NO-IR ([hardware.md L27-L35](https://github.com/BetaZay/Barista/blob/main/docs/hardware.md?plain=1#L27-L35)) | nicht empfohlen |
| FullMAC, z. B. CYW43455 im Raspberry Pi | nein | – | nein | im Vanilla-Wiki „Not Working“, FullMAC braucht Firmware-Patches ([Wiki SBC](https://github.com/vanilla-wiiu/vanilla/wiki/Single%E2%80%90Board-Computers)) |
| ESP32-C5 | ja, eigener Stack | ESP-IDF-Funktion | belegt, Toffee ([setup.md L10-L16](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/docs/setup.md?plain=1#L10-L16)) | Funkregion fest Irland, änderbar per Neubau ([setup.md L151-L155](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/docs/setup.md?plain=1#L151-L155)) |

### Empfohlene Hardware

| Rang | Gerät | Chipsatz | Warum |
| --- | --- | --- | --- |
| 1 | Waveshare ESP32-C5-Zero | ESP32-C5 | Toffees Entwicklungsboard ([README L17-L18](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/README.md?plain=1#L17-L18)). Läuft am Windows-Host ohne Linux. |
| 2 | TP-Link „Nano AC600“, wie bei Barista verlinkt; Alternative ALFA AWUS036ACS | RTL8811AU | Von Barista mit GamePad getestet. Treiber steckt im Linux-Kernel und im WSL-Kernel. ALFA-Modell laut [morrownr-Liste](https://github.com/morrownr/USB-WiFi/blob/main/home/USB_WiFi_Adapters_that_are_supported_with_Linux_in-kernel_drivers.md). |
| 3 | Ein Adapter mit RTL8821CU, etwa TP-Link Archer T600UB Nano (laut Vanilla-Wiki) | RTL8821CU | Einzige Messreihe mit Zahlen (rtw88_TSF). Braucht das Modul rtw88_TSF statt des Standardtreibers. |
| Option | ALFA AWUS036AXML, Netgear A7500 oder BrosTrend AX9L ([morrownr-Liste](https://github.com/morrownr/USB-WiFi/blob/main/home/USB_WiFi_Adapters_that_are_supported_with_Linux_in-kernel_drivers.md)) | MT7921AU | Treiber in Mainline mit `get_tsf` und AP-Modus. Mit GamePad aber nicht belegt. |

Hersteller wechseln den Chipsatz manchmal zwischen Revisionen. Vor dem Einsatz mit `lsusb` die USB-ID prüfen. (Schluss)

## 5. Plattform der Brücke

### WSL2

Belegt:

- usbipd-win reicht USB-Geräte in WSL2 durch ([Microsoft: USB-Geräte verbinden](https://learn.microsoft.com/en-us/windows/wsl/connect-usb), [usbipd-win Wiki](https://github.com/dorssel/usbipd-win/wiki/WSL-support)). PCIe-WLAN-Karten gehen nicht, nur USB ([Vanilla-Wiki WSL2](https://github.com/vanilla-wiiu/vanilla/wiki/Windows-%E2%80%90-WSL2)).
- Ein eigener Kernel wird per `.wslconfig` mit `kernel=` geladen, eigene Module per `kernelModules` ([wsl-config.md L236, L322-L325](https://github.com/MicrosoftDocs/WSL/blob/main/WSL/wsl-config.md?plain=1#L236-L325)).
- Der aktuelle WSL-Kernel 6.18 bringt cfg80211 und mac80211 als Module mit ([config-wsl L1915, L1925](https://github.com/microsoft/WSL2-Linux-Kernel/blob/linux-msft-wsl-6.18.64.1/arch/x86/configs/config-wsl#L1915-L1925)). Dazu MT7921U ([L2800](https://github.com/microsoft/WSL2-Linux-Kernel/blob/linux-msft-wsl-6.18.64.1/arch/x86/configs/config-wsl#L2800)), rtw88 für 8821CU, 8821AU und 8812AU ([L2849-L2851](https://github.com/microsoft/WSL2-Linux-Kernel/blob/linux-msft-wsl-6.18.64.1/arch/x86/configs/config-wsl#L2849-L2851)) und USB/IP ([L5036-L5037](https://github.com/microsoft/WSL2-Linux-Kernel/blob/linux-msft-wsl-6.18.64.1/arch/x86/configs/config-wsl#L5036-L5037)). Ralink- und Atheros-Treiber fehlen. RFKILL ist aus ([L1935](https://github.com/microsoft/WSL2-Linux-Kernel/blob/linux-msft-wsl-6.18.64.1/arch/x86/configs/config-wsl#L1935)).
- Vanilla beschreibt WSL2 mit usbipd und eigenem Kernel, aber für die Client-Richtung. Firmware muss man eventuell in den Kernel einbauen ([Vanilla-Wiki WSL2](https://github.com/vanilla-wiiu/vanilla/wiki/Windows-%E2%80%90-WSL2)).
- Im Modus „mirrored networking“ erreichen sich Windows und WSL über `127.0.0.1` ([networking.md L54, L130](https://github.com/MicrosoftDocs/WSL/blob/main/WSL/networking.md?plain=1#L54-L130)). Die Hyper-V-Firewall kann eingehende Verbindungen blockieren ([networking.md L136](https://github.com/MicrosoftDocs/WSL/blob/main/WSL/networking.md?plain=1#L136)).

Schluss:

- Für den libdrc-Weg mit sysfs-TSF braucht man trotzdem einen eigenen Kernel mit mac80211-Patch. Der Monitor-Weg von Barista käme ohne Patch aus, wenn der Treiber AP und Monitor gleichzeitig kann.
- Einen Bericht über hostapd im AP-Modus über usbipd haben wir nicht gefunden. Das ist offen.
- USB/IP legt jede USB-Übertragung über das virtuelle Netz. TSF-Lesen über USB-Register wird damit ungenauer.
- Im mirrored mode sieht Linux auch das Heimnetz. Nutzt das Heimnetz 192.168.1.0/24, kollidiert es mit dem GamePad-Netz.
- Die Brücke liefe auf dem Host mit. Das widerspricht nicht der Isolation, kostet aber CPU und macht WSL zu einer weiteren Fehlerquelle.

### Raspberry Pi und Mini-PC

- **Raspberry Pi 5**: kein Hardware-Encoder für H.264, nur Software-Encoder mit höherer Latenz ([rpicam-vid.adoc L94](https://github.com/raspberrypi/documentation/blob/master/documentation/asciidoc/accessories/camera/rpicam-vid.adoc?plain=1#L94)). (belegt) Für das GamePad kodieren wir ohnehin in Software. (Schluss) Der eingebaute WLAN-Chip CYW43455 ist unbrauchbar, ein USB-Dongle ist Pflicht ([Vanilla-Wiki](https://github.com/vanilla-wiiu/vanilla/wiki/Wireless-Compatibility)). (belegt)
- **Raspberry Pi 4**: Software-H.264 kam auf etwa 2 Bilder pro Sekunde ([libdrc-streaming L52-L53](https://github.com/ywh233/libdrc-streaming/blob/master/README.md?plain=1#L52-L53)). (belegt) Das war mit dem langsamen libdrc-Preset. Für uns zu knapp. (Schluss)
- **x86-Mini-PC**: Barista gibt es fertig paketiert für Ubuntu 24.04, Fedora 44 und Arch auf x86_64 ([README L32-L33](https://github.com/BetaZay/Barista/blob/main/README.md?plain=1#L32-L33)). (belegt) Ein aktueller Mini-PC schafft Barista-Encoder (4,5 ms pro Bild auf Ryzen 5 7600) und das Dekodieren des Apollo-Streams locker. (Schluss)
- Auf echtem Linux ist ein Kernel-Patch oder ein Zusatzmodul per DKMS einfach. (Schluss)

| Kriterium | WSL2 auf dem Host | x86-Mini-PC mit Linux | Raspberry Pi 5 |
| --- | --- | --- | --- |
| Zusatzgerät | keins | ja | ja |
| Treiber und Kernel | Module im Standardkernel, für sysfs-TSF eigener Kernel | frei, DKMS | frei, oft Eigenbau |
| AP-Modus mit GamePad | nicht belegt | belegt (Barista, rtw88_TSF) | nicht belegt |
| TSF-Genauigkeit | USB/IP dazwischen (Schluss) | direkt | direkt |
| Rechenleistung | reichlich | reicht (Schluss) | knapp (Schluss) |
| Barista-Pakete | nur theoretisch | ja | nein, selbst bauen |
| Last auf dem Host | ja | nein | nein |

### Empfehlung Plattform

Alles hier ist Schluss.

1. **Toffee (Spike A)** braucht keine Linux-Plattform. Damit anfangen.
2. **Spike B** zuerst mit einem Ubuntu-24.04-Live-USB am Host. So prüfen wir den Dongle mit echtem Kernel und Baristas Paket. Das trennt „Dongle geht“ von „WSL geht“.
3. Danach **WSL2** mit demselben Dongle. Kein Zusatzgerät nötig.
4. Scheitert WSL2, wird ein **x86-Mini-PC mit Ubuntu 24.04** die feste Brücke. Ein Pi 5 nur, wenn Platz oder Strom wichtiger sind als Reserven.

## Offene Fragen

Diese Punkte klärt nur ein Hardware-Spike:

1. **Toffee im Alltag**: Koppelt das ESP32-C5-Zero stabil? Wie hoch ist die Latenz? Stimmen die DSU-Achsen in Lichii? Kann Toffee die Spielanzeige auf einer virtuellen Anzeige abgreifen? Toffee bringt dafür einen eigenen Treiber mit ([virtual_display.cpp L16](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/src/display/virtual_display.cpp#L16)). Den Ton nimmt Toffee vom Standard-Ausgabegerät ([audio_capture.cpp L81-L87](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/src/audio/audio_capture.cpp#L81-L87)). Wie trennen wir dann den Spielton?
2. **WSL2**: Läuft hostapd im AP-Modus über usbipd? Kommt ein brauchbarer TSF an? Bleiben die Keyframe-Anfragen bei null?
3. **Dauerbetrieb**: Hält die Verbindung über Stunden? Wie sieht ein Switch-Spiel mit festem QP 32 aus? rtw88_TSF meldet Blockartefakte ([L137-L140](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md?plain=1#L137-L140)). Wie weit reicht der Funk?
4. **MT7921AU**: Klappen AP-Modus und `get_tsf` mit dem GamePad?
5. **Gesamtlatenz im Linux-Weg**: Apollo kodiert, die Brücke dekodiert und kodiert neu. Reicht das zum Spielen?
6. **Kopplung mit der Wii U**: Bleibt sie erhalten, oder muss man für Plan B neu koppeln?
7. **Kanalwahl**: Stört das Heim-WLAN auf Kanal 36 bis 48?
8. **wup-stream**: Kommt das GamePad stabil ins Heim-WLAN? Mehrere offene Issues melden Probleme ([#1](https://github.com/ravensclawx/wup-homebrew/issues/1), [#4](https://github.com/ravensclawx/wup-homebrew/issues/4), [#10](https://github.com/ravensclawx/wup-homebrew/issues/10), [#20](https://github.com/ravensclawx/wup-homebrew/issues/20)).

## Folgen für andere Dokumente

Umgesetzt in [ADR 0005](../docs/adr/0005-direktmodus-als-ziel.md): Glossar (die Brücke ist kein reines Linux‑System mehr), Roadmap, Architektur, verwandte Projekte und dieses Verzeichnis.

## Quellen

Protokoll und Kopplung:

- libdrc-Doku (Spiegel opencma/libdrc): [wifi.rst](https://github.com/opencma/libdrc/blob/master/web/docs/re/wifi.rst), [network.rst](https://github.com/opencma/libdrc/blob/master/web/docs/network.rst), [sc-vstrm.rst](https://github.com/opencma/libdrc/blob/master/web/docs/re/sc-vstrm.rst), [sc-astrm.rst](https://github.com/opencma/libdrc/blob/master/web/docs/re/sc-astrm.rst), [sc-input.rst](https://github.com/opencma/libdrc/blob/master/web/docs/re/sc-input.rst), [sc-cmd.rst](https://github.com/opencma/libdrc/blob/master/web/docs/re/sc-cmd.rst), [services.rst](https://github.com/opencma/libdrc/blob/master/web/docs/re/services.rst)
- libdrc-Code: [h264-encoder.cpp](https://github.com/opencma/libdrc/blob/master/src/h264-encoder.cpp), [video-streamer.cpp](https://github.com/opencma/libdrc/blob/master/src/video-streamer.cpp), [audio-streamer.cpp](https://github.com/opencma/libdrc/blob/master/src/audio-streamer.cpp), [tsf-linux.cpp](https://github.com/opencma/libdrc/blob/master/src/tsf-linux.cpp)
- memahaxx auf Bitbucket: [libdrc](https://bitbucket.org/memahaxx/libdrc), [drc-hostap](https://bitbucket.org/memahaxx/drc-hostap), [drc-x264](https://bitbucket.org/memahaxx/drc-x264), [drc-mac80211](https://bitbucket.org/memahaxx/drc-mac80211)
- [Nintendo-Hilfe: GamePad mit der Konsole koppeln](https://en-americas-support.nintendo.com/app/answers/detail/a_id/1131/~/how-to-sync-a-wii-u-gamepad-with-a-wii-u-console)

Projekte:

- Barista: [README](https://github.com/BetaZay/Barista/blob/main/README.md), [docs/hardware.md](https://github.com/BetaZay/Barista/blob/main/docs/hardware.md), [docs/user-guide.md](https://github.com/BetaZay/Barista/blob/main/docs/user-guide.md), [core/drh/pairing.cpp](https://github.com/BetaZay/Barista/blob/main/core/drh/pairing.cpp), [core/drh/server/backend_linux.cpp](https://github.com/BetaZay/Barista/blob/main/core/drh/server/backend_linux.cpp), [VALIDATION.md](https://github.com/BetaZay/Barista/blob/main/core/drh/encoder/x264/VALIDATION.md), [COMPILING.md](https://github.com/BetaZay/Barista/blob/main/COMPILING.md)
- rtw88_TSF: [WIIU_GAMEPAD.md](https://github.com/wozt/rtw88_TSF/blob/master/WIIU_GAMEPAD.md), [README](https://github.com/wozt/rtw88_TSF/blob/master/README.md)
- Toffee: [README](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/README.md), [docs/setup.md](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/docs/setup.md), [docs/framework.md](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/docs/framework.md), [docs/architecture.md](https://github.com/Gavwalsh15/toffee_wiiu/blob/master/docs/architecture.md), [Firmware-Quellen](https://github.com/Gavwalsh15/toffee_wiiu/tree/master/firmware/src)
- wup-homebrew: [README](https://github.com/ravensclawx/wup-homebrew/blob/main/README.md); wup-stream: [README](https://github.com/ravensclawx/wup-stream/blob/main/README.md)
- WiiU-GP-RE: [DISPLAY-WORKS.md](https://github.com/DTRHnet/WiiU-GP-RE/blob/main/WiiU-tk/00-docs/research/DISPLAY-WORKS.md), [ENCODER-VERDICT.md](https://github.com/DTRHnet/WiiU-GP-RE/blob/main/WiiU-tk/00-docs/research/ENCODER-VERDICT.md)
- [pc2drc](https://github.com/thefloppydriver/pc2drc), [Vanilla](https://github.com/vanilla-wiiu/vanilla), [vanilla-wiiu/drc-hostap](https://github.com/vanilla-wiiu/drc-hostap), [opencma/drc-sim](https://github.com/opencma/drc-sim), [opencma/drc-sim-c](https://github.com/opencma/drc-sim-c), [ZiiUScreen](https://github.com/pancreations/ZiiUScreen), [libdrc-streaming](https://github.com/ywh233/libdrc-streaming), [minih264](https://github.com/lieff/minih264)

Hardware und Kernel:

- Linux-Kernel (Commit 4dce97c): [rt2800usb.c](https://github.com/torvalds/linux/blob/4dce97c6c265544342e716e62fd24bbb232590c5/drivers/net/wireless/ralink/rt2x00/rt2800usb.c#L655), [mt7921/main.c](https://github.com/torvalds/linux/blob/4dce97c6c265544342e716e62fd24bbb232590c5/drivers/net/wireless/mediatek/mt76/mt7921/main.c#L1574), [mt792x_core.c](https://github.com/torvalds/linux/blob/4dce97c6c265544342e716e62fd24bbb232590c5/drivers/net/wireless/mediatek/mt76/mt792x_core.c#L331), [ath9k htc_drv_main.c](https://github.com/torvalds/linux/blob/4dce97c6c265544342e716e62fd24bbb232590c5/drivers/net/wireless/ath/ath9k/htc_drv_main.c#L1893)
- morrownr: [USB-WiFi-Chipsätze](https://github.com/morrownr/USB-WiFi/blob/main/home/USB_WiFi_Chipsets.md), [Adapter mit In-Kernel-Treiber](https://github.com/morrownr/USB-WiFi/blob/main/home/USB_WiFi_Adapters_that_are_supported_with_Linux_in-kernel_drivers.md)
- Vanilla-Wiki: [Wireless Compatibility](https://github.com/vanilla-wiiu/vanilla/wiki/Wireless-Compatibility), [Single-Board Computers](https://github.com/vanilla-wiiu/vanilla/wiki/Single%E2%80%90Board-Computers), [Windows WSL2](https://github.com/vanilla-wiiu/vanilla/wiki/Windows-%E2%80%90-WSL2)
- [Raspberry Pi: rpicam-vid](https://github.com/raspberrypi/documentation/blob/master/documentation/asciidoc/accessories/camera/rpicam-vid.adoc)

WSL2:

- Microsoft: [USB-Geräte verbinden](https://learn.microsoft.com/en-us/windows/wsl/connect-usb), [wsl-config](https://learn.microsoft.com/en-us/windows/wsl/wsl-config), [Netzwerk](https://learn.microsoft.com/en-us/windows/wsl/networking)
- [WSL-Kernel-Konfiguration 6.18.64.1](https://github.com/microsoft/WSL2-Linux-Kernel/blob/linux-msft-wsl-6.18.64.1/arch/x86/configs/config-wsl), [usbipd-win Wiki](https://github.com/dorssel/usbipd-win/wiki/WSL-support)

Lizenz:

- [GNU GPL Version 2](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html)
