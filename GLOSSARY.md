# Glossar

Gemeinsame Sprache dieses Projekts: Lichii auf dem Wii U GamePad spielen, während der PC frei bleibt. Code, Issues und Doku verwenden diese Begriffe.

## Geräte

**GamePad**:
Der Wii‑U‑Controller mit eigenem Bildschirm, Tasten, Sticks, Gyro und Touch.
_Avoid_: Tablet, Controller, DRC (nur im Protokoll‑Code)

**Host**:
Der Windows‑PC, auf dem Lichii und Apollo laufen.
_Avoid_: Server

**Brücke**:
Das Gerät mit Software, das sich dem GamePad gegenüber als Konsole ausgibt.
_Avoid_: Bridge, Relay, Dongle

**Konsole**:
Die Wii U selbst. Sie wird nur im Relay gebraucht.
_Avoid_: WiiU‑Box

**Client**:
Die Gegenstelle von Apollo, die den Stream empfängt: im Direktmodus die Brücke, im Relay die Wii‑U‑App.
_Avoid_: Homebrew

## Betriebsarten

**Direktmodus**:
Die Brücke spricht direkt mit dem GamePad, ganz ohne Konsole. Das ist das Ziel des Projekts.
_Avoid_: Standalone

**Relay**:
Plan B: Die Konsole empfängt den Stream vom Host und gibt ihn an das GamePad weiter.
_Avoid_: Proxy

**Kopplung**:
Das einmalige Bekanntmachen von GamePad und Brücke (oder Konsole). Danach verbindet sich das GamePad von selbst.
_Avoid_: Sync, Pairing ohne Zusatz

**Moonlight‑Pairing**:
Das einmalige Vertrauen zwischen Client und Apollo per PIN.
_Avoid_: Kopplung

## Kanäle

**Stream**:
Bild und Ton vom Host zum Client.

**Spielanzeige**:
Die virtuelle Anzeige auf dem Host, auf der nur Lichii läuft und die gestreamt wird.
_Avoid_: Zweiter Monitor

**Spielton**:
Nur Lichiis Ton, getrennt vom übrigen Ton des Hosts.

**Eingabekanal**:
Der Weg der Eingaben vom GamePad zu Lichii.

**DSU**:
Das Cemuhook‑Protokoll, über das Lichii Tasten, Sticks, Gyro und Touch abfragt. Der Client ist DSU‑Server, Lichii ist DSU‑Client.
_Avoid_: UDP‑Controller (nur der Name in Lichiis Oberfläche)

**Isolation**:
Lichii bekommt Bild, Ton und Eingabe über eigene Kanäle. Maus, Tastatur, Hauptbildschirm und Ton des Hosts bleiben unberührt.
_Avoid_: Headless

**Spielprofil**:
Ein App‑Eintrag in Apollo, der Lichii mit einem bestimmten Spiel startet.

**Eingabeprofil**:
Eine gespeicherte Tastenbelegung in Lichii (`config/input/<Name>.ini`). Das Host‑Modul legt `WiiU GamePad` an: das DSU‑Pad der Brücke als Pro Controller für Spieler 1.
_Avoid_: Spielprofil (das ist Apollo), Controller‑Profil
