@echo off
setlocal
title Questie Emberveil Installer

set "QEV_INSTALLER_PS1=%~dp0installer\Install-Questie-Emberveil.ps1"

rem Parse the complete installer with PowerShell's own AST parser before running it.
rem This specifically prevents a malformed .ps1 package from reaching the install path.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$tokens=$null;$errors=$null;$null=[System.Management.Automation.Language.Parser]::ParseFile($env:QEV_INSTALLER_PS1,[ref]$tokens,[ref]$errors);if($errors.Count -gt 0){Write-Host 'Questie Emberveil installer syntax validation FAILED.' -ForegroundColor Red;foreach($err in $errors){Write-Host ('  line ' + $err.Extent.StartLineNumber + ', col ' + $err.Extent.StartColumnNumber + ': ' + $err.Message) -ForegroundColor Red};exit 2}"
set "QEV_PARSE_EXIT=%ERRORLEVEL%"

if not "%QEV_PARSE_EXIT%"=="0" (
  echo.
  echo Questie Emberveil did not install because the installer script failed syntax validation.
  if not "%QEV_NO_PAUSE%"=="1" pause
  exit /b %QEV_PARSE_EXIT%
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%QEV_INSTALLER_PS1%" %*
set "QEV_EXIT=%ERRORLEVEL%"
echo.
if "%QEV_EXIT%"=="0" (
  echo Questie Emberveil finished successfully.
) else (
  echo Questie Emberveil did not install. Review the error above.
)
if not "%QEV_NO_PAUSE%"=="1" pause
exit /b %QEV_EXIT%
