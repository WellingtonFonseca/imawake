#!/usr/bin/env bash
# Hand-made mutation test, run in Windows PowerShell 5.1 from WSL (see mutate.ps1).
# Each mutant of scripts/mutants.psd1 runs alone in its own folder; the folders go away at the end.
# The files are copied to a Windows folder first, as scripts/test.sh does.
# Usage: scripts/mutate.sh [jobs]      (jobs: mutants at the same time, default 4)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
win_tmp="$(wslpath "$(cd /mnt/c && cmd.exe /c 'echo %TEMP%' 2>/dev/null | tr -d '\r')")"
work="$win_tmp/imawake-mutate-root-$$"
trap 'rm -rf "$work"' EXIT

rm -rf "$work"
mkdir -p "$work"
cp -r "$root/src" "$root/scripts" "$root/tests" "$work/"

cd /mnt/c
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$work/scripts/mutate.ps1")" \
	-Root "$(wslpath -w "$work")" -Jobs "${1:-4}"
