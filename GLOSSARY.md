# Glossar

Gemeinsame Sprache für dieses Projekt. Code, Issues und Doku verwenden diese Begriffe.

| Begriff | Bedeutung | Nicht verwenden |
| --- | --- | --- |
| **GamePad** | Der Wii‑U‑Controller mit Bildschirm (intern „DRC“). | Tablet, Controller (mehrdeutig) |
| **Konsole** | Die Wii U selbst. Sie läuft mit Aroma und dient als **Relay**. | WiiU‑Box |
| **Host** | Der Windows‑PC, auf dem Lichii und Apollo laufen. | Server (mehrdeutig, siehe DSU) |
| **Relay** | Betriebsart, in der die Konsole den Stream vom Host empfängt und ans GamePad weitergibt. Standard‑Betriebsart. | Proxy |
| **Direktmodus** | Spätere Betriebsart ohne Konsole: Der Host spricht über einen WLAN‑Dongle direkt mit dem GamePad (libdrc‑Weg). | — |
| **Client** | Unsere Wii‑U‑App (Fork von moonlight‑wiiu). Sie zeigt den Stream an und liest das GamePad aus. | Homebrew (zu allgemein) |
| **Stream** | Bild (H.264) und Ton (Opus) vom Host zum Client über das Moonlight‑Protokoll. | — |
| **Spielanzeige** | Das virtuelle Display (SudoVDA), auf dem nur Lichii läuft. Es wird gestreamt. | Zweiter Monitor |
| **Spielton** | Der Audio‑Pfad, der nur Lichiis Ton zum Stream führt. | — |
| **Eingabekanal** | Der Weg vom GamePad zu Lichii. Bevorzugt **DSU**, als Rückfall ein virtueller Xbox‑Controller (ViGEm). | — |
| **DSU** | Cemuhook‑UDP‑Protokoll (Port 26760). Der Client ist DSU‑**Server**, Lichii ist DSU‑**Client**. | UDP‑Controller (nur in Lichii‑UI) |
| **Isolation** | Lichii bekommt Bild, Ton und Eingabe über eigene Kanäle. Maus, Tastatur, Hauptbildschirm und Ton des Hosts bleiben unberührt. | Headless |
| **Spielprofil** | Ein App‑Eintrag in Apollo, der Lichii mit einem bestimmten Spiel startet. | — |
