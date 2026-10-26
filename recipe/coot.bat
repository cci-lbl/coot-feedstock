@echo off
:: Launcher for Coot on Windows. The autotools build installs the GUI as
:: WinCoot.exe in Library\bin with no wrapper, so this stands in for the
:: bin/coot shell script that Unix installs.
setlocal
set "COOT_LIBRARY=%~dp0.."
if "%COOT_DATA_DIR%"=="" set "COOT_DATA_DIR=%COOT_LIBRARY%\share\coot"
if "%COOT_PREFIX%"=="" set "COOT_PREFIX=%COOT_LIBRARY%\.."
if "%SYMINFO%"=="" set "SYMINFO=%COOT_LIBRARY%\share\coot\data\syminfo.lib"
set LC_ALL=C
set LANG=C
"%~dp0WinCoot.exe" %*
endlocal
