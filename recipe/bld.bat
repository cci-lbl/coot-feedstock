@echo on
:: Delegate the Windows build to MSYS2 bash. The real work lives in
:: build-win.sh next to this file. Requires the following on the build
:: line in meta.yaml (selector [win]): m2-base, m2-bash, m2-make,
:: m2-autoconf, m2-automake, m2-libtool, m2-patch, m2-pkg-config.
bash -e %RECIPE_DIR%/build-win.sh
if errorlevel 1 exit 1
