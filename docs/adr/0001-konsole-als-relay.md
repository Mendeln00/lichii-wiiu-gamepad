# 0001: Konsole als Relay statt Direktmodus als Standard

- Status: abgelöst durch [ADR 0005](0005-direktmodus-als-ziel.md)
- Datum: 2026-11-25

## Kontext

Das GamePad spricht ein eigenes WLAN‑Protokoll (802.11n 5 GHz, WPS‑Pairing, H.264 mit eigenen Headern, TSF‑genaues Timing). Ohne Konsole braucht man den **Direktmodus**: libdrc/drc‑sim bzw. pc2drc. Das läuft nur unter Linux, verlangt einen gepatchten Kernel (TSF‑Export) und ein passendes WLAN‑Chipset (RT5572/rt2800usb). Zum Pairing braucht man trotzdem einmal eine Konsole. pc2drc ist seit April 2026 archiviert und hat bekannte Bildfehler und Abbrüche.

Mit Aroma kann die Konsole dagegen Homebrew ausführen, H.264 in Hardware dekodieren und das GamePad über das System‑SDK nutzen. moonlight‑wiiu zeigt, dass das stabil funktioniert.

## Entscheidung

Standard ist der **Relay**‑Betrieb: Der Host streamt zur Konsole, die Konsole bedient das GamePad. Der **Direktmodus** bleibt ein eigener Forschungs‑Meilenstein (M5) und blockiert nichts anderes.

## Folgen

- Schnell lauffähig, kein Kernel‑Patch, funktioniert unter Windows.
- Die Konsole muss laufen, ein LAN‑Adapter ist empfohlen.
- Der Direktmodus kann später ein zweites Backend für denselben Client‑Vertrag werden: Bild, Ton und Eingabe bleiben gleich.
