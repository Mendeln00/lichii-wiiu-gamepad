# Lichii lokal bauen (Windows)

Wozu: einen Fix an Lichii am PC prüfen, bevor er als PR upstream geht, etwa mit dem DSU‑Testserver (`tools/Start-DsuTestServer.ps1`). Erstmals genutzt für #62 (Lichii#2675, Touch per DSU). Stand 2026‑11‑28, Lichii `nx2` d17f0ee.

Lichii wird dabei nicht gepatcht (ADR 0002): Der lokale Build dient nur zum Testen eines Upstream‑PRs. Gespielt wird weiter mit dem installierten Lichii.

## Werkzeuge

Gleiche Versionen wie Lichiis CI (Job „Windows clang-cl production build and tests“ in [`.github/workflows/build-check.yml`](https://github.com/zortos293/Lichii/blob/d17f0eee8befc4de714c16dcd47c9aa1fdbd941b/.github/workflows/build-check.yml)):

| Werkzeug | Version | Woher | Ort |
|---|---|---|---|
| Visual Studio 2022 Build Tools | 17.14, MSVC 14.44, Windows SDK 10.0.26100 | winget, Paket `Microsoft.VisualStudio.2022.BuildTools` | `C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools` |
| LLVM (clang-cl, lld-link) | 22.1.8 | GitHub‑Release von LLVM, SHA256 wie in Lichiis `tools/windows/install-llvm.ps1` | `local/tools/llvm` |
| Vulkan SDK (für `glslangValidator`) | 1.4.341.1 | sdk.lunarg.com, signiert von LunarG | `local/tools/VulkanSDK` |
| CMake, Ninja | 4.4.5, 1.13.2 | pip in einem venv | `local/tools/venv` |

- Die Build Tools 2019 reichen nicht. Lichii braucht die STL von MSVC 14.44.
- Qt ist nicht nötig, solange `eden-cli` und die Tests genügen (`-DENABLE_QT=OFF`). Für die Qt‑Oberfläche braucht es Qt 6.8.3 (msvc2022_64), siehe Lichiis `docs/Build.md`.
- Der Vulkan‑Installer braucht Adminrechte. Mit `copy_only=1` setzt er keine Umgebungsvariablen und ändert den `PATH` nicht.
- `local/` ignoriert git. Dort liegen auch die Installer (`local/downloads`) und der Clone (`local/lichii`). Platz: etwa 2,8 GB für LLVM, 2,1 GB für das Vulkan SDK und 1,2 GB für Build und CPM‑Cache, dazu die Build Tools auf C:.

Installation, je in PowerShell im Wurzelordner des Repos. Die Installer liegen vorher in `local/downloads`, LLVM von `https://github.com/llvm/llvm-project/releases/download/llvmorg-22.1.8/LLVM-22.1.8-win64.exe`, das Vulkan SDK von `https://sdk.lunarg.com/sdk/download/1.4.341.1/windows/vulkansdk-windows-X64-1.4.341.1.exe`.

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools --exact --source winget --override "--wait --passive --norestart --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.26100 --add Microsoft.VisualStudio.Component.VC.CMake.Project"
```

```powershell
Start-Process -Wait -FilePath .\local\downloads\llvm\LLVM-22.1.8-win64.exe -ArgumentList '/S', "/D=$PWD\local\tools\llvm"
```

```powershell
Start-Process -Verb RunAs -Wait -FilePath .\local\downloads\vulkan\vulkansdk-windows-X64-1.4.341.1.exe -ArgumentList '--root', "`"$PWD\local\tools\VulkanSDK`"", '--accept-licenses', '--default-answer', '--confirm-command', 'install', 'copy_only=1'
```

```powershell
python -m venv local\tools\venv; local\tools\venv\Scripts\python -m pip install cmake ninja
```

## Quelle

```powershell
git clone --filter=blob:none --branch nx2 https://github.com/zortos293/Lichii.git local\lichii
```

Der Fix kommt auf einen eigenen Branch im Clone. PRs gehen über den Fork [`Mendeln00/Lichii`](https://github.com/Mendeln00/Lichii), im Clone als Remote `fork` eingetragen, gegen `nx2`. Beispiel: [zortos293/Lichii#2681](https://github.com/zortos293/Lichii/pull/2681) für #62. Lichiis CI läuft für PRs aus dem Fork erst, wenn ein Maintainer sie freigibt.

## Umgebung laden

Jede Shell, die baut, braucht die MSVC‑Umgebung und die Werkzeuge im `PATH`:

```powershell
$vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -version '[17.0,18.0)' -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
cmd /c "`"$vs\VC\Auxiliary\Build\vcvarsall.bat`" x64 >nul && set" | ForEach-Object { if ($_ -match '^(.*?)=(.*)$') { [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process') } }
$env:LLVM_ROOT = "$PWD\local\tools\llvm"
$env:PATH = "$PWD\local\tools\venv\Scripts;$env:LLVM_ROOT\bin;$PWD\local\tools\VulkanSDK\Bin;$env:PATH"
Set-Location local\lichii
```

`vcvarsall.bat` meldet dabei, `vswhere.exe` sei nicht zu finden. Das stört nicht.

## Konfigurieren und bauen

Wie die CI, nur ohne Qt und ohne ccache:

```powershell
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release "-DCMAKE_C_COMPILER=$env:LLVM_ROOT/bin/clang-cl.exe" "-DCMAKE_CXX_COMPILER=$env:LLVM_ROOT/bin/clang-cl.exe" "-DCMAKE_LINKER=$env:LLVM_ROOT/bin/lld-link.exe" "-DCMAKE_AR=$env:LLVM_ROOT/bin/llvm-lib.exe" "-DCMAKE_C_FLAGS=-DWIN32 -D_WINDOWS -DNOMINMAX" "-DCMAKE_CXX_FLAGS=-DWIN32 -D_WINDOWS -EHsc -DNOMINMAX" -DENABLE_WERROR=ON -DBUILD_TESTING=ON -DLICHII_TESTS=ON -DENABLE_QT=OFF -DLICHII_CMD=ON -DLICHII_ROOM=OFF -DLICHII_ROOM_STANDALONE=OFF -DLICHII_USE_BUNDLED_SDL3=ON -DUSE_DISCORD_PRESENCE=OFF -DUSE_CCACHE=OFF
```

```powershell
cmake --build build --parallel
```

Auf diesem PC (8 Threads) dauert das Konfigurieren etwa 2 Minuten, der erste Build etwa 25 Minuten. Danach baut Ninja nur, was sich ändert. Das Leerzeichen im Pfad (`WiiU Gamepad Claude`) hat nicht gestört.

## Tests

```powershell
.\build\bin\tests.exe "[input_common]"
```

```powershell
ctest --test-dir build --output-on-failure --no-tests=error --parallel 8
```

Fragt Windows beim ersten Lauf nach Netzwerkzugriff für `tests.exe`, darf man ablehnen. Die Regeln gelten nicht für Loopback, die UDP‑Tests nutzen nur `127.0.0.1`.

## Portabel starten, ohne die echten Daten

Liegt neben der exe ein Ordner `user`, nimmt Lichii ihn statt `%APPDATA%\lichii` ([path_util.cpp L109‑L122](https://github.com/zortos293/Lichii/blob/d17f0eee8befc4de714c16dcd47c9aa1fdbd941b/src/common/fs/path_util.cpp#L109-L122)). So bleiben Konfiguration, Spielstände und Caches des installierten Lichii unberührt. In `build\bin\user\keys` gehören nur `prod.keys` und `title.keys` aus `%APPDATA%\lichii\keys`. Keys bleiben in `local/`, nie ins Repo.

`eden-cli` bekommt eine eigene Konfigurationsdatei, etwa `local\touch-test\sdl-config.ini`. `eden-cli.exe --config <Datei> -h` legt sie an, das Host‑Modul füllt sie (`Set-LichiiGamepadLichiiConfig` und `Set-LichiiGamepadInputProfile`, je mit `-LichiiConfigPath <Datei>`). Handheld ist dort schon Standard (`use_docked_mode=0`).

## Spieltest mit dem DSU‑Testserver

Wie in #60, jeder Befehl in einem eigenen PowerShell‑Fenster:

```powershell
& .\research\tools\Start-DsuTestServer.ps1 -Keyboard
```

```powershell
& .\local\lichii\build\bin\eden-cli.exe --config .\local\touch-test\sdl-config.ini -g "<Pfad zum Spiel>"
```

Für Touch: im Spiel eine Stelle in der Bildmitte suchen, die auf einen Mausklick reagiert, dann im Fenster des Servers P drücken (`Touch=960,470`). Auch für `eden-cli.exe` fragt Windows nach Netzwerkzugriff, Ablehnen stört den Test nicht.
