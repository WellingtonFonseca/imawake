#!/usr/bin/env bash
# Installs ImAwake on Windows from WSL: runs scripts/install.ps1 with Windows PowerShell.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
win_tmp="$(wslpath "$(cd /mnt/c && cmd.exe /c 'echo %TEMP%' 2>/dev/null | tr -d '\r')")"
work="$win_tmp/imawake-install"
trap 'rm -rf "$work"' EXIT

rm -rf "$work"
mkdir -p "$work"
cp -r "$root/src" "$root/scripts" "$work/"

cd /mnt/c
powershell.exe -NoProfile -ExecutionPolicy Bypass \
	-File "$(wslpath -w "$work/scripts/install.ps1")" -SourceDir "$(wslpath -w "$work/src")"
