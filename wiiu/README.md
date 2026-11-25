# Wii-U-Client

Hier entsteht der Client für die Konsole, als Fork von [moonlight-wiiu](https://github.com/GaryOderNichts/moonlight-wiiu) (GPL-3.0). Er wird als Git-Submodule eingebunden. Details stehen in Meilenstein M2 der [Roadmap](../docs/roadmap.md).

Geplant sind:

- ein eingebauter DSU-Server (Port 26760) für Tasten, Sticks, Gyro und Touch, siehe [ADR 0003](../docs/adr/0003-eingabe-ueber-dsu.md)
- eine abschaltbare Moonlight-Eingabe
- eine Touch-Skalierung passend zu Lichiis `touch_device`

Bis dahin funktioniert das unveränderte moonlight-wiiu (Meilenstein M1).
