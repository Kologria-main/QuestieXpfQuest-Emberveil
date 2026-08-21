@echo off
setlocal
title Questie Emberveil Installer
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\Install-Questie-Emberveil.ps1" %*
set "QEV_EXIT=%ERRORLEVEL%"
echo.
if "%QEV_EXIT%"=="0" (
  echo Questie Emberveil finished successfully.
) else (
  echo Questie Emberveil did not install. Review the error above.
)
if not "%QEV_NO_PAUSE%"=="1" pause
exit /b %QEV_EXIT%
