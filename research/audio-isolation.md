# Spielton isolieren: Recherche zu Issue #15

Stand: 2026-11-26. Betrifft [Issue #15](https://github.com/Mendeln00/lichii-wiiu-gamepad/issues/15), den Ton-Teil von [Issue #31](https://github.com/Mendeln00/lichii-wiiu-gamepad/issues/31) und [ADR 0004](../docs/adr/0004-isolation-durch-eigene-kanaele.md).

Kennzeichnung: **(belegt)** heißt, die verlinkte Primärquelle sagt das so. **(Schluss)** heißt, das ist unsere Ableitung aus den Quellen. Sie ist nicht getestet.

Geprüfte Stände: Apollo `master` [adc5c5a](https://github.com/ClassicOldSong/Apollo/tree/adc5c5a0bd80831ce495434bb16aee2cd4175fb8) vom 2026-05-21, Sunshine `master` [b7a0b68](https://github.com/LizardByte/Sunshine/tree/b7a0b68613f9fce5fcb206a75e00f092a638b8b7) vom 2026-11-25, Toffee `master` [85051f0](https://github.com/Gavwalsh15/toffee_wiiu/tree/85051f02a4537d860052f5e1985efebd688eac13) vom 2026-11-16, Lichii `nx2` [7cc8a77](https://github.com/zortos293/Lichii/tree/7cc8a7750c0b98ce87917236d35e57e2f23cc811) vom 2026-11-25. Alle Code-Links zeigen auf diese Stände.

## Ergebnis

- **Die Ton-Annahme in ADR 0004 stimmt nicht.** Apollo nimmt unter Windows immer per Loopback vom Standardgerät auf ([windows/audio.cpp L338-L354, L481](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/platform/windows/audio.cpp#L338-L354)). Ist `audio_sink` gesetzt und erlaubt der Client Ton auf dem Host, macht Apollo `audio_sink` beim Start der Sitzung zum Windows-Standardgerät, für alle Rollen ([audio.cpp L160-L196](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/audio.cpp#L160-L196), [windows/audio.cpp L853-L881](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/platform/windows/audio.cpp#L853-L881)). (belegt)
- **Mit Apollo allein geht die Isolation nicht.** Keine Kombination aus `audio_sink`, `virtual_sink` und dem Host-Ton-Flag des Clients nimmt nur ein Gerät auf, ohne das Standardgerät umzustellen. Entweder stellt Apollo um, oder es nimmt den ganzen Ton des Hosts auf. (Schluss aus dem Code, Tabelle in Abschnitt 1)
- **Sunshine upstream kann es inzwischen.** Seit [PR #5408](https://github.com/LizardByte/Sunshine/pull/5408) nimmt Sunshine das eingestellte Gerät direkt auf. Seit [PR #5647](https://github.com/LizardByte/Sunshine/pull/5647) lässt `external_audio = enabled` das Standardgerät ganz in Ruhe ([configuration.md L942-L974](https://github.com/LizardByte/Sunshine/blob/b7a0b68613f9fce5fcb206a75e00f092a638b8b7/docs/configuration.md?plain=1#L942-L974)). Das steckt nur in Vorabversionen ab v2026.1122. Apollo hat Sunshine zuletzt am 2025-09-26 eingemischt ([Merge-Commit](https://github.com/ClassicOldSong/Apollo/commit/10fd290b813f545e26f403376eae3d98bc072ecb)). (belegt)
- **Toffee nimmt nur das Standardgerät auf** (`eRender`, `eConsole`, Loopback) und bietet keine Geräteauswahl ([audio_capture.cpp L77-L90](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/src/audio/audio_capture.cpp#L77-L90), [framework.md L39](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/docs/framework.md?plain=1#L39)). (belegt) Für die Isolation braucht Toffee eine kleine Änderung. (Schluss)
- **Lichii wählt sein Ausgabegerät per Anzeigename**: Abschnitt `[Audio]`, Schlüssel `output_device` mit `output_device\default=false` in `qt-config.ini`. Passt der Name zu keinem Gerät, spielt Lichii ohne Meldung auf dem Standardgerät. (belegt, Abschnitt 3)
- **Windows kann es, ohne das Standardgerät zu ändern.** Loopback geht auf jedem Wiedergabegerät, nicht nur auf dem Standardgerät ([Loopback Recording L11-L14](https://github.com/MicrosoftDocs/win32/blob/bc82a65f74ef2c4f2f44a3d7db5f7cfebfdc3583/desktop-src/CoreAudio/loopback-recording.md?plain=1#L11-L14)). Prozess-Loopback ab Windows 10 Build 20348 nimmt nur einen Prozessbaum auf, egal auf welchem Gerät er spielt ([ApplicationLoopback README L23-L27, L41](https://github.com/microsoft/Windows-classic-samples/blob/434f6002bdf9cf9829406c3ff2b33387982d6168/Samples/ApplicationLoopback/README.md?plain=1#L23-L41)). (belegt)
- **Stummschalten im Lautstärkemixer gilt auch für den Prozess-Loopback.** Am PC des Maintainers am 2026-11-26 mit einem Testton gemessen: Ist der Prozess stumm, kommt nur noch Rundungsrauschen an (−90 dBFS Spitze), und 10 % Lautstärke senken den Pegel um 20 dB. Prozess-Loopback ersetzt das stille Gerät also nicht. Lichii braucht weiter ein eigenes Gerät, das am PC nicht zu hören ist. (belegt am PC, Abschnitt 4 c) Die Bestätigung mit Lichii selbst steht noch aus.
- **Offene Alternative zu VB-CABLE:** [Virtual-Audio-Driver](https://github.com/VirtualDrivers/Virtual-Audio-Driver) steht unter MIT-Lizenz und dürfte mitgeliefert werden, ist aber noch Beta. VB-CABLE dürfen wir nicht mitliefern. (belegt, Abschnitt 4 e)

Empfehlung (Schluss):

1. **Lichii auf ein eigenes Gerät stellen**, etwa VB-CABLE „CABLE Input“. Reine Konfiguration, gilt für beide Wege. Offene Treiber haben Vorrang, sobald einer stabil genug ist (Abschnitt 4 e).
2. **Toffee-Weg**: Feature Request und PR an Toffee für eine Option `--audio-device`. Sie nimmt ein Wiedergabegerät nach ID oder Name per Loopback auf. Später optional Prozess-Loopback für das gestreamte Fenster.
3. **Apollo-Weg**: PR an Apollo, der Sunshine #5408 und #5647 nachzieht. Bis dahin hat der Apollo-Weg keine Ton-Isolation. Den Namen des Schalters vorher abstimmen, denn der offene [PR #5935](https://github.com/LizardByte/Sunshine/pull/5935) will `external_audio` in `keep_default_sink` umbenennen.
4. **ADR 0004 korrigieren.** Der Satz „Der Client fordert ‚Ton auf Host behalten‘ an, damit Apollo das Standardgerät nicht umstellt“ ist falsch.

## 1. Apollo

### Wie Apollo aufnimmt

- WASAPI im geteilten Modus mit `AUDCLNT_STREAMFLAGS_LOOPBACK` ([windows/audio.cpp L318-L326](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/platform/windows/audio.cpp#L318-L326)). (belegt)
- Das Gerät ist immer `GetDefaultAudioEndpoint(eRender, eConsole)` ([L338-L354](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/platform/windows/audio.cpp#L338-L354), Aufruf in [L481](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/platform/windows/audio.cpp#L481)). Einen anderen Weg, ein Gerät zur Aufnahme zu öffnen, hat die Datei nicht. Prozess-Loopback (`ActivateAudioInterfaceAsync`) kommt nicht vor. (belegt)
- Wechselt das Standardgerät, meldet die Aufnahme `reinit` ([L585-L594](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/platform/windows/audio.cpp#L585-L594)). Mit `auto_capture_sink` öffnet Apollo dann das neue Standardgerät ([audio.cpp L232-L243](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/audio.cpp#L232-L243)). (belegt)
- Apollo v0.4.6 (letzte Version, 2025-07-13) verhält sich gleich. `audio.cpp` ist identisch, `windows/audio.cpp` unterscheidet sich nur in der Schreibweise. (Schluss aus dem Diff der Dateien)

### Welches Gerät Apollo wählt

Ablauf beim Start einer Sitzung ([audio.cpp L160-L196](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/audio.cpp#L160-L196)) (belegt):

1. Ausgangspunkt ist das Standardgerät. Apollo merkt sich dessen ID beim Start der Audio-Steuerung ([windows/audio.cpp L690-L701](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/platform/windows/audio.cpp#L690-L701), [audio.cpp L284-L309](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/audio.cpp#L284-L309)).
2. Ist `audio_sink` gesetzt, gilt `audio_sink`.
3. Gibt es einen virtuellen Sink und erlaubt der Client keinen Ton auf dem Host, gilt der virtuelle Sink. Das gilt auch, wenn bis hier kein Gerät feststeht.
4. Weicht die Wahl vom Standardgerät ab, setzt Apollo sie per `IPolicyConfig::SetDefaultEndpoint` als Standard, in einer Schleife über alle Rollen ([windows/audio.cpp L853-L881](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/platform/windows/audio.cpp#L853-L881)). Apollo nennt diese Schnittstelle selbst „completely undocumented“ ([L832-L833](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/platform/windows/audio.cpp#L832-L833)).
5. Nur die erste Sitzung darf umstellen ([audio.cpp L187-L188](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/audio.cpp#L187-L188)).
6. Danach nimmt Apollo das (neue) Standardgerät auf ([audio.cpp L199](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/audio.cpp#L199)).

Daraus folgt (Schluss):

| Ton auf Host (Client) | `audio_sink` | virtueller Sink vorhanden | Apollo nimmt auf | Standardgerät |
| --- | --- | --- | --- | --- |
| ja | leer oder gleich dem Standardgerät | egal | Standardgerät, also den ganzen Host-Ton | bleibt |
| ja | anderes Gerät X | egal | X | wird X |
| nein | egal | ja (etwa Steam Streaming Speakers) | virtuellen Sink, also den ganzen Host-Ton, Lautsprecher stumm | wird der virtuelle Sink |
| nein | anderes Gerät X | nein | X | wird X |
| nein | leer | nein | Standardgerät, also den ganzen Host-Ton | bleibt |

Keine Zeile erfüllt ADR 0004. Ein bestimmtes Gerät allein nimmt Apollo nur auf, wenn es Standardgerät ist. (Schluss)

### Optionen

| Option | Standard | Was sie tut | Beleg |
| --- | --- | --- | --- |
| `audio_sink` | leer, dann das Standardgerät | Gerät für „Ton auf Host erlaubt“. Passt auf Geräte-ID, Anzeigename, Gerätebeschreibung oder Adaptername, nur aktive Wiedergabegeräte. Wird zum Standardgerät. Bei gleichen Namen die Geräte-ID nehmen. | [config.cpp L1228](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/config.cpp#L1228-L1233), [windows/audio.cpp L899-L923](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/platform/windows/audio.cpp#L899-L923), [configuration.md L728-L796](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/docs/configuration.md?plain=1#L728-L796), [en.json L180](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src_assets/common/assets/web/public/assets/locale/en.json#L180) |
| `virtual_sink` | leer, dann „Steam Streaming Speakers“ | Gerät für „Ton auf Host nicht erlaubt“. Wird zum Standardgerät, Apollo setzt dazu das Format. | [L703-L727](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/platform/windows/audio.cpp#L703-L727), [L893-L897](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/platform/windows/audio.cpp#L893-L897), [configuration.md L798-L826](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/docs/configuration.md?plain=1#L798-L826), [en.json L455](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src_assets/common/assets/web/public/assets/locale/en.json#L455) |
| `install_steam_audio_drivers` | an | Installiert Steam Streaming Speakers, wenn Steam da ist. Stellt danach das alte Standardgerät wieder her. | [L1067-L1091](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/platform/windows/audio.cpp#L1067-L1091), [L1162-L1177](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/platform/windows/audio.cpp#L1162-L1177) |
| `keep_sink_default` | an | Nur Apollo: Stellt jemand das Standardgerät um, setzt Apollo den virtuellen Sink sofort wieder als Standard. Wirkt nur bei virtuellem Sink. Nicht in `docs/configuration.md`, nur in der Weboberfläche. | [L771-L780](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/platform/windows/audio.cpp#L771-L780), [en.json L311-L312](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src_assets/common/assets/web/public/assets/locale/en.json#L311-L312) |
| `auto_capture_sink` | an | Nur Apollo: nach einem Wechsel des Standardgeräts das neue aufnehmen | [audio.cpp L232-L243](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/audio.cpp#L232-L243), [en.json L183-L184](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src_assets/common/assets/web/public/assets/locale/en.json#L183-L184) |
| `stream_audio` | an | Ton ganz abschalten | [audio.cpp L132-L135](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/audio.cpp#L132-L135) |

Standardwerte: [config.cpp L521-L528](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/config.cpp#L521-L528). (belegt)

### Das Host-Ton-Flag des Clients

- Der Client schickt `localAudioPlayMode` bei `/launch`, neuere Clients auch bei `/resume`. Apollo setzt damit `HOST_AUDIO` ([nvhttp.cpp L1240](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/nvhttp.cpp#L1240), [L1392-L1398](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/nvhttp.cpp#L1392-L1398), [rtsp.cpp L992](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/rtsp.cpp#L992)). (belegt)
- Das Flag entscheidet nur zwischen `audio_sink` und `virtual_sink` ([audio.cpp L169-L170](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/audio.cpp#L169-L170)). Es verhindert das Umstellen nicht. (belegt)
- moonlight-qt sendet es ([nvhttp.cpp L232](https://github.com/moonlight-stream/moonlight-qt/blob/dc99771b1d4310aa8648dbaf374b3a2178e6f935/app/backend/nvhttp.cpp#L232)). Der Schalter heißt umgekehrt „Mute host PC speakers while streaming“ ([SettingsView.qml L939-L943](https://github.com/moonlight-stream/moonlight-qt/blob/dc99771b1d4310aa8648dbaf374b3a2178e6f935/app/gui/SettingsView.qml#L939-L943)). Standard ist kein Host-Ton ([streamingpreferences.cpp L134](https://github.com/moonlight-stream/moonlight-qt/blob/dc99771b1d4310aa8648dbaf374b3a2178e6f935/app/settings/streamingpreferences.cpp#L134)). (belegt)
- moonlight-embedded, der Kandidat für eine Linux-Brücke, nutzt `-localaudio`, Standard aus ([README.pod L119-L121](https://github.com/moonlight-stream/moonlight-embedded/blob/33142e58ebd576085a076f4ce24881d20b3c4ef5/docs/README.pod?plain=1#L119-L121), [client.c L744-L745](https://github.com/moonlight-stream/moonlight-embedded/blob/33142e58ebd576085a076f4ce24881d20b3c4ef5/libgamestream/client.c#L744-L745), [config.c L374](https://github.com/moonlight-stream/moonlight-embedded/blob/33142e58ebd576085a076f4ce24881d20b3c4ef5/src/config.c#L374)). (belegt)
- Apollo gibt das Flag an gestartete Apps als `APOLLO_CLIENT_HOST_AUDIO` weiter ([process.cpp L394](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/process.cpp#L394)). (belegt)

### Zurückstellen

- Endet die letzte Sitzung, setzt Apollo das gemerkte Standardgerät zurück, „best effort“ ([audio.cpp L311-L323](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/audio.cpp#L311-L323)). (belegt)
- Beim Start von Apollo gilt: Sind Steam Streaming Speakers das Standardgerät, wählt Apollo ein anderes ([L987-L1042](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/platform/windows/audio.cpp#L987-L1042), [L1179-L1195](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/platform/windows/audio.cpp#L1179-L1195)). (belegt)
- Steam Streaming Speakers eignen sich deshalb nicht als Lichiis Gerät: Apollo behandelt sie automatisch als virtuellen Sink. VB-CABLE kommt dieser Automatik nicht in die Quere, solange `virtual_sink` leer bleibt. (Schluss)

### Sunshine upstream im Vergleich

| Stand | Verhalten | Beleg |
| --- | --- | --- |
| Apollo `master` und v0.4.6 | wie oben: stellt um, nimmt das Standardgerät auf | siehe oben |
| Sunshine ab v2026.906 (PR #5408) | nimmt `audio_sink` direkt per `GetDevice` auf. Stellt beim Start aber weiter um, „intentionally unchanged“. | [PR #5408](https://github.com/LizardByte/Sunshine/pull/5408), [windows/audio.cpp L963-L991](https://github.com/LizardByte/Sunshine/blob/b7a0b68613f9fce5fcb206a75e00f092a638b8b7/src/platform/windows/audio.cpp#L963-L991) |
| Sunshine-Vorabversion ab v2026.1122 (PR #5647) | `external_audio = enabled`: nimmt `audio_sink` direkt auf, ändert weder Standardgerät noch Format, installiert keinen Steam-Treiber. `virtual_sink` und das Host-Ton-Flag wirken dann nicht. Fehlt das Gerät, gibt es keinen Ton statt eines Rückfalls. | [configuration.md L942-L974](https://github.com/LizardByte/Sunshine/blob/b7a0b68613f9fce5fcb206a75e00f092a638b8b7/docs/configuration.md?plain=1#L942-L974), [windows/audio.cpp L878-L887](https://github.com/LizardByte/Sunshine/blob/b7a0b68613f9fce5fcb206a75e00f092a638b8b7/src/platform/windows/audio.cpp#L878-L887), [L1002-L1040](https://github.com/LizardByte/Sunshine/blob/b7a0b68613f9fce5fcb206a75e00f092a638b8b7/src/platform/windows/audio.cpp#L1002-L1040), [L1119-L1123](https://github.com/LizardByte/Sunshine/blob/b7a0b68613f9fce5fcb206a75e00f092a638b8b7/src/platform/windows/audio.cpp#L1119-L1123) |
| Sunshine PR #5935, offen | ersetzt `external_audio` durch `keep_default_sink` für alle Systeme | [PR #5935](https://github.com/LizardByte/Sunshine/pull/5935) |
| Sunshine PR #6124, Entwurf | nimmt den Prozessbaum der gestarteten App per Prozess-Loopback auf | [PR #6124](https://github.com/LizardByte/Sunshine/pull/6124) |

Welche Version welchen PR enthält, ergibt der Vergleich der Tags auf GitHub: #5408 ist in [v2026.906.222525](https://github.com/LizardByte/Sunshine/releases/tag/v2026.906.222525) und später, #5647 erst in den Vorabversionen v2026.1122.180652 und [v2026.1123.40502](https://github.com/LizardByte/Sunshine/releases/tag/v2026.1123.40502). (belegt)

Apollo hat seit dem 2026-05-21 nichts mehr gemergt ([PR #1496](https://github.com/ClassicOldSong/Apollo/pull/1496)). Offene PRs reichen bis zum 2026-11-24. (belegt) Ein PR an Apollo kann also lange liegen. (Schluss)

## 2. Toffee

- **Aufnahme**: WASAPI-Loopback im geteilten Modus auf `GetDefaultAudioEndpoint(eRender, eConsole)`. Format fest 24 kHz, 16 Bit, Stereo, Windows wandelt per `AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM` um ([audio_capture.cpp L69-L90](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/src/audio/audio_capture.cpp#L69-L90)). Toffee fragt alle 2 ms ab, ohne Ereignis-Handle ([L23](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/src/audio/audio_capture.cpp#L23), [L107-L139](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/src/audio/audio_capture.cpp#L107-L139)). (belegt)
- **Gerätewechsel**: Toffee meldet sich nicht für Gerätemeldungen an. Erst wenn ein Aufruf scheitert, öffnet es das dann aktuelle Standardgerät neu ([L62-L104](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/src/audio/audio_capture.cpp#L62-L104), [L107-L141](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/src/audio/audio_capture.cpp#L107-L141)). (belegt) WASAPI-Programme müssen dem Standardgerät selbst folgen ([Stream Routing L24-L35](https://github.com/MicrosoftDocs/win32/blob/bc82a65f74ef2c4f2f44a3d7db5f7cfebfdc3583/desktop-src/CoreAudio/stream-routing.md?plain=1#L24-L35)). Ungültig wird ein Strom erst, wenn das Gerät verschwindet oder umkonfiguriert wird ([GetNextPacketSize L73-L77](https://github.com/MicrosoftDocs/sdk-api/blob/656e9656bfaef34dd29cd7ee9e1146aec17e924c/sdk-api-src/content/audioclient/nf-audioclient-iaudiocaptureclient-getnextpacketsize.md?plain=1#L73-L77)). (belegt) Toffee bleibt nach einem Wechsel also beim alten Gerät. (Schluss)
- **Optionen**: nur `--no-audio` und `--audio-gain` ([framework.md L39](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/docs/framework.md?plain=1#L39), [cli/main.cpp L210-L211](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/src/cli/main.cpp#L210-L211)). In der App nur „Audio“ an oder aus und „Audio volume“ ([SettingsPage.qml L19-L41](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/src/ui/qml/SettingsPage.qml#L19-L41)). `docs/setup.md` nennt keine Geräteauswahl. Die Roadmap auch nicht ([roadmap.md L12-L19](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/docs/roadmap.md?plain=1#L12-L19)). (belegt)
- **Folge**: Toffee schickt heute den ganzen Ton des Standardgeräts zum GamePad, also auch Musik und Calls. (Schluss)

### Umfang einer Änderung

| Variante | Was sich ändert | Umfang (Schluss) |
| --- | --- | --- |
| A: bestimmtes Gerät | In [L81](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/src/audio/audio_capture.cpp#L81) statt `GetDefaultAudioEndpoint` das Gerät per `IMMDeviceEnumerator::GetDevice(ID)` öffnen ([GetDevice L53-L59](https://github.com/MicrosoftDocs/sdk-api/blob/656e9656bfaef34dd29cd7ee9e1146aec17e924c/sdk-api-src/content/mmdeviceapi/nf-mmdeviceapi-immdeviceenumerator-getdevice.md?plain=1#L53-L59)), bei einem Namen vorher über die aktiven Wiedergabegeräte suchen. Der Loopback-Code bleibt gleich. Dazu Option `--audio-device`, ein Feld in den Einstellungen und die Weitergabe an `AudioCapture`. Fehlt das Gerät, besser Fehler melden als zum Standardgerät wechseln. | Kern etwa 30 Zeilen, mit CLI und Oberfläche etwa 100 |
| B: Prozess-Loopback | Aktivierung per `ActivateAudioInterfaceAsync(VIRTUAL_AUDIO_DEVICE_PROCESS_LOOPBACK, …)` mit einem agilen Completion-Handler wie im Microsoft-Beispiel ([LoopbackCapture.cpp L50-L71](https://github.com/microsoft/Windows-classic-samples/blob/434f6002bdf9cf9829406c3ff2b33387982d6168/Samples/ApplicationLoopback/cpp/LoopbackCapture.cpp#L50-L71)). Die Prozess-ID kommt aus dem gestreamten Fenster. Toffee ruft dort schon `GetWindowThreadProcessId` auf ([capture_source.cpp L106-L115](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/src/video/capture_source.cpp#L106-L115)). `mmdevapi` linken ([CMakeLists.txt L53-L55](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/CMakeLists.txt#L53-L55)). Windows-Version prüfen. | etwa 150 bis 250 Zeilen |

Zu Variante B:

- Toffee baut mit MinGW 13.1 ([toolchain.json L6-L9](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/toolchain.json#L6-L9)). (belegt) mingw-w64 deklariert `ActivateAudioInterfaceAsync` und hat es in der Importbibliothek ([mmdeviceapi.idl L271-L274](https://github.com/mirror/mingw-w64/blob/93f3505a758fe70e56678f00e753af3bc4f640bb/mingw-w64-headers/include/mmdeviceapi.idl#L271-L274), [mmdevapi.def L4](https://github.com/mirror/mingw-w64/blob/93f3505a758fe70e56678f00e753af3bc4f640bb/mingw-w64-crt/lib-common/mmdevapi.def#L4)). Den Header `audioclientactivationparams.h` hat der Spiegel (Stand 2024-09) nicht ([Verzeichnis](https://github.com/mirror/mingw-w64/tree/93f3505a758fe70e56678f00e753af3bc4f640bb/mingw-w64-headers/include)). (belegt) Toffee müsste die Strukturen selbst deklarieren, wie es das mit GUIDs schon tut ([wasapi_guids.cpp](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/src/audio/wasapi_guids.cpp)). (Schluss)
- Toffee nennt Windows 10 oder 11 als Voraussetzung ([setup.md L9](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/docs/setup.md?plain=1#L9)). (belegt) Prozess-Loopback braucht Build 20348. Windows 10 22H2 hat Build 19045 und fällt damit raus. Variante B muss daher optional bleiben. (Schluss)
- Das feste Format mit `AUTOCONVERTPCM` passt zum Microsoft-Beispiel ([LoopbackCapture.cpp L95-L110](https://github.com/microsoft/Windows-classic-samples/blob/434f6002bdf9cf9829406c3ff2b33387982d6168/Samples/ApplicationLoopback/cpp/LoopbackCapture.cpp#L95-L110)). (belegt) Das Beispiel arbeitet aber mit Ereignis-Handle, Toffee fragt ab. Ob Abfragen beim Prozess-Loopback geht, ist offen.

Toffee steht unter GPL-3.0-only. Die Änderung gehört in einen eigenen Fork und als PR upstream, nicht in unser Repo ([ADR 0005](../docs/adr/0005-direktmodus-als-ziel.md)). Toffee hat noch keine Issues. Zuerst einen Feature Request über die Vorlage öffnen ([roadmap.md L21-L24](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/docs/roadmap.md?plain=1#L21-L24)). (Schluss)

## 3. Lichii

Das Repo ist erreichbar. Lichii baut auf Eglantine, Eden, yuzu und Sudachi auf ([README L21](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/README.md?plain=1#L21)). Die Audio-Einstellungen sind die von Eden. (belegt)

### Einstellungen

| C++-Name | Schlüssel in `qt-config.ini` | Standard | Werte | Beleg |
| --- | --- | --- | --- | --- |
| `sink_id` | `output_engine` | Auto | als Zahl: `0` auto, `1` cubeb, `2` sdl3, `3` null | [settings.h L179-L185](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/common/settings.h#L179-L185), [settings_enums.h L94-L103](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/common/settings_enums.h#L94-L103), [settings_setting.h L128-L140](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/common/settings_setting.h#L128-L140) |
| `audio_output_device_id` | `output_device` | `auto` | Anzeigename des Wiedergabegeräts | [settings.h L186-L187](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/common/settings.h#L186-L187), [sink.h L23](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/audio_core/sink/sink.h#L23) |
| `audio_input_device_id` | `input_device` | `auto` | Mikrofon, hier unwichtig | [settings.h L188-L189](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/common/settings.h#L188-L189) |

Lichii erzeugt den Sink aus `output_engine` und `output_device` ([audio_core.cpp L24-L31](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/audio_core/audio_core.cpp#L24-L31)). Bei `auto` nimmt es cubeb. Meldet cubeb eine zu hohe Latenz, nimmt es SDL3 ([sink_details.cpp L98-L105](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/audio_core/sink/sink_details.cpp#L98-L105)). (belegt)

### Format in `qt-config.ini`

- Datei: `%APPDATA%\lichii\config\qt-config.ini`. Gibt es neben `lichii.exe` einen Ordner `user`, dann `user\config\qt-config.ini` ([path_util.cpp L117-L125](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/common/fs/path_util.cpp#L117-L125), [fs_paths.h L10-L17](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/common/fs/fs_paths.h#L10-L17), [qt_config.h L14](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/qt_common/config/qt_config.h#L14)). (belegt)
- Abschnitt `[Audio]` ([config.cpp L393-L397](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/frontend_common/config.cpp#L393-L397), [settings.cpp L307-L308](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/common/settings.cpp#L307-L308)). (belegt)
- Zu jedem Wert gehört ein Marker `<Schlüssel>\default`. Steht er auf `true` oder fehlt er, nimmt Lichii den eingebauten Standard und ignoriert den Wert ([config.cpp L1102-L1125](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/frontend_common/config.cpp#L1102-L1125)). In Spiel-Konfigurationen kommt `<Schlüssel>\use_global` dazu. (belegt)
- Spiel-Konfigurationen liegen unter `config\custom\<Titel-ID>.ini`. Steht dort `output_device\use_global=false`, gilt für dieses Spiel der eigene Wert statt des globalen. Lichii loggt das als `MC Audio.output_device` („C“ = Wert aus der Spiel-Konfiguration). (belegt am PC, 2026-11-25)
- Lichiis Dialog „Eigenschaften“ eines Spiels setzt diesen Wert ungefragt. Beim Öffnen füllt er die Geräteliste mit eingeschaltetem Schutz `updating_devices` und schaltet ihn wieder aus. Erst danach springt die Liste auf das globale Gerät ([configure_audio.cpp L181-L188](https://github.com/zortos293/Lichii/blob/fdc7cdaf8df179775685d0afb57fca178f876a51/src/lichii/configuration/configure_audio.cpp#L181-L188), [L213-L226](https://github.com/zortos293/Lichii/blob/fdc7cdaf8df179775685d0afb57fca178f876a51/src/lichii/configuration/configure_audio.cpp#L213-L226), [L284-L302](https://github.com/zortos293/Lichii/blob/fdc7cdaf8df179775685d0afb57fca178f876a51/src/lichii/configuration/configure_audio.cpp#L284-L302)). Dieser Sprung gilt als Änderung und setzt `use_global` auf `false` ([L140-L148](https://github.com/zortos293/Lichii/blob/fdc7cdaf8df179775685d0afb57fca178f876a51/src/lichii/configuration/configure_audio.cpp#L140-L148)). (belegt) Ist global ein Gerät eingestellt und nicht `auto`, bekommt also jedes Spiel ein eigenes Tongerät, dessen Eigenschaften man öffnet und mit OK schließt. Am PC des Maintainers passiert, nachdem nur die Eingabe geändert wurde. (Schluss, belegt am PC)
- Zurück geht es über den Knopf „Use the global value“ neben dem Feld ([shared_widget.cpp L104-L113](https://github.com/zortos293/Lichii/blob/fdc7cdaf8df179775685d0afb57fca178f876a51/src/lichii/configuration/shared_widget.cpp#L104-L113)). Das Feld auf `auto` zu stellen reicht nicht, `use_global` bleibt dann `false`. (belegt) Die Prüfregel `audio-game-override` nennt solche Spiele. (Schluss)
- Anführungszeichen setzt Lichii nur, wenn der Wert eines dieser Zeichen enthält: ``! # $ % ^ & * | ; ' " , < > ? ` ~ =``. Beim Lesen entfernt es alle `"`. Backslashes schreibt es als `/` ([config.cpp L1194-L1218](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/frontend_common/config.cpp#L1194-L1218), [config.h L235-L236](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/frontend_common/config.h#L235-L236), [config.cpp L993-L1013](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/frontend_common/config.cpp#L993-L1013)). (belegt) Leerzeichen und Klammern im Gerätenamen brauchen also keine Anführungszeichen. (Schluss)

Beispiel. Der Gerätename ist ein Platzhalter, der echte steht auf dem PC (Schluss):

```ini
[Audio]
output_device\default=false
output_device=CABLE Input (VB-Audio Virtual Cable)
```

`output_engine` kann auf `auto` bleiben. Das Host-Modul kann die Zeilen mit `Merge-LichiiConfig -Section 'Audio'` setzen, wie heute schon für DSU. (Schluss)

### Welcher Name ein Gerät bezeichnet

- cubeb vergleicht `friendly_name` exakt mit `output_device`, nur bei aktiven Geräten ([cubeb_sink.cpp L231-L264](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/audio_core/sink/cubeb_sink.cpp#L231-L264)). Unter WASAPI ist das `PKEY_Device_FriendlyName` ([cubeb_wasapi.cpp L3328-L3331](https://github.com/mozilla/cubeb/blob/fa021607121360af7c171d881dc5bc8af7bb56eb/src/cubeb_wasapi.cpp#L3328-L3331), Version laut [cpmfile.json L46-L57](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/cpmfile.json#L46-L57)). (belegt)
- SDL3 vergleicht `SDL_GetAudioDeviceName` exakt ([sdl3_sink.cpp L46-L65](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/audio_core/sink/sdl3_sink.cpp#L46-L65)). Unter Windows ist das ebenfalls `PKEY_Device_FriendlyName` ([SDL_immdevice.c L86-L100](https://github.com/libsdl-org/SDL/blob/release-3.4.20/src/core/windows/SDL_immdevice.c#L86-L100)). (belegt)
- Beide nutzen also den Namen, den Windows in den Sound-Einstellungen zeigt, etwa „Lautsprecher (Adapter)“. Eine Geräte-ID versteht Lichii nicht. (Schluss)
- Die Oberfläche speichert den Text des gewählten Listeneintrags ([configure_audio.cpp L266-L268, L286-L292](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/lichii/configuration/configure_audio.cpp#L266-L292)). (belegt)
- Der Gerätename in der Windows-Geräteverwaltung (`Win32_PnPEntity`) kann davon abweichen. Am PC des Maintainers am 2026-11-25 gemessen, direkt nach der Installation von VB-CABLE: Die Geräteverwaltung nennt das Gerät „Lautsprecher (VB-Audio Virtual Cable)“, Core Audio (`PKEY_Device_FriendlyName`) dagegen „CABLE Input (VB-Audio Virtual Cable)“. Bei den anderen Geräten waren beide Namen gleich. (belegt am PC) Das Host-Modul liest die Namen deshalb über Core Audio. (Schluss)

### Wenn das Gerät fehlt

- cubeb: ohne Treffer bleibt die Geräte-ID leer ([cubeb_sink.h L82](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/audio_core/sink/cubeb_sink.h#L82)). Dann nimmt cubeb das Standardgerät und folgt ihm. Mit Treffer bleibt der Strom bei genau diesem Gerät ([cubeb.h L575-L579](https://github.com/mozilla/cubeb/blob/fa021607121360af7c171d881dc5bc8af7bb56eb/include/cubeb/cubeb.h#L575-L579)). (belegt)
- SDL3: ohne Treffer `SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK` ([sdl3_sink.cpp L54-L61](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/audio_core/sink/sdl3_sink.cpp#L54-L61)). Das folgt dem Standardgerät ([SDL_audio.h L676-L686](https://github.com/libsdl-org/SDL/blob/release-3.4.20/include/SDL3/SDL_audio.h#L676-L686)). (belegt)
- Die Suchschleifen schreiben dabei nichts ins Log. (belegt, siehe die verlinkten Zeilen) Ein Tippfehler im Namen schickt den Spielton also unbemerkt auf das Standardgerät. Die Prüfregel `audio-isolated` muss deshalb prüfen, ob es ein aktives Wiedergabegerät mit genau diesem Namen gibt. (Schluss)

## 4. Wege unter Windows

| Weg | Voraussetzung | Standardgerät bleibt | Grenzen |
| --- | --- | --- | --- |
| a. Eigenes Gerät, Loopback dieses Geräts | Virtuelles Gerät (VB-CABLE), Lichii spielt darauf, die Brücke öffnet „CABLE Input“ gezielt | ja | Treiber nötig. Die Brücke muss ein Gerät wählen können. |
| a'. Aufnahme von „CABLE Output“ | dasselbe Kabel, normale Aufnahme vom Aufnahmegerät | ja | Für Apollo und Sunshine ungeeignet, die nehmen nur Wiedergabegeräte per Loopback auf |
| b. Windows-Einstellung pro App | Lichii auf `auto`, in Windows für Lichii ein anderes Ausgabegerät | ja | Keine dokumentierte API, nur von Hand. Speicherort und Haltbarkeit undokumentiert. |
| c. Prozess-Loopback | Windows 10 Build 20348 oder neuer, Brücke kennt Lichiis Prozess-ID | ja | Spielt Lichii auf dem Standardgerät, hört man das Spiel auch am PC. Stummschalten im Mixer schaltet auch die Aufnahme stumm. |
| d. Sunshine `external_audio` | Sunshine-Vorabversion ab v2026.1122 statt Apollo, `audio_sink` gesetzt | ja | Apollo hat es nicht. Der Name des Schalters kann sich noch ändern. |

Bewertung der Spalten: (Schluss aus den Belegen unten)

### a. Eigenes Gerät

- „In loopback mode, a client of WASAPI can capture the audio stream that is being played by a rendering endpoint device.“ Dafür braucht der Client nur das `IMMDevice` dieses Geräts ([Loopback Recording L11-L14](https://github.com/MicrosoftDocs/win32/blob/bc82a65f74ef2c4f2f44a3d7db5f7cfebfdc3583/desktop-src/CoreAudio/loopback-recording.md?plain=1#L11-L14)). Das muss nicht das Standardgerät sein. Loopback geht nur im geteilten Modus ([L27](https://github.com/MicrosoftDocs/win32/blob/bc82a65f74ef2c4f2f44a3d7db5f7cfebfdc3583/desktop-src/CoreAudio/loopback-recording.md?plain=1#L27)). (belegt)
- Ein Gerät öffnet man per Endpunkt-ID mit `IMMDeviceEnumerator::GetDevice` ([L53-L59](https://github.com/MicrosoftDocs/sdk-api/blob/656e9656bfaef34dd29cd7ee9e1146aec17e924c/sdk-api-src/content/mmdeviceapi/nf-mmdeviceapi-immdeviceenumerator-getdevice.md?plain=1#L53-L59)). Die ID überlebt Neustarts, ändert sich aber bei Neuinstallation oder Update des Treibers. Zwei Geräte können denselben Anzeigenamen haben ([Endpoint ID Strings L13, L29](https://github.com/MicrosoftDocs/win32/blob/bc82a65f74ef2c4f2f44a3d7db5f7cfebfdc3583/desktop-src/CoreAudio/endpoint-id-strings.md?plain=1#L13-L29)). (belegt)
- VB-CABLE: „All audio coming in the CABLE input is simply forwarded to the CABLE output.“ Donationware, Windows XP bis 11 ([VB-Audio](https://vb-audio.com/Cable/)). (belegt)
- Apollo und Sunshine suchen nur unter aktiven Wiedergabegeräten ([Apollo windows/audio.cpp L913-L923](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/platform/windows/audio.cpp#L913-L923)). (belegt) `audio_sink` muss also „CABLE Input“ sein, nicht „CABLE Output“. (Schluss)
- Die IDs und Namen listet `tools\audio-info.exe` aus Apollo: Device ID, Device name, Adapter name ([tools/audio.cpp L215-L223](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/tools/audio.cpp#L215-L223)). (belegt)

### b. Windows-Einstellung pro App

- Unter Windows 11: Einstellungen > System > Sound > Lautstärkemixer, dort pro App das Ausgabegerät. „Apps can use a different output device than the system default.“ ([Microsoft Support](https://support.microsoft.com/en-US/Windows/Hardware/audio/fix-app-audio-not-working-while-system-sounds-work-in-windows)). (belegt)
- Eine dokumentierte Win32-API dafür haben wir auf Microsoft Learn nicht gefunden. (Schluss)
- EarTrumpet setzt die Einstellung über die undokumentierte Schnittstelle `IAudioPolicyConfigFactory::SetPersistedDefaultAudioEndpoint` mit einer Prozess-ID. Die Schnittstelle gibt es je nach Windows-Version in verschiedenen Varianten ([AudioPolicyConfigService.cs L44-L66](https://github.com/File-New-Project/EarTrumpet/blob/17bbd57a71dbea2e287a83ebe34a6d67be0040c3/EarTrumpet/DataModel/WindowsAudio/Internal/AudioPolicyConfigService.cs#L44-L66), [AudioPolicyConfigFactory.cs L9-L19](https://github.com/File-New-Project/EarTrumpet/blob/17bbd57a71dbea2e287a83ebe34a6d67be0040c3/EarTrumpet/Interop/Helpers/AudioPolicyConfigFactory.cs#L9-L19), [IAudioPolicyConfigFactoryVariantFor21H2.cs L6-L34](https://github.com/File-New-Project/EarTrumpet/blob/17bbd57a71dbea2e287a83ebe34a6d67be0040c3/EarTrumpet/Interop/MMDeviceAPI/IAudioPolicyConfigFactoryVariantFor21H2.cs#L6-L34)). (belegt)
- Wo Windows die Wahl speichert und ob sie Neustarts überlebt, sagt keine Primärquelle. „Persisted“ im Namen spricht dafür. (Schluss)
- Der normale Loopback eines Geräts enthält „all audio from all apps that are playing sounds on the chosen audio endpoint“ ([ApplicationLoopback README L19-L21](https://github.com/microsoft/Windows-classic-samples/blob/434f6002bdf9cf9829406c3ff2b33387982d6168/Samples/ApplicationLoopback/README.md?plain=1#L19-L21)). (belegt) Eine App auf einem anderen Gerät fehlt darin also. (Schluss)
- Für uns bringt b nichts gegenüber a: Lichii kann sein Gerät selbst wählen, und das steht skriptbar in `qt-config.ini`. (Schluss)

### c. Prozess-Loopback

- Aktivierung: `ActivateAudioInterfaceAsync` mit `VIRTUAL_AUDIO_DEVICE_PROCESS_LOOPBACK` und `AUDIOCLIENT_ACTIVATION_PARAMS` ([ActivateAudioInterfaceAsync L57-L73](https://github.com/MicrosoftDocs/sdk-api/blob/656e9656bfaef34dd29cd7ee9e1146aec17e924c/sdk-api-src/content/mmdeviceapi/nf-mmdeviceapi-activateaudiointerfaceasync.md?plain=1#L57-L73)). Typ `AUDIOCLIENT_ACTIVATION_TYPE_PROCESS_LOOPBACK` ([L48-L50](https://github.com/MicrosoftDocs/sdk-api/blob/656e9656bfaef34dd29cd7ee9e1146aec17e924c/sdk-api-src/content/audioclientactivationparams/ne-audioclientactivationparams-audioclient_activation_type.md?plain=1#L48-L50)). Dazu `TargetProcessId` und der Modus ([AUDIOCLIENT_PROCESS_LOOPBACK_PARAMS L48-L54](https://github.com/MicrosoftDocs/sdk-api/blob/656e9656bfaef34dd29cd7ee9e1146aec17e924c/sdk-api-src/content/audioclientactivationparams/ns-audioclientactivationparams-audioclient_process_loopback_params.md?plain=1#L48-L54)). (belegt)
- `PROCESS_LOOPBACK_MODE_INCLUDE_TARGET_PROCESS_TREE` nimmt den Prozess und seine Kindprozesse auf, `…_EXCLUDE_…` alles außer ihnen ([PROCESS_LOOPBACK_MODE L44-L50](https://github.com/MicrosoftDocs/sdk-api/blob/656e9656bfaef34dd29cd7ee9e1146aec17e924c/sdk-api-src/content/audioclientactivationparams/ne-audioclientactivationparams-process_loopback_mode.md?plain=1#L44-L50)). (belegt)
- Mindestversion: Windows 10 Build 20348 laut Typ-Seite und Beispiel ([L18](https://github.com/MicrosoftDocs/sdk-api/blob/656e9656bfaef34dd29cd7ee9e1146aec17e924c/sdk-api-src/content/audioclientactivationparams/ne-audioclientactivationparams-audioclient_activation_type.md?plain=1#L18), [README L41](https://github.com/microsoft/Windows-classic-samples/blob/434f6002bdf9cf9829406c3ff2b33387982d6168/Samples/ApplicationLoopback/README.md?plain=1#L41)). Die Funktionsseite nennt Build 20438 ([L73](https://github.com/MicrosoftDocs/sdk-api/blob/656e9656bfaef34dd29cd7ee9e1146aec17e924c/sdk-api-src/content/mmdeviceapi/nf-mmdeviceapi-activateaudiointerfaceasync.md?plain=1#L73)). (belegt) Windows 11 liegt über beiden Angaben. (Schluss)
- „the capture is not tied to a specific audio endpoint“ ([README L25-L27](https://github.com/microsoft/Windows-classic-samples/blob/434f6002bdf9cf9829406c3ff2b33387982d6168/Samples/ApplicationLoopback/README.md?plain=1#L25-L27)). Spielt der Prozess nichts, kommt Stille ([L29-L30](https://github.com/microsoft/Windows-classic-samples/blob/434f6002bdf9cf9829406c3ff2b33387982d6168/Samples/ApplicationLoopback/README.md?plain=1#L29-L30)). (belegt)
- Prozess-Loopback braucht kein virtuelles Gerät. Soll das Spiel am PC aber nicht zu hören sein, muss Lichii trotzdem auf ein stilles Gerät spielen. Mit beidem zusammen landet auch dann nur Lichii im Stream, wenn eine andere App versehentlich auf „CABLE Input“ spielt. (Schluss)

#### Messung: Stummschalten und Lautstärke im Mixer

Gemessen mit [`tools/Measure-ProcessLoopback.ps1`](tools/Measure-ProcessLoopback.ps1), Aufruf `-SelfTest -ToneDevice 'CABLE Input (VB-Audio Virtual Cable)' -PhaseSeconds 3`. Das Skript startet einen Kindprozess, der einen Sinuston mit 440 Hz und −30 dBFS auf „CABLE Input“ spielt. Diesen Prozess nimmt es per Prozess-Loopback auf (48 kHz, 16 Bit, Stereo, `AUTOCONVERTPCM`). Währenddessen setzt es Stummschaltung und Lautstärke der Tonsitzung des Prozesses über `ISimpleAudioVolume`, die Schnittstelle hinter den Reglern pro App im Lautstärkemixer.

Am PC des Maintainers am 2026-11-26, Windows 11 Pro Build 26300, in Windows PowerShell 5.1 und PowerShell 7, mit Ereignis-Handle und mit Abfragen alle 10 ms. Alle Läufe ergaben dieselben Werte: (belegt am PC)

| Phase | Pakete in 3 s | Stille Pakete | Spitze dBFS | RMS dBFS |
| --- | --- | --- | --- | --- |
| normal | 300 | 0 | −30,0 | −33,0 |
| stumm | 300 | 0 | −90,3 | −96,7 |
| leise (10 %) | 300 | 0 | −49,9 | −53,0 |
| normal (zurück) | 300 | 0 | −30,0 | −33,0 |

- Windows wendet Stummschaltung und Lautstärke der Sitzung an, **bevor** der Prozess-Loopback den Ton abgreift. Stumm kommen weiter Pakete, aber nur Rundungsrauschen von etwa 1 LSB. Das Flag `AUDCLNT_BUFFERFLAGS_SILENT` setzt Windows dabei nicht. 10 % Lautstärke sind genau 20 dB weniger. (belegt am PC)
- Lichii im Mixer stumm schalten ist deshalb kein Ersatz für ein stilles Gerät: Die Brücke bekäme dann auch Stille. (Schluss)
- Abfragen ohne Ereignis-Handle funktioniert mit Prozess-Loopback: 100 Pakete pro Sekunde, wie mit Ereignis. Toffee kann also bei seiner Art zu lesen bleiben. (belegt am PC)
- Der Testton spielte auf „CABLE Input“, Lichii spielt dagegen auf das Standardgerät. Die Sitzungslautstärke gilt pro Stream und unabhängig vom Gerät. Mit Lichii ist deshalb dasselbe Ergebnis zu erwarten. (Schluss) Bestätigen: „Prüfen am PC“, Schritt 5.

### d. Weitere Wege

- **Sunshine `external_audio`**: siehe Abschnitt 1. Mit `audio_sink = <ID von CABLE Input>` und `external_audio = enabled` wäre der Apollo-Weg gelöst, aber ohne Apollo. ADR 0002 legt Apollo fest. Ein Wechsel bräuchte ein neues ADR. Ob Sunshine Apollos virtuelles Display pro App ersetzen kann, haben wir nicht geprüft. (Schluss)
- **Sunshine PR #6124** (Entwurf) nimmt den Prozessbaum der gestarteten App auf ([PR #6124](https://github.com/LizardByte/Sunshine/pull/6124)). (belegt) Das wäre die sauberste Lösung für den Apollo-Weg, ist aber weit vom Release entfernt. (Schluss)
- **Notbehelf mit Apollo, nicht empfohlen**: Host-Ton an, `audio_sink` = CABLE Input, `auto_capture_sink = disabled`. Apollo stellt beim Start auf CABLE um und öffnet dort die Aufnahme. Stellt danach jemand das Standardgerät zurück, bleibt die Aufnahme beim alten Gerät ([audio.cpp L232-L244](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/audio.cpp#L232-L244), [windows/audio.cpp L585-L594](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/platform/windows/audio.cpp#L585-L594)). `keep_sink_default` greift bei einem nicht virtuellen Gerät nicht ([L771-L780](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/platform/windows/audio.cpp#L771-L780)). (belegt) Das Standardgerät wechselt aber kurz. Musik und Calls springen dabei auf CABLE und zurück. Das Zurückstellen braucht ein zweites Werkzeug. Das verletzt ADR 0004. (Schluss)

### e. Stilles Gerät bereitstellen

Ein stilles Gerät braucht unter Windows einen Treiber für ein virtuelles Audiogerät. Ohne Treiber bleibt nur ein ungenutztes echtes Wiedergabegerät, etwa der HDMI-Ton eines Monitors ohne Lautsprecher. Das hängt von der Hardware ab. (Schluss) Wir ziehen offene Treiber vor, die wir mitliefern dürfen. (Entscheidung des Maintainers, 2026-11-26)

**VB-CABLE** (proprietär, Donationware):

- Wer VB-CABLE an Firmen oder Einrichtungen verteilt, braucht eine bezahlte Lizenz. Für Bundles und die Einbindung in eigene Software verlangt VB-Audio eine eigene Vereinbarung ([Licensing](https://vb-audio.com/Services/licensing.htm)). (belegt) Ins Repo und in einen eigenen Installer gehört VB-CABLE damit nicht. Der Installer kann höchstens die offizielle Datei von vb-audio.com laden und starten. (Schluss)
- Stille Installation: Laut zwei Forenbeiträgen kennt `VBCABLE_Setup_x64.exe` die Schalter `-i -h`, laut einem anderen `-i -y`. Dokumentiert sind sie nicht. Den Dialog von Windows für die Treiberinstallation zeigt Windows trotzdem. Der Entwickler von VB-Audio hält es für unmöglich, ihn zu umgehen ([Forum p=7128](https://forum.vb-audio.com/viewtopic.php?p=7128), [Forum p=6681](https://forum.vb-audio.com/viewtopic.php?p=6681)). (belegt, nur Forum) Einmal bestätigen muss man also immer. (Schluss)

**[Virtual-Audio-Driver](https://github.com/VirtualDrivers/Virtual-Audio-Driver)** (offen, Stand [bb34fba](https://github.com/VirtualDrivers/Virtual-Audio-Driver/tree/bb34fba15faf569a6ae9bdea360bc1cf4821354e) vom 2026-03-03):

- MIT-Lizenz. Legt einen virtuellen Lautsprecher und ein virtuelles Mikrofon an. Stammt aus derselben GitHub-Organisation wie der [Virtual Display Driver](https://github.com/VirtualDrivers/Virtual-Display-Driver) (MIT). (belegt) Mitliefern dürften wir ihn. (Schluss)
- Die Version [25.7.14](https://github.com/VirtualDrivers/Virtual-Audio-Driver/releases/tag/25.7.14) vom 2025-07-14 heißt „Signed“. Signiert ist sie über SignPath.io mit einem Zertifikat der SignPath Foundation. (belegt)
- Das README nennt die Software Beta und verlangt eine Testsignatur, „A production-signed driver can skip this step“ ([README L2, L58-L63](https://github.com/VirtualDrivers/Virtual-Audio-Driver/blob/bb34fba15faf569a6ae9bdea360bc1cf4821354e/README.md?plain=1#L58-L63)). Installiert wird von Hand über den Gerätemanager. (belegt) Ob die signierte Version mit Secure Boot ohne Testmodus lädt, haben wir nicht geprüft.
- Offene Issues: Die signierte Version lässt sich nur ab Build 22000 (Windows 11) installieren, obwohl das README Windows 10 nennt ([#23](https://github.com/VirtualDrivers/Virtual-Audio-Driver/issues/23)). Dazu Fehler 39 ([#7](https://github.com/VirtualDrivers/Virtual-Audio-Driver/issues/7)) und eine gescheiterte Installation ([#10](https://github.com/VirtualDrivers/Virtual-Audio-Driver/issues/10)). (belegt)
- Bewertung: der bevorzugte Kandidat, als Standard aber noch zu unreif. Vor einem Wechsel am PC prüfen: Installation ohne Testmodus, Gerätename in Core Audio, Lichii spielt darauf, Toffee nimmt davon auf. (Schluss)

**Eigener Treiber:** Er müsste von Microsoft signiert sein, wie der Treiber für die Spielanzeige. Für dieses Projekt ist das nicht realistisch. (Schluss)

## 5. Schluss

### Toffee-Weg

| Schritt | Ort | Art |
| --- | --- | --- |
| 1. VB-CABLE installieren | Host | von Hand, Treiber mit Adminrechten |
| 2. `[Audio] output_device` = Anzeigename von „CABLE Input“, `output_device\default=false` | Lichiis `qt-config.ini` | Konfiguration, Host-Modul |
| 3. Toffee nimmt „CABLE Input“ auf (Variante A) | Toffee | Feature Request und PR upstream, bis dahin eigener Fork |
| 4. optional Prozess-Loopback des gestreamten Fensters (Variante B) | Toffee | PR upstream |

Ohne Schritt 3 gibt es im Toffee-Weg keine Isolation. Toffee würde den Ton der Lautsprecher schicken, Lichiis Spielton aber gar nicht. (Schluss)

### Apollo-Weg

| Schritt | Ort | Art |
| --- | --- | --- |
| 1. und 2. wie oben | Host, Lichii | Konfiguration |
| 3. Apollo nimmt `audio_sink` direkt auf und lässt das Standardgerät in Ruhe | Apollo | PR upstream, der Sunshine #5408 und #5647 nachzieht, oder der nächste Abgleich mit Sunshine |
| 4. `audio_sink = <ID von CABLE Input>`, `external_audio = enabled` (oder der Name, den Sunshine am Ende wählt) | `sunshine.conf` von Apollo | Konfiguration, Host-Modul |

- Das Host-Ton-Flag des Clients ist danach egal. (Schluss aus [Sunshine configuration.md L954-L956](https://github.com/LizardByte/Sunshine/blob/b7a0b68613f9fce5fcb206a75e00f092a638b8b7/docs/configuration.md?plain=1#L954-L956))
- Der PR an Apollo muss auch die Apollo-eigenen Schalter `keep_sink_default` und `auto_capture_sink` im neuen Modus abschalten. (Schluss)
- Bis Schritt 3 erfüllt keine Apollo-Konfiguration ADR 0004. Für M1 bleibt nur: Host-Ton an, `audio_sink` leer. Dann bleibt das Standardgerät, aber der ganze Host-Ton geht mit. (Schluss)
- ADR 0002 bleibt gewahrt: Apollo und Lichii werden nur konfiguriert, die Code-Änderung geht als PR an Apollo und an Toffee. (Schluss)

### ADR 0004

Der Ton-Satz sollte lauten: „Lichii spielt auf ein eigenes Gerät. Die Brücke nimmt genau dieses Gerät auf, ohne das Standardgerät zu ändern. Apollo kann das erst nach einem Upstream-PR, Toffee nach einer Option für das Gerät.“ (Schluss)

### Prüfen am PC, ohne GamePad

1. **Gerätenamen lesen**: VB-CABLE installieren, dann `tools\audio-info.exe` aus Apollo starten. ID und Namen von „CABLE Input“ notieren. Den Namen allein zeigt auch `Test-LichiiGamepadHost -Detailed`: Bei falschem Namen listet die Regel `audio-isolated` alle aktiven Wiedergabegeräte auf.
2. **Lichii allein**: Lichii beenden, `Set-LichiiGamepadLichiiConfig -AudioDevice '<Name>'` ausführen, Lichii starten. Am PC ist das Spiel nicht zu hören. Musik am PC läuft weiter über die Lautsprecher. In der Systemsteuerung unter Sound (`mmsys.cpl`), Reiter Wiedergabe, schlägt der Pegel bei „CABLE Input“ aus, solange das Spiel Ton macht. Der Lautstärkemixer der Windows-Einstellungen taugt dafür nicht: Er zeigt pro App nur die Windows-Vorgabe, nicht das Gerät, das Lichii selbst wählt. Am PC des Maintainers am 2026-11-25 gemessen: Laut Core Audio (`IAudioSessionManager2`) hatte Lichii seine einzige aktive Sitzung auf „CABLE Input“, der Mixer zeigte bei Lichii aber nicht „CABLE Input“. (belegt am PC)
3. **Aufnahme statt Brücke**: Mit einer beliebigen Aufnahme-App „CABLE Output“ aufnehmen, während am PC Musik läuft. Die Aufnahme darf nur Lichii enthalten. Das prüft Weg a ganz ohne Brücke.
4. **Rückfall prüfen**: Einen falschen Namen eintragen. Erwartet: Lichii spielt auf dem Standardgerät, ohne Meldung. Daran testet man die Prüfregel `audio-isolated`. Das gilt nur für ein Spiel ohne eigenes Tongerät: Meldet `audio-game-override` das Spiel, gilt dessen eigener Wert. Am PC des Maintainers blieb ein Spiel deshalb auf „CABLE Input“.
5. **Prozess-Loopback mit Lichii**: Prüft, was eine Brücke per Prozess-Loopback von Lichii bekommt, auch wenn Lichii im Lautstärkemixer stumm ist. Werkzeug: [`tools/Measure-ProcessLoopback.ps1`](tools/Measure-ProcessLoopback.ps1). Es braucht keinen Build und keine Installation. Ablauf und Auswertung stehen in „Messung mit Lichii“ unten.
6. **Apollo heute**: Mit einem beliebigen Moonlight-Client, etwa moonlight-qt auf einem Laptop, die Zeilen der Tabelle in Abschnitt 1 durchspielen. Vor, während und nach dem Stream das Standardgerät in den Sound-Einstellungen ablesen. Im Apollo-Log steht „Selected audio sink“ ([audio.cpp L185](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/audio.cpp#L185)). Erwartet: Das Standardgerät wechselt, wie im Code.
7. **Toffee heute**: Mit Toffee streamen und am PC Musik abspielen. Erwartet: Die Musik ist auf dem GamePad zu hören. Das bestätigt die Lücke für #31.
8. **Nach den PRs**: Schritt 6 mit `external_audio` und Schritt 7 mit der neuen Option wiederholen. Das Standardgerät darf sich nie ändern.

### Messung mit Lichii

Bestätigt die Messung mit dem Testton aus Abschnitt 4 c mit Lichii selbst. Dauer etwa 25 Sekunden.

Vorbereiten:

1. In Lichii muss die allgemeine Einstellung „Pause when not in focus“ aus sein. Das ist der Standard ([uisettings.h L111-L116](https://github.com/zortos293/Lichii/blob/2f5443491615e7200a34e642f45ff42dddcd49e7/src/qt_common/config/uisettings.h#L111-L116), [shared_translation.cpp L552-L553](https://github.com/zortos293/Lichii/blob/2f5443491615e7200a34e642f45ff42dddcd49e7/src/qt_common/config/shared_translation.cpp#L552-L553)). Sonst pausiert das Spiel, sobald das PowerShell-Fenster vorne ist.
2. Lichii spielt auf das Standardgerät: `Test-LichiiGamepadHost -Detailed` meldet bei `audio-isolated` „Standardgerät“ und bei `audio-game-override` Pass. Das ist hier gewollt, denn so würde man es ohne stilles Gerät betreiben.
3. Ein Spiel starten und an eine Stelle gehen, die durchgehend Ton macht, etwa ein Menü mit Musik. Das Spiel nicht pausieren.
4. Lichii im Lautstärkemixer auf 100 % und nicht stumm stellen. Das Skript gibt den Zustand vorher und nachher aus.
5. Als Gegenprobe im Browser Musik laufen lassen. Sie darf in der Aufnahme nicht vorkommen.

Messen, in einem normalen PowerShell-Fenster ohne Adminrechte:

```powershell
cd 'D:\WiiU Gamepad Claude'
powershell -NoProfile -ExecutionPolicy Bypass -File research\tools\Measure-ProcessLoopback.ps1 -WavPath "$env:TEMP\lichii-loopback.wav"
```

`-ExecutionPolicy Bypass` gilt nur für diesen Aufruf. Der Pfad ist ein Beispiel. Während der Messung ist das Spiel am PC 5 Sekunden stumm und dann 5 Sekunden leise. Das Skript stellt danach Lautstärke und Stummschaltung zurück. Wurde es hart abgebrochen, etwa durch Schließen des Fensters, Lichii im Mixer von Hand zurückstellen.

Zum Vergleich ein zweiter Lauf mit `-Polling` (Abfragen wie Toffee) und der Selbsttest ohne Lichii: `-SelfTest -ToneDevice 'CABLE Input (VB-Audio Virtual Cable)'`.

Auswerten:

- **Tabelle**: Erwartet sind Pakete in allen vier Phasen, „stumm“ unter −80 dBFS RMS und „leise (10 %)“ etwa 20 dB unter „normal“. Liegen „normal“ und „normal (zurück)“ mehr als 6 dB auseinander, war die Stelle im Spiel zu unruhig. Dann an einer gleichmäßigeren Stelle wiederholen.
- **Ergebnis-Zeile**: „Stummschalten wirkt auch auf den Prozess-Loopback“ bestätigt die Messung mit dem Testton. „Wirkt NICHT“ widerspräche ihr: Dann bräuchte der Toffee-Weg mit Prozess-Loopback gar kein stilles Gerät. Lichii würde dann stumm geschaltet aufs Standardgerät spielen.
- **WAV in Audacity**: Erwartet ist das Muster laut, flach, leise, laut, jeweils etwa 5 Sekunden. Die Musik aus dem Browser fehlt.

Festhalten: Die Ausgabe des Skripts (Ziel, Windows, Lesen, Sitzungen, Tabelle, Ergebnis) für beide Läufe als Kommentar an Issue #15. Die WAV-Datei bleibt lokal.

## Offene Fragen

- Wie heißt „CABLE Input“ auf dem Host genau? Ändert ein Treiber-Update die Geräte-ID, muss `audio_sink` neu gesetzt werden.
- Wählt Lichii bei `auto` auf dem Host cubeb oder SDL3? Beide nutzen denselben Namen, aber das Verhalten bei Latenz kann sich unterscheiden.
- Haben Spielprofile eigene Spiel-Konfigurationen mit `output_device\use_global=false`? Dann gilt dort ein anderer Wert.
- Was passiert, wenn VB-CABLE während des Spiels verschwindet? cubeb kehrt laut Doku nicht zum Standardgerät zurück. Ob Lichii neu startet oder stumm bleibt, ist offen.
- Liefert der Loopback von „CABLE Input“ Pakete, solange Lichii nichts spielt? Wenn nicht, bekommt das GamePad Lücken im Ton. Wie es darauf reagiert, ist offen.
- ~~Geht Prozess-Loopback mit Toffees Abfragen ohne Ereignis-Handle? Wirkt die Stummschaltung im Lautstärkemixer auf den Prozess-Loopback?~~ Beides geklärt mit dem Testton (Abschnitt 4 c): Abfragen geht, und die Stummschaltung wirkt mit. Die Bestätigung mit Lichii steht aus („Messung mit Lichii“).
- Lädt die signierte Version von Virtual-Audio-Driver mit Secure Boot ohne Testmodus? Taugt sie als stilles Gerät für Lichii (Abschnitt 4 e)?
- Ändert die Windows-Einstellung pro App für `toffee.exe` die Quelle seines Loopbacks? Das wäre ein Weg ohne Code. Toffee spielt aber selbst nichts ab und erscheint deshalb vermutlich nicht im Lautstärkemixer.
- Überlebt die Windows-Einstellung pro App einen Neustart, und wo steht sie?
- Nimmt der Apollo-Maintainer einen PR an, und wann? Welchen Namen bekommt der Schalter in Sunshine am Ende: `external_audio` oder `keep_default_sink`?
- Läuft auf dem Host Windows 11 oder Windows 10 ab Build 20348? Nur dann gibt es Prozess-Loopback.

## Quellen

Code (Permalinks auf die geprüften Stände):

- Apollo: [src/audio.cpp](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/audio.cpp), [src/platform/windows/audio.cpp](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/platform/windows/audio.cpp), [src/config.cpp](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/config.cpp), [src/nvhttp.cpp](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src/nvhttp.cpp), [docs/configuration.md](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/docs/configuration.md), [en.json](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/src_assets/common/assets/web/public/assets/locale/en.json), [tools/audio.cpp](https://github.com/ClassicOldSong/Apollo/blob/adc5c5a0bd80831ce495434bb16aee2cd4175fb8/tools/audio.cpp), [Releases](https://github.com/ClassicOldSong/Apollo/releases)
- Sunshine: [src/audio.cpp](https://github.com/LizardByte/Sunshine/blob/b7a0b68613f9fce5fcb206a75e00f092a638b8b7/src/audio.cpp#L187-L226), [src/platform/windows/audio.cpp](https://github.com/LizardByte/Sunshine/blob/b7a0b68613f9fce5fcb206a75e00f092a638b8b7/src/platform/windows/audio.cpp), [docs/configuration.md](https://github.com/LizardByte/Sunshine/blob/b7a0b68613f9fce5fcb206a75e00f092a638b8b7/docs/configuration.md), PRs [#5408](https://github.com/LizardByte/Sunshine/pull/5408), [#5647](https://github.com/LizardByte/Sunshine/pull/5647), [#5935](https://github.com/LizardByte/Sunshine/pull/5935), [#6124](https://github.com/LizardByte/Sunshine/pull/6124), [Releases](https://github.com/LizardByte/Sunshine/releases)
- Toffee: [src/audio/audio_capture.cpp](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/src/audio/audio_capture.cpp), [src/cli/main.cpp](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/src/cli/main.cpp), [docs/framework.md](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/docs/framework.md), [docs/setup.md](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/docs/setup.md), [docs/roadmap.md](https://github.com/Gavwalsh15/toffee_wiiu/blob/85051f02a4537d860052f5e1985efebd688eac13/docs/roadmap.md)
- Lichii: [src/common/settings.h](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/common/settings.h), [src/audio_core/sink/](https://github.com/zortos293/Lichii/tree/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/audio_core/sink), [src/frontend_common/config.cpp](https://github.com/zortos293/Lichii/blob/7cc8a7750c0b98ce87917236d35e57e2f23cc811/src/frontend_common/config.cpp)
- cubeb [fa02160](https://github.com/mozilla/cubeb/tree/fa021607121360af7c171d881dc5bc8af7bb56eb), SDL [release-3.4.20](https://github.com/libsdl-org/SDL/tree/release-3.4.20)
- moonlight-qt [dc99771](https://github.com/moonlight-stream/moonlight-qt/tree/dc99771b1d4310aa8648dbaf374b3a2178e6f935), moonlight-embedded [33142e5](https://github.com/moonlight-stream/moonlight-embedded/tree/33142e58ebd576085a076f4ce24881d20b3c4ef5)
- EarTrumpet [17bbd57](https://github.com/File-New-Project/EarTrumpet/tree/17bbd57a71dbea2e287a83ebe34a6d67be0040c3), mingw-w64-Spiegel [93f3505](https://github.com/mirror/mingw-w64/tree/93f3505a758fe70e56678f00e753af3bc4f640bb)

Microsoft (Learn-Seiten, Zeilenangaben aus den Quell-Repos [MicrosoftDocs/win32](https://github.com/MicrosoftDocs/win32/tree/bc82a65f74ef2c4f2f44a3d7db5f7cfebfdc3583) und [MicrosoftDocs/sdk-api](https://github.com/MicrosoftDocs/sdk-api/tree/656e9656bfaef34dd29cd7ee9e1146aec17e924c)):

- [Loopback Recording](https://learn.microsoft.com/en-us/windows/win32/coreaudio/loopback-recording)
- [Stream Routing](https://learn.microsoft.com/en-us/windows/win32/coreaudio/stream-routing)
- [Endpoint ID Strings](https://learn.microsoft.com/en-us/windows/win32/coreaudio/endpoint-id-strings)
- [IMMDeviceEnumerator::GetDevice](https://learn.microsoft.com/en-us/windows/win32/api/mmdeviceapi/nf-mmdeviceapi-immdeviceenumerator-getdevice)
- [IAudioCaptureClient::GetNextPacketSize](https://learn.microsoft.com/en-us/windows/win32/api/audioclient/nf-audioclient-iaudiocaptureclient-getnextpacketsize)
- [ActivateAudioInterfaceAsync](https://learn.microsoft.com/en-us/windows/win32/api/mmdeviceapi/nf-mmdeviceapi-activateaudiointerfaceasync)
- [AUDIOCLIENT_ACTIVATION_TYPE](https://learn.microsoft.com/en-us/windows/win32/api/audioclientactivationparams/ne-audioclientactivationparams-audioclient_activation_type), [AUDIOCLIENT_PROCESS_LOOPBACK_PARAMS](https://learn.microsoft.com/en-us/windows/win32/api/audioclientactivationparams/ns-audioclientactivationparams-audioclient_process_loopback_params), [PROCESS_LOOPBACK_MODE](https://learn.microsoft.com/en-us/windows/win32/api/audioclientactivationparams/ne-audioclientactivationparams-process_loopback_mode)
- [Application Loopback API Capture Sample](https://learn.microsoft.com/en-us/samples/microsoft/windows-classic-samples/applicationloopbackaudio-sample/), Code in [Windows-classic-samples](https://github.com/microsoft/Windows-classic-samples/tree/434f6002bdf9cf9829406c3ff2b33387982d6168/Samples/ApplicationLoopback)
- [Microsoft Support: App-Ton funktioniert nicht](https://support.microsoft.com/en-US/Windows/Hardware/audio/fix-app-audio-not-working-while-system-sounds-work-in-windows)

Treiber für virtuelle Audiogeräte:

- [VB-Audio VB-CABLE](https://vb-audio.com/Cable/), [VB-Audio Licensing](https://vb-audio.com/Services/licensing.htm), Forum [p=7128](https://forum.vb-audio.com/viewtopic.php?p=7128) und [p=6681](https://forum.vb-audio.com/viewtopic.php?p=6681)
- Virtual-Audio-Driver [bb34fba](https://github.com/VirtualDrivers/Virtual-Audio-Driver/tree/bb34fba15faf569a6ae9bdea360bc1cf4821354e), [Release 25.7.14](https://github.com/VirtualDrivers/Virtual-Audio-Driver/releases/tag/25.7.14), Issues [#7](https://github.com/VirtualDrivers/Virtual-Audio-Driver/issues/7), [#10](https://github.com/VirtualDrivers/Virtual-Audio-Driver/issues/10), [#23](https://github.com/VirtualDrivers/Virtual-Audio-Driver/issues/23)

Messung am PC: [`tools/Measure-ProcessLoopback.ps1`](tools/Measure-ProcessLoopback.ps1)
