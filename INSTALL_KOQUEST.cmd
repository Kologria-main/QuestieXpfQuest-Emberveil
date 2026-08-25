@echo off
setlocal
title KoQuest Installer

set "KOQUEST_INSTALLER_PS1=%~dp0installer\Install-Questie-Emberveil.ps1"

rem Parse the complete installer with PowerShell's own AST parser before running it.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$tokens=$null;$errors=$null;$null=[System.Management.Automation.Language.Parser]::ParseFile($env:KOQUEST_INSTALLER_PS1,[ref]$tokens,[ref]$errors);if($errors.Count -gt 0){Write-Host 'KoQuest installer syntax validation FAILED.' -ForegroundColor Red;foreach($err in $errors){Write-Host ('  line ' + $err.Extent.StartLineNumber + ', col ' + $err.Extent.StartColumnNumber + ': ' + $err.Message) -ForegroundColor Red};exit 2}"
set "KOQUEST_PARSE_EXIT=%ERRORLEVEL%"

if not "%KOQUEST_PARSE_EXIT%"=="0" (
  echo.
  echo KoQuest did not install because the installer script failed syntax validation.
  if not "%KOQUEST_NO_PAUSE%"=="1" pause
  exit /b %KOQUEST_PARSE_EXIT%
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%KOQUEST_INSTALLER_PS1%" %*
set "KOQUEST_EXIT=%ERRORLEVEL%"
echo.
if "%KOQUEST_EXIT%"=="0" (
  echo KoQuest finished successfully.
) else (
  echo KoQuest did not install. Review the error above.
)
if not "%KOQUEST_NO_PAUSE%"=="1" pause
exit /b %KOQUEST_EXIT%
