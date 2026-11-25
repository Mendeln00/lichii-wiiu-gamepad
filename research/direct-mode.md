# Direktmodus: GamePad ohne Konsole

Stand: 2026-11-25. Ziel ist Meilenstein M5.

## Was nötig ist

- **WLAN**: 802.11n auf 5 GHz, AP-Modus und WPS-PIN-Pairing mit dem GamePad. Das GamePad erwartet einen Access Point mit einem speziell abgeleiteten PSK.
- **Timing**: Das GamePad braucht TSF-synchrone Frames. libdrc liest den TSF über einen gepatchten Kernel (`get_tsf` → sysfs).
- **Chipsets**: bekannt gut sind RT5572 (rt2800usb). Untersucht werden sollen mt76-Adapter, deren Treiber `get_tsf` können.
- **Pairing**: Einmalig mit einer echten Konsole oder über das bei pc2drc beschriebene Verfahren. Ohne Konsole ist es laut pc2drc „NOT EASY“.

## Optionen auf dem Host

| Option | Pro | Contra |
| --- | --- | --- |
| Raspberry Pi 4/5 oder Mini-PC mit Linux als Bridge | Echter Kernel-Patch möglich, USB-Dongle direkt | Encoding auf dem Pi zu langsam, daher H.264 auf dem PC kodieren und nur weiterreichen |
| WSL2 + usbipd + eigener Kernel | Kein zusätzliches Gerät | WLAN-USB unter WSL2 ist experimentell, Timing ist fraglich |
| Windows-Treiber | — | Kein AP-Modus mit TSF-Zugriff realistisch |

## Ausgangsbasis

- [thefloppydriver/pc2drc](https://github.com/thefloppydriver/pc2drc) (GPL-2.0, archiviert, „Please fork“)
- [rolandoislas/libdrc](https://github.com/rolandoislas/libdrc), memahaxx/libdrc, [rodolforg/drc-sim](https://github.com/rodolforg/drc-sim)
- Vanilla Wii U: umgekehrte Richtung, aber gute Pairing- und Protokoll-Doku

## Offene Fragen (Tickets in M5)

1. Welche aktuellen Dongles (mt76) liefern TSF ohne Kernel-Patch?
2. Lässt sich der Bild-Teil des Client-Vertrags (H.264-Stream) unverändert an libdrc übergeben?
3. Pairing ohne Konsole: Ist die WPS-PIN aus dem GamePad-Display ausreichend?
