#!/usr/bin/env bash
# Runs the Pester 3.4 tests in Windows PowerShell 5.1 from WSL.
# The files are copied to a Windows folder first, because PowerShell treats
# the \\wsl.localhost share as a remote zone.
# Usage: scripts/test.sh [--coverage]
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
win_tmp="$(wslpath "$(cd /mnt/c && cmd.exe /c 'echo %TEMP%' 2>/dev/null | tr -d '\r')")"
work="$win_tmp/imawake-dev"
trap 'rm -rf "$work"' EXIT

rm -rf "$work"
mkdir -p "$work"
cp -r "$root/src" "$root/tests" "$work/"

coverage=""
if [[ "${1:-}" == "--coverage" ]]; then
	coverage="-CodeCoverage (Get-ChildItem '$(wslpath -w "$work/src")\\*.psm1').FullName"
fi

cd /mnt/c
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \
	"Import-Module Pester -RequiredVersion 3.4.0; Invoke-Pester -Script '$(wslpath -w "$work/tests")' -EnableExit $coverage"
