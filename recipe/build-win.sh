#!/bin/bash
# Windows build of coot under MSYS2 bash (m2-bash), called from bld.bat.
#
# Mirrors build.sh with these differences:
#   - MinGW-w64 GCC from gcc_win-64 / gxx_win-64 instead of MSVC
#   - boost, rdkit, and gemmi are built here and vendored, because the
#     conda-forge copies are MSVC builds that MinGW cannot link
#   - no guile, no vte (Python console and AI tab are absent on Windows)
# See docs/superpowers/specs/2026-10-26-windows-mingw-build-design.md.

set -e
set -o pipefail

CORES=${CPU_COUNT:-4}

# conda-build passes Windows paths. MSYS2 tools and autotools want /c/...,
# native cmake wants C:/... (cygpath -m).
LP_U=$(cygpath -u "$LIBRARY_PREFIX")
LP_M=$(cygpath -m "$LIBRARY_PREFIX")
SRC_U=$(cygpath -u "$SRC_DIR")
RECIPE_U=$(cygpath -u "$RECIPE_DIR")

# gcc_win-64's activation sets CC and gxx_win-64 sets CXX; be explicit so
# every sub-build agrees, and tell autotools this is a MinGW target even
# though the shell is MSYS.
TRIPLET=x86_64-w64-mingw32
export CC=${CC:-$TRIPLET-gcc.exe}
export CXX=${CXX:-$TRIPLET-g++.exe}
for tool in ar ranlib nm strip; do
  if command -v "$TRIPLET-$tool" >/dev/null 2>&1; then
    export "$(echo "$tool" | tr '[:lower:]' '[:upper:]')=$TRIPLET-$tool"
  fi
done
CONFIGURE_HOST="--build=$TRIPLET --host=$TRIPLET"

export CPPFLAGS="-I$LP_U/include ${CPPFLAGS:-}"
export LDFLAGS="-L$LP_U/lib ${LDFLAGS:-}"
export PKG_CONFIG_PATH="$LP_U/lib/pkgconfig:$LP_U/share/pkgconfig"

cd "$SRC_U"

echo "Toolchain"
echo "========="
$CC --version | head -1
$CXX --version | head -1
cmake --version | head -1
echo "LIBRARY_PREFIX: $LP_U"
echo "pkg-config --cflags gtk4: $(pkg-config --cflags gtk4)"
echo

# glm ships no pkg-config file; write one the way build.sh does.
echo "Creating glm.pc"
mkdir -p "$LP_U/share/pkgconfig"
echo "prefix=$LP_M" > "$LP_U/share/pkgconfig/glm.pc"
cat "$RECIPE_U/glm.pc" >> "$LP_U/share/pkgconfig/glm.pc"

# Modern config.sub for the autotools packages (the triplet above must be
# recognized).
for d in fftw mmdb2 ssm libccp4 clipper coot; do
  if [[ -f "$d/config.sub" ]]; then
    cp "$RECIPE_U/patches/config.sub" "$d/config.sub"
  elif [[ -d "$d/build-aux" ]]; then
    cp "$RECIPE_U/patches/config.sub" "$d/build-aux/config.sub"
  fi
done

echo "Building fftw"
echo "============="
cd fftw
./configure $CONFIGURE_HOST --prefix="$LP_U" --enable-shared --disable-static --enable-float
# fftw 2.1.5 ships libtool 1.4.3, which cannot link MinGW DLLs on its own.
# These are WinCoot's fftw-2.1.5_shared2.patch and
# fix_shared_makefiles_fftw.sh, applied to the generated files.
sed -i 's/^\( *\)compiler_flags=$/\1compiler_flags=-shared/' libtool
sed -i 's?-version-info?-no-undefined -version-info?' fftw/Makefile rfftw/Makefile
sed -i 's?^librfftw_la_LIBADD =.*?librfftw_la_LIBADD = ../fftw/libfftw.la?' rfftw/Makefile
make -j "$CORES"
make install
cd ..
echo

echo "Building mmdb2"
echo "=============="
cd mmdb2
patch -p1 < "$RECIPE_U/patches/mmdb2-mingw-io-file.patch"
./configure $CONFIGURE_HOST --prefix="$LP_U" --enable-shared --disable-static
make -j "$CORES"
make install
cd ..
echo

echo "Building ssm"
echo "============"
cd ssm
./configure $CONFIGURE_HOST --prefix="$LP_U" --enable-shared --disable-static
make -j "$CORES"
make install
cd ..
echo

echo "Building libccp4"
echo "================"
cd libccp4
CFLAGS="${CFLAGS:-} -Wno-error=incompatible-pointer-types" \
  ./configure $CONFIGURE_HOST --prefix="$LP_U" --enable-shared --disable-static --disable-fortran
make -j "$CORES"
make install
cd ..
echo

echo "Building clipper"
echo "================"
cd clipper
patch -p1 < "$RECIPE_U/patches/clipper-mingw-sysdep.patch"
patch -p1 < "$RECIPE_U/patches/clipper-mingw-addatom.patch"
# clipper's Makefile.am files lack -no-undefined, which libtool needs to
# build DLLs; passing it through LDFLAGS reaches every link line.
LDFLAGS="$LDFLAGS -no-undefined" ./configure $CONFIGURE_HOST \
  --prefix="$LP_U" \
  --enable-mmdb="$LP_U" \
  --enable-ccp4="$LP_U" \
  --enable-shared --disable-static \
  --enable-mmdb \
  --enable-cif \
  --enable-ccp4 \
  --enable-minimol \
  --enable-cns
make -j "$CORES"
make install
cd ..
echo

pkg-config --list-all
cp "$LP_U/lib/pkgconfig/ccp4c.pc" "$LP_U/lib/pkgconfig/libccp4c.pc"
ls "$LP_U/bin" | grep -iE "fftw|mmdb|ssm|ccp4|clipper" || true

echo "Building boost"
echo "=============="
echo "Stopping here: later stages are added task by task on the win2 branch."
exit 0
