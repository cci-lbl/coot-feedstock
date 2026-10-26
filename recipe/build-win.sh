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
# native programs (cmake, b2, python) want C:/... (cygpath -m).
PREFIX_U=$(cygpath -u "$PREFIX")
PREFIX_M=$(cygpath -m "$PREFIX")
LP_U=$(cygpath -u "$LIBRARY_PREFIX")
LP_M=$(cygpath -m "$LIBRARY_PREFIX")
SRC_U=$(cygpath -u "$SRC_DIR")
RECIPE_U=$(cygpath -u "$RECIPE_DIR")
SP_U=$(cygpath -u "$SP_DIR")
PY_VER_NODOT=${PY_VER//./}

# gcc_win-64's activation sets CC and gxx_win-64 sets CXX; be explicit so
# every sub-build agrees. Coot's own Windows switch (macros/coot-windows.m4)
# keys on --build, so every configure gets both --build and --host.
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
echo "SP_DIR: $SP_U"
echo "pkg-config --cflags gtk4: $(pkg-config --cflags gtk4)"
echo

# glm ships no pkg-config file; write one the way build.sh does.
echo "Creating glm.pc"
mkdir -p "$LP_U/share/pkgconfig"
echo "prefix=$LP_M" > "$LP_U/share/pkgconfig/glm.pc"
cat "$RECIPE_U/glm.pc" >> "$LP_U/share/pkgconfig/glm.pc"

# Modern config.sub for the autotools packages (the triplet above must be
# recognized).
for d in mmdb2 ssm libccp4 clipper coot; do
  if [[ -f "$d/config.sub" ]]; then
    cp "$RECIPE_U/patches/config.sub" "$d/config.sub"
  elif [[ -d "$d/build-aux" ]]; then
    cp "$RECIPE_U/patches/config.sub" "$d/build-aux/config.sub"
  fi
done

echo "Building fftw"
echo "============="
cd fftw
# fftw 2.1.5 ships libtool 1.4.3, which only knows 32-bit MinGW and quietly
# produces static archives. Regenerate libtool, configure, and the
# Makefiles with the MSYS2 autotools; autoheader is skipped because the
# shipped config.h.in predates templates it now insists on. Then link
# librfftw against libfftw so -no-undefined holds.
libtoolize --force --copy
aclocal
autoconf
automake --add-missing --copy --force-missing
./configure $CONFIGURE_HOST --prefix="$LP_U" --enable-shared --disable-static --enable-float
sed -i 's?^librfftw_la_LIBADD =.*?librfftw_la_LIBADD = ../fftw/libfftw.la?' rfftw/Makefile
# -no-undefined is a libtool link flag; given at make time it reaches only
# libtool's link lines, whereas in configure's LDFLAGS the compiler checks
# would reject it.
make -j "$CORES" LDFLAGS="$LDFLAGS -no-undefined"
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
patch -p1 < "$RECIPE_U/patches/libccp4-mingw-stdint.patch"
# libccp4 declares putenv() and friends K&R style; under GCC 15's C23
# default an empty parameter list means (void) and conflicts with the
# MinGW prototypes, so build it as C17.
CFLAGS="${CFLAGS:-} -std=gnu17 -Wno-error=incompatible-pointer-types" \
  ./configure $CONFIGURE_HOST --prefix="$LP_U" --enable-shared --disable-static --disable-fortran
make -j "$CORES"
make install
cd ..
echo

echo "Building clipper"
echo "================"
cd clipper
patch -p1 < "$RECIPE_U/patches/clipper-mingw-sysdep.patch"
# clipper's Makefile.am files lack -no-undefined, which libtool needs to
# build DLLs; passing it at make time reaches every libtool link line.
./configure $CONFIGURE_HOST \
  --prefix="$LP_U" \
  --enable-shared --disable-static \
  --enable-mmdb \
  --enable-cif \
  --enable-ccp4 \
  --enable-minimol \
  --enable-cns
make -j "$CORES" LDFLAGS="$LDFLAGS -no-undefined"
make install
cd ..
echo

cp "$LP_U/lib/pkgconfig/ccp4c.pc" "$LP_U/lib/pkgconfig/libccp4c.pc"
echo "CCP4 stack DLLs:"
ls "$LP_U/bin" | grep -iE "fftw|mmdb|ssm|ccp4|clipper" || true
echo

echo "Building boost"
echo "=============="
cd boost
# bootstrap.sh clears CXX and probes a bare g++, which this toolchain does
# not provide, so build the b2 engine with our compiler and write the
# project configuration by hand. b2 is a native program: C:/ paths.
(cd tools/build/src/engine && ./build.sh --cxx="$CXX" gcc)
B2=tools/build/src/engine/b2
cat > project-config.jam <<JAM
using gcc : : $CXX ;
using python : $PY_VER : $PREFIX_M/python.exe : $PREFIX_M/include : $PREFIX_M/libs ;
JAM
$B2 -j "$CORES" toolset=gcc address-model=64 link=shared runtime-link=shared \
  variant=release threading=multi --layout=system \
  --with-python --with-thread --with-chrono --with-date_time --with-atomic \
  --with-serialization --with-iostreams --with-regex \
  -sZLIB_INCLUDE="$LP_M/include" -sZLIB_LIBRARY_PATH="$LP_M/lib" -sZLIB_NAME=zlib \
  -sNO_ZSTD=1 -sNO_LZMA=1 -sNO_BZIP2=1 \
  --prefix="$LP_M" install
cd ..
# b2 installs the DLLs beside the import libraries; Windows loads from bin.
mv "$LP_U"/lib/libboost_*.dll "$LP_U/bin/" 2>/dev/null || true
echo "boost DLLs:"
ls "$LP_U/bin" | grep -i boost || true
echo

echo "Building maeparser"
echo "=================="
cd maeparser
mkdir -p build && cd build
cmake -G "MSYS Makefiles" \
  -DCMAKE_INSTALL_PREFIX="$LP_M" -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
  -DMAEPARSER_BUILD_SHARED_LIBS=ON -DMAEPARSER_BUILD_TESTS=OFF \
  -DBOOST_ROOT="$LP_M" ..
make -j "$CORES"
make install
cd ../..
echo

echo "Building coordgenlibs"
echo "====================="
cd coordgenlibs
mkdir -p build && cd build
cmake -G "MSYS Makefiles" \
  -DCMAKE_INSTALL_PREFIX="$LP_M" -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
  -DCOORDGEN_BUILD_SHARED_LIBS=ON -DCOORDGEN_RIGOROUS_BUILD=OFF \
  -DCOORDGEN_USE_MAEPARSER=ON -DCOORDGEN_BUILD_TESTS=OFF -DCOORDGEN_BUILD_EXAMPLE=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_PREFIX_PATH="$LP_M" -Dmaeparser_DIR="$LP_M/lib/cmake" \
  -DBOOST_ROOT="$LP_M" ..
make -j "$CORES"
make install
cd ../..
echo

echo "Building rdkit"
echo "=============="
cd rdkit
mkdir -p build && cd build
# RDK_INSTALL_STATIC_LIBS defaults ON and on WIN32 that means static-only
# with no RDKIT_DYN_LINK; maeparser and coordgen export their configs to a
# bare lib/cmake. ChemDraw stays on because layla links it.
cmake -G "MSYS Makefiles" \
  -DCMAKE_INSTALL_PREFIX="$LP_M" -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
  -DCMAKE_PREFIX_PATH="$LP_M" \
  -Dmaeparser_DIR="$LP_M/lib/cmake" -Dcoordgen_DIR="$LP_M/lib/cmake" \
  -DBOOST_ROOT="$LP_M" \
  -DRDK_BUILD_PYTHON_WRAPPERS=OFF \
  -DRDK_INSTALL_INTREE=OFF \
  -DRDK_INSTALL_STATIC_LIBS=OFF \
  -DRDK_BUILD_CPP_TESTS=OFF \
  -DRDK_BUILD_DESCRIPTORS3D=OFF \
  -DRDK_OPTIMIZE_POPCNT=OFF \
  -DRDK_BUILD_INCHI_SUPPORT=OFF \
  -DRDK_BUILD_FREESASA_SUPPORT=OFF \
  -DRDK_BUILD_PUBCHEMSHAPE_SUPPORT=OFF \
  -DRDK_INSTALL_COMIC_FONTS=OFF \
  -DRDK_BUILD_COORDGEN_SUPPORT=ON \
  -DRDK_BUILD_MAEPARSER_SUPPORT=ON \
  -DRDK_BUILD_CHEMDRAW_SUPPORT=ON \
  -DRDK_USE_BOOST_SERIALIZATION=ON \
  -DRDK_USE_BOOST_IOSTREAMS=ON \
  -DRDK_BUILD_THREADSAFE_SSS=ON \
  ..
make -j "$CORES"
make install
cd ..
# rdkit installs DLLs to lib. Windows loads from bin, but Coot's CMake build
# consumes RDKit through its exported targets, whose config checks that the
# lib paths exist, so copy now and drop the lib copies in the final strip.
# The install list also omits a header that BoundsMatrixBuilder.h includes
# (rdkit PR #9434).
cp "$LP_U"/lib/libRDKit*.dll "$LP_U/bin/"
cp Code/GraphMol/DistGeomHelpers/BoundsMatrixBuilderDetails.h "$LP_U/include/rdkit/GraphMol/DistGeomHelpers/"
cd ..
echo "rdkit DLLs:"
ls "$LP_U/bin" | grep -i rdkit | head -5 || true
echo

echo "Building gemmi"
echo "=============="
cd gemmi
mkdir -p build && cd build
# No gemmi program: conda-forge's gemmi package also installs gemmi.exe.
cmake -G "MSYS Makefiles" \
  -DCMAKE_INSTALL_PREFIX="$LP_M" -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
  -DBUILD_SHARED_LIBS=ON -DUSE_PYTHON=OFF -DINSTALL_DEV_FILES=ON -DBUILD_GEMMI_PROGRAM=OFF \
  ..
make -j "$CORES"
make install
cd ../..
mv "$LP_U"/lib/libgemmi_cpp*.dll "$LP_U/bin/" 2>/dev/null || true
# gemmi ships no pkg-config file and Coot's configure probes gemmi.pc first.
cat > "$LP_U/lib/pkgconfig/gemmi.pc" <<PC
prefix=$LP_M
includedir=\${prefix}/include
libdir=\${prefix}/lib

Name: gemmi
Description: GEMMI macromolecular crystallography library
Version: 0.7.5
Cflags: -I\${includedir}
Libs: -L\${libdir} -lgemmi_cpp
PC
echo "gemmi DLLs:"
ls "$LP_U/bin" | grep -i gemmi || true
echo

echo "Building coot"
echo "============="
cd coot
rm -rf autom4te.cache
if [ -e ltmain.sh    ] ; then rm ltmain.sh    ; fi
if [ -e config.guess ] ; then rm config.guess ; fi
./autogen.sh
# conda's Windows python ships no python3-config, its sysconfig has no
# LIBS/LINKFORSHARED, and Coot's python.m4 would derive the install dirs
# through distutils, so every Python variable is preset. gsl.pc on win-64
# carries backslash paths that pkg-config mangles, so GSL is preset too.
./configure $CONFIGURE_HOST \
  --prefix="$LP_U" \
  --disable-static \
  --with-boost="$LP_U" \
  --with-boost-libdir="$LP_U/lib" \
  --with-boost-python="boost_python$PY_VER_NODOT" \
  --with-enhanced-ligand-tools \
  --with-fftw-prefix="$LP_U" \
  --with-gemmi="$LP_U" \
  --with-glm="$LP_U" \
  --with-rdkit-prefix="$LP_U" \
  --with-glib-prefix="$LP_U" \
  --with-gtk-prefix="$LP_U" \
  PYTHON="$PREFIX_M/python.exe" \
  PYTHON_CPPFLAGS="-I$PREFIX_M/include" \
  PYTHON_LIBS="-L$PREFIX_M/libs -lpython$PY_VER_NODOT" \
  PYTHON_EXTRA_LIBS="-lm" \
  PYTHON_EXTRA_LDFLAGS="-L$PREFIX_M/libs" \
  am_cv_python_pythondir="$SP_U" \
  am_cv_python_pyexecdir="$SP_U" \
  GSL_CFLAGS="-I$LP_M/include" \
  GSL_LIBS="-L$LP_M/lib -lgsl -lgslcblas" \
  CXXFLAGS="-O2 -Wa,-mbig-obj"
make -j "$CORES"
make install
cd ..
echo "Python modules:"
ls "$SP_U" | grep -i coot || true
echo

echo "Building cootapi via CMake"
echo "=========================="
cd coot
mkdir -p build-cmake && cd build-cmake
cmake -G "MSYS Makefiles" \
  -DCMAKE_INSTALL_PREFIX="$LP_M" -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
  -DCMAKE_PREFIX_PATH="$LP_M" \
  -DBOOST_ROOT="$LP_M" \
  -DPython_EXECUTABLE="$PREFIX_M/python.exe" \
  ..
make -j "$CORES"
make install
cd ../..
# The CMake build installs Python files to lib/python3.X/site-packages
# under the install prefix; conda's site-packages is elsewhere.
CMAKE_SP="$LP_U/lib/python$PY_VER/site-packages"
if [ -d "$CMAKE_SP" ]; then
  mkdir -p "$SP_U"
  cp -a "$CMAKE_SP"/. "$SP_U/"
  rm -rf "$LP_U/lib/python$PY_VER"
fi
rm -f "$LP_U"/lib/coot_headless_api*.pyd
echo "Python modules after CMake:"
ls "$SP_U" | grep -iE "coot|chapi" || true
echo

# Replace the CMake-installed monomers with the refmac monomer library
# and add reference-structures, as build.sh does.
mkdir -p "$LP_U/share/coot/lib/data"
rm -rf "$LP_U/share/coot/lib/data/monomers"
cp -r monomers "$LP_U/share/coot/lib/data/monomers"
rm -rf "$LP_U/share/coot/reference-structures"
cp -r reference-structures "$LP_U/share/coot/reference-structures"

# Launcher: the autotools build installs WinCoot.exe with no wrapper.
cp "$RECIPE_U/coot.bat" "$LP_U/bin/coot.bat"

# Activation scripts: conda on Windows runs .bat from cmd and .sh from
# bash-based shells, so install both. The .sh variant must point at
# Library/share/coot on Windows.
mkdir -p "$PREFIX_U/etc/conda/activate.d" "$PREFIX_U/etc/conda/deactivate.d"
sed 's|\$CONDA_PREFIX/share/coot|$CONDA_PREFIX/Library/share/coot|' "$RECIPE_U/coot-activate.sh" \
  > "$PREFIX_U/etc/conda/activate.d/coot-activate.sh"
cp "$RECIPE_U/coot-deactivate.sh"  "$PREFIX_U/etc/conda/deactivate.d/coot-deactivate.sh"
cp "$RECIPE_U/coot-activate.bat"   "$PREFIX_U/etc/conda/activate.d/coot-activate.bat"
cp "$RECIPE_U/coot-deactivate.bat" "$PREFIX_U/etc/conda/deactivate.d/coot-deactivate.bat"

# The vendored C++ stack ships as DLLs only. Its headers, import and static
# libraries, libtool and pkg-config files, and CMake configs would clobber
# conda-forge's boost, rdkit, and gemmi packages in the same environment,
# and nothing downstream consumes them. Every .la goes: libtool files embed
# the build-time /c/bld paths, which conda cannot relocate. The Unix shell
# wrappers (bin/coot, bin/coot-mini-rsr, ...) are useless on Windows.
echo "Removing vendored development files"
rm -rf "$LP_U"/include/{boost,rdkit,gemmi,clipper,mmdb2,ssm,ccp4,maeparser,coordgen}
rm -f  "$LP_U"/include/{fftw,rfftw,sfftw,srfftw,fftw_threads,rfftw_threads}.h
rm -f  "$LP_U"/lib/lib{boost_,RDKit,gemmi,clipper,mmdb2,ssm,ccp4c,fftw,rfftw,maeparser,coordgen}*.{a,dll.a,dll}
rm -f  "$LP_U"/lib/*.la
rm -rf "$LP_U"/lib/cmake/{rdkit,maeparser,coordgen,Boost,boost_,RDKit}* "$LP_U"/cmake/gemmi*
rm -f  "$LP_U"/lib/pkgconfig/{clipper,mmdb2,ssm,ccp4c,libccp4c,gemmi,fftw,rfftw,sfftw,srfftw}*.pc
rm -rf "$LP_U"/lib/rdkit
for f in "$LP_U"/bin/*; do
  if [ -f "$f" ] && [ "$(head -c 2 "$f" 2>/dev/null)" = "#!" ]; then rm -f "$f"; fi
done
echo "Library/bin after strip:"
ls "$LP_U/bin" | grep -iE "coot|RDKit|boost|gemmi|clipper|mmdb|ssm|ccp4|fftw" | head -60
echo
echo "Done"
