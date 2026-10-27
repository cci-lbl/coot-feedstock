@echo off
:: gtk4 on win-64 installs GSettings schema XML without gschemas.compiled,
:: and GTK's file chooser aborts without it. Compile the schemas now.
if exist "%PREFIX%\Library\bin\glib-compile-schemas.exe" (
  "%PREFIX%\Library\bin\glib-compile-schemas.exe" "%PREFIX%\Library\share\glib-2.0\schemas" >> "%PREFIX%\.messages.txt" 2>&1
)
exit /b 0
