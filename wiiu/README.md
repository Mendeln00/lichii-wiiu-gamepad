# Wii-U-Client (Plan B)

Dieser Ordner gehört zum **Relay**, dem Plan B des Projekts. Er ruht, solange der Direktmodus vorankommt, siehe [ADR 0005](../docs/adr/0005-direktmodus-als-ziel.md).

Wird der Plan B gebraucht, entsteht hier ein Fork von [moonlight-wiiu](https://github.com/GaryOderNichts/moonlight-wiiu) (GPL-3.0) als Git-Submodule. Er bekommt:

- einen eingebauten DSU-Server für Tasten, Sticks, Gyro und Touch, siehe [ADR 0003](../docs/adr/0003-eingabe-ueber-dsu.md)
- eine abschaltbare Moonlight-Eingabe
- eine Touch-Skalierung passend zu Lichiis `touch_device`

Die Tickets liegen im Milestone „Plan B: Wii U als Relay“. Als Notlösung läuft schon heute das unveränderte moonlight-wiiu auf der Konsole, mit Tasten über den virtuellen Xbox-Controller.
