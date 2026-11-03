@echo on
:: Delegate the Windows build to MSYS2 bash (m2-bash). The real work lives
:: in build-win.sh next to this file; meta.yaml lists the m2-* tools and
:: the gcc_win-64 / gxx_win-64 compilers it needs under [win].
set "RECIPE_DIR_FWD=%RECIPE_DIR:\=/%"
bash -e "%RECIPE_DIR_FWD%/build-win.sh"
if errorlevel 1 exit 1
