# 0003: Eingabekanal über DSU (Cemuhook), ViGEm nur als Rückfall

- Status: angenommen
- Datum: 2026-11-25

## Kontext

moonlight‑wiiu schickt GamePad‑Tasten über das Moonlight‑Protokoll an Apollo. Apollo legt daraus einen virtuellen Xbox‑360‑Controller an (ViGEmBus). Dabei gehen **Gyro** und **Touch** verloren: Touch wird zu Maus oder Windows‑Touch und wirkt global auf dem Host. Lichii (yuzu‑Erbe) hat einen DSU‑Client (`src/input_common/drivers/udp_client.cpp`). Er kennt 16 Tasten, Home, zwei Sticks, Gyro/Beschleunigung und zwei Touch‑Punkte und läuft unabhängig vom Fensterfokus.

## Entscheidung

Der Client bekommt einen eingebauten **DSU‑Server**. Lichii verbindet sich per `udp_input_servers=<Konsole‑IP>:26760`. Die Moonlight‑Eingabe lässt sich im Client abschalten. Der virtuelle Xbox‑Controller bleibt als Rückfall (M1), bis DSU fertig ist.

## Folgen

- Eingaben erreichen **nur** Lichii. Der Host bekommt keine globalen Maus‑ oder Touch‑Ereignisse (Isolation).
- Gyro wird zur Switch‑Bewegungssteuerung, der GamePad‑Touch zum Switch‑Touchscreen.
- Lichii muss einmalig „UDP‑Controller“ aktivieren. Das übernimmt das Host‑Modul.
- Touch‑Kalibrierung: Der DSU‑Client erwartet Rohwerte im Bereich `min_x..max_x`. Der Client sendet 854×480‑skalierte Werte, und das Host‑Modul setzt `touch_device` passend.
