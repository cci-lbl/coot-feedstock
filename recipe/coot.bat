@echo off
:: Launcher for Coot on Windows. The autotools build installs the GUI as
:: WinCoot.exe in Library\bin with no wrapper, so this stands in for the
:: bin/coot shell script that Unix installs. It also works from a shell
:: where the environment is not activated.
setlocal
set "COOT_LIBRARY=%~dp0.."
for %%I in ("%COOT_LIBRARY%\..") do set "COOT_ENV=%%~fI"
if "%COOT_DATA_DIR%"=="" set "COOT_DATA_DIR=%COOT_LIBRARY%\share\coot"
if "%COOT_PREFIX%"=="" set "COOT_PREFIX=%COOT_ENV%"
if "%SYMINFO%"=="" set "SYMINFO=%COOT_LIBRARY%\share\coot\data\syminfo.lib"
:: The embedded interpreter only sets its own home for a POSIX
:: lib/python3.X layout; point CPython at the environment explicitly.
if "%PYTHONHOME%"=="" set "PYTHONHOME=%COOT_ENV%"
set "PATH=%COOT_ENV%;%COOT_LIBRARY%\bin;%PATH%"
set LC_ALL=C
set LANG=C
"%~dp0WinCoot.exe" %*
endlocal
