@echo off
rem Runs the imawake command; keeps the exit code for cmd and PowerShell.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\ImAwake.Cli.ps1" %*
exit /b %ERRORLEVEL%
