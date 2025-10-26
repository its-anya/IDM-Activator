@echo off
:: IDM Activation Script Launcher
:: This script downloads and runs the latest version of the IDM Activator

title IDM Activation Script Launcher
color 0A
cls

echo ==================================================
echo    IDM Activation Script Launcher
echo ==================================================
echo.
echo Downloading and running the latest IDM Activator...
echo.

:: PowerShell command to download and execute the script
powershell -Command " irm https://raw.githubusercontent.com/its-anya/IDM-Activator/refs/heads/main/install.ps1 | iex"

echo.
echo ==================================================
echo    Process completed
echo ==================================================
echo.
echo Press any key to exit...
pause >nul
exit