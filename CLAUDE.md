# CLAUDE.md

ImAwake: a Windows PowerShell 5.1 console app that keeps Windows awake while its window is open.
It runs in a new Windows Terminal window opened by a desktop shortcut.

## Stack, branches, commands
- Stack: Windows PowerShell 5.1 + Pester 3.4 (both ship with Windows). No installs.
- No .exe: Smart App Control blocks unsigned executables on this PC. A Go version was dropped for this reason.
- Base branch: `main`. No remote.
- Full suite: `scripts/test.sh` (runs Pester in Windows from WSL; includes a real SetThreadExecutionState call).
- Coverage: `scripts/test.sh --coverage` (Pester `-CodeCoverage` on `src/*.psm1`).
- One test file: run `scripts/test.sh` after editing; Pester 3.4 has no single-test filter here.
- Lint: none. Mutation tool: none; break code by hand (global rule 6).
- Install on Windows: `scripts/install.sh` (copies `src/` to `%USERPROFILE%\Apps\ImAwake`, makes the desktop shortcut, adds `...\ImAwake\bin` to the user PATH; the old PATH goes to `%LOCALAPPDATA%\ImAwake\path-backup.txt`).
- Terminal command: `imawake` (run in this terminal), `imawake window` (new window), `imawake status`. Both start forms say so and stop when the app already runs. Exit codes: 0 ok/running, 1 not running, 2 wrong arguments, 3 failure.

## Rules
- `src/*.psm1` and `src/*.ps1` stay ASCII. PowerShell 5.1 reads a file without a BOM as ANSI; build glyphs with `[char]::ConvertFromUtf32`.
- `ImAwake.Core.psm1` and `ImAwake.Frame.psm1` are pure: no console, no clock, no Windows calls. Time comes in as `NowMs`.
- Every power call comes from the main loop thread. Never use jobs, runspaces or event actions for it.
- Pester 3.4 syntax: `Should Be`, no dash; no `BeforeAll`.

## Traps
- Windows Terminal resolves a bare `powershell.exe` through PATH; the shortcut uses the full path.
- `WScript.Shell.AppActivate` matches the title start. The title starts with the coffee glyph while running and with the sleeping glyph while paused.
- `powercfg /requests` needs admin; read the state with `CallNtPowerInformation(16)` instead.
- Only `bin\` is on PATH: in PowerShell a bare name finds `<name>.ps1` in a PATH folder before `.cmd`, so the app folder on PATH would run `ImAwake.ps1` in place.
- `bin\imawake.cmd` must keep CRLF (`.gitattributes`) and `exit /b %ERRORLEVEL%`.
- Write the user PATH through the registry with `DoNotExpandEnvironmentNames`; `[Environment]::SetEnvironmentVariable` expands `%VAR%` and changes the value type.
- Terminals already open keep the old PATH; Windows Terminal may need every window closed. The WSL shell never sees it.
- A named mutex `Local\ImAwake` allows one app per session; a second window says so and closes.
- `Win32_Process.CommandLine` is empty for a process with higher rights; such an app is not found by `imawake status`.
