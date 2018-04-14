@echo off
REM
REM Xbox App Settings Mod Script Launcher
REM v1.0
REM Date: 13/04/2018
REM Author: Pawel 'kaczorws' Koscielny
REM
REM ==============
REM
REM Check for admin rights hack by and31415
REM Original source:
REM https://stackoverflow.com/questions/4051883/batch-script-how-to-check-for-admin-rights/21295806#21295806
REM
fsutil dirty query %systemdrive% >nul
if not %errorlevel% == 0 (
    echo Running without administrator rights - please re-run start.bat as Administrator
	pause
	exit
)
REM
REM Correcting current directory after running as admin by Simon P Stevens
REM Original source:
REM https://www.codeproject.com/Tips/119828/Running-a-bat-file-as-administrator-Correcting-cur
REM
@setlocal enableextensions
@cd /d "%~dp0"

powershell.exe -File "./xboxappmod.ps1"