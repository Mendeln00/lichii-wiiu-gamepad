# Recherche

Notizen und Spikes, die (noch) nicht in Code münden. Jede Datei nennt ihre Quellen. Neue Recherchen entstehen mit `/research`.

- `direct-mode.md`: Direktmodus ohne Konsole. Kopplung, Protokoll, Projekte und Lizenzen, Hardware, Plattform (Meilensteine M2 bis M4)
- `audio-isolation.md`: Spielton isolieren. Wie Apollo, Toffee und Lichii Geräte wählen und aufnehmen, Wege unter Windows, stilles Gerät und offene Treiber dafür, nötige Upstream-PRs (Issues #15, #43)
- `tools/`: Messwerkzeuge für Prüfungen am PC
  - `Measure-ProcessLoopback.ps1`: nimmt einen Prozess per Prozess-Loopback auf und misst den Pegel, während er im Lautstärkemixer stumm und leise ist (Issue #15)
  - `Measure-DeviceLoopback.ps1`: nimmt ein Wiedergabegerät per Geräte-Loopback auf, wie die Brücke, und zeigt das Standardgerät vorher und nachher (Issue #44)
  - `LoopbackProbe.cs`: Core-Audio-Code, den beide Skripte laden
  - `Start-DsuTestServer.ps1`: spielt den DSU-Server der Brücke nach (Cemuhook 1001, UDP `127.0.0.1:26760`) und sendet für Slot 0 Tasten, Sticks, Gyro, Beschleunigung und Touch aus einem Ablaufskript oder von der Tastatur. Damit lassen sich das Eingabeprofil und `eden-cli` ohne Brücke und GamePad prüfen. `-SelfTest` fragt den Server wie Lichii ab und prüft jede Antwort (Issue #60)
  - `DsuProbe.cs`: Protokoll, Server und Prüf-Client, die `Start-DsuTestServer.ps1` lädt
  - `DsuTour.txt`: Standardablauf, ein Rundgang durch alle Eingaben mit der Switch-Taste, die Lichii daraus macht
