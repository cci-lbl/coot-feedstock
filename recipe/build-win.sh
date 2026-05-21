#!/bin/bash
# Windows build of coot under MSYS2 bash, invoked from bld.bat.
# Mirrors the Unix build.sh but adapted for MinGW conventions:
#   - import libraries are libfoo.dll.a (not libfoo.dylib / .so)
#   - no Guile (not viable on Windows)
#   - GTK4 (not GTK2 like upstream's build-it-win)
#   - extra patches for fftw and clipper to actually link as shared DLLs

set -e

CORES=4

# Convert PREFIX / SRC_DIR / RECIPE_DIR from native Windows paths to
# MSYS2 unix-style so autotools handles them correctly.
PREFIX="$(cygpath -u "$PREFIX")"
SRC_DIR="$(cygpath -u "$SRC_DIR")"
RECIPE_DIR="$(cygpath -u "$RECIPE_DIR")"

cd "$SRC_DIR"

# MinGW import-library suffix. CMake's find_library uses this when
# linking against shared DLL builds.
SHLIB_EXT="dll.a"

# patch glm pkg-config
echo "Creating glm.pc"
mkdir -p ${PREFIX}/share/pkgconfig
echo "prefix=${PREFIX}" > ${PREFIX}/share/pkgconfig/glm.pc
cat ${RECIPE_DIR}/glm.pc >> ${PREFIX}/share/pkgconfig/glm.pc

export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig:${PREFIX}/share/pkgconfig

echo "Building dependencies"
echo "====================="
echo

# Refresh stale config.sub copies (some of these tarballs predate arm64
# and modern triplets).
for d in fftw mmdb2 ssm libccp4 clipper coot; do
  echo "Checking ${d}"
  if [[ -f "${d}/config.sub" ]]; then
    cp ${RECIPE_DIR}/patches/config.sub ${d}/config.sub
  elif [[ -d "${d}/build-aux" ]]; then
    cp ${RECIPE_DIR}/patches/config.sub ${d}/build-aux/config.sub
  fi
done

# maeparser
echo "Building maeparser"
cd maeparser
mkdir -p build
cd build
cmake -DCMAKE_INSTALL_PREFIX=${PREFIX} \
      -DMAEPARSER_BUILD_TESTS=OFF \
      -G "MSYS Makefiles" ..
make -j ${CORES} && make install
cd ../..

# coordgenlibs
echo "Building coordgenlibs"
cd coordgenlibs
mkdir -p build
cd build
cmake -DCMAKE_INSTALL_PREFIX=${PREFIX} \
      -DCOORDGEN_USE_MAEPARSER=ON \
      -DCOORDGEN_BUILD_TESTS=OFF \
      -DCOORDGEN_BUILD_EXAMPLE=OFF \
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
      -G "MSYS Makefiles" ..
make -j ${CORES} && make install
cd ../..

# fftw (float)
# NEEDS: recipe/patches/fftw-2.1.5_shared.patch from
# bernhardcl/coot@gtk4 to actually build shared DLLs on MinGW.
echo "Building fftw"
cd fftw
if [[ -f "${RECIPE_DIR}/patches/fftw-2.1.5_shared.patch" ]]; then
  patch -p1 < ${RECIPE_DIR}/patches/fftw-2.1.5_shared.patch
fi
./configure --prefix=${PREFIX} --enable-shared --disable-static --enable-float
make -j ${CORES}
make install
cd ..
echo

# mmdb2
echo "Building mmdb2"
cd mmdb2
./configure --prefix=${PREFIX} --enable-shared --disable-static
make -j ${CORES}
make install
cd ..
echo

# ssm
echo "Building ssm"
cd ssm
CPPFLAGS="-I${PREFIX}/include" LDFLAGS="-L${PREFIX}/lib" \
  ./configure --prefix=${PREFIX} --enable-shared --disable-static
make -j ${CORES}
make install
cd ..
echo

# libccp4
echo "Building libccp4"
cd libccp4
CFLAGS="${CFLAGS:-} -Wno-error=incompatible-pointer-types" \
  ./configure --prefix=${PREFIX} --enable-shared --disable-static
make -j ${CORES}
make install
cd ..
echo

# clipper
# NEEDS: recipe/patches/clipper_win64.patch and clipper-configure-2.patch
# from bernhardcl/coot@gtk4. Upstream disables threading on Windows
# ("no clean exit from WinCoot") - if you hit hang-on-quit, that's why.
echo "Building clipper"
cd clipper
if [[ -f "${RECIPE_DIR}/patches/clipper-configure-2.patch" ]]; then
  patch -p1 < ${RECIPE_DIR}/patches/clipper-configure-2.patch
fi
if [[ -f "${RECIPE_DIR}/patches/clipper_win64.patch" ]]; then
  patch -p1 < ${RECIPE_DIR}/patches/clipper_win64.patch
fi
./configure \
  --prefix=${PREFIX} \
  --enable-mmdb=${PREFIX} \
  --enable-ccp4=${PREFIX} \
  --enable-shared --disable-static \
  --enable-mmdb \
  --enable-cif \
  --enable-ccp4 \
  --enable-minimol \
  --enable-cns \
  CXXFLAGS="-g -O2 -fno-strict-aliasing"
make -j ${CORES}
make install
cd ..
echo

# debug info
pkg-config --list-all
cp $PKG_CONFIG_PATH/ccp4c.pc $PKG_CONFIG_PATH/libccp4c.pc

# coot autotools (GUI)
# Differences from build.sh: no --with-guile (Guile on Windows is not
# viable; rely on Python scripting).
echo "Building coot"
echo "============="
echo
cd coot
rm -rf autom4te.cache
if [ -e ltmain.sh    ] ; then rm ltmain.sh    ; fi
if [ -e config.guess ] ; then rm config.guess ; fi
./autogen.sh
./configure \
  --prefix=${PREFIX} \
  --disable-static \
  --with-backward \
  --with-boost=${PREFIX} \
  --with-boost-libdir=${PREFIX}/lib \
  --with-enhanced-ligand-tools \
  --with-fftw-prefix=${PREFIX} \
  --with-gemmi=${PREFIX} \
  --with-glm=${PREFIX} \
  --with-rdkit-prefix=${PREFIX} \
  --with-python \
  --with-glib-prefix=${PREFIX} \
  --with-gtk-prefix=${PREFIX}
make -j ${CORES}
make install
cd ..
echo

# coot CMake build (libcootapi + coot_headless_api + MCP files)
echo "Building cootapi via CMake"
echo "=========================="
echo
cd coot
mkdir -p build-cmake
cd build-cmake
cmake \
  -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DCMAKE_BUILD_TYPE=Release \
  -DPython_EXECUTABLE=${PREFIX}/python.exe \
  -DMMDB2_LIBRARY=${PREFIX}/lib/libmmdb2.${SHLIB_EXT} \
  -DMMDB2_INCLUDE_DIR=${PREFIX}/include \
  -DSSM_LIBRARY=${PREFIX}/lib/libssm.${SHLIB_EXT} \
  -DSSM_INCLUDE_DIR=${PREFIX}/include \
  -DCCP4C_LIBRARY=${PREFIX}/lib/libccp4c.${SHLIB_EXT} \
  -DCLIPPER-CORE_LIBRARY=${PREFIX}/lib/libclipper-core.${SHLIB_EXT} \
  -DCLIPPER-CORE_INCLUDE_DIR=${PREFIX}/include \
  -DCLIPPER-CCP4_LIBRARY=${PREFIX}/lib/libclipper-ccp4.${SHLIB_EXT} \
  -DCLIPPER-CCP4_INCLUDE_DIR=${PREFIX}/include \
  -DCLIPPER-MMDB_LIBRARY=${PREFIX}/lib/libclipper-mmdb.${SHLIB_EXT} \
  -DCLIPPER-MMDB_INCLUDE_DIR=${PREFIX}/include \
  -DCLIPPER-CIF_LIBRARY=${PREFIX}/lib/libclipper-cif.${SHLIB_EXT} \
  -DCLIPPER-CIF_INCLUDE_DIR=${PREFIX}/include \
  -DCLIPPER-CONTRIB_LIBRARY=${PREFIX}/lib/libclipper-contrib.${SHLIB_EXT} \
  -DCLIPPER-CONTRIB_INCLUDE_DIR=${PREFIX}/include \
  -DCLIPPER-MINIMOL_LIBRARY=${PREFIX}/lib/libclipper-minimol.${SHLIB_EXT} \
  -DCLIPPER-MINIMOL_INCLUDE_DIR=${PREFIX}/include \
  -DFFTW2_LIBRARY=${PREFIX}/lib/libfftw.${SHLIB_EXT} \
  -DRFFTW2_LIBRARY=${PREFIX}/lib/librfftw.${SHLIB_EXT} \
  -DFFTW2_INCLUDE_DIRS=${PREFIX}/include \
  -G "MSYS Makefiles" \
  ..
make -j ${CORES}
make install
cd ../..
echo

# Replace the CMake-installed monomers (coot's own bundled set) with
# the refmac-monomer-library tarball.
mkdir -p ${PREFIX}/share/coot/lib/data
rm -rf ${PREFIX}/share/coot/lib/data/monomers
cp -r monomers ${PREFIX}/share/coot/lib/data/monomers

# reference-structures isn't installed by either build system.
cp -r reference-structures ${PREFIX}/share/coot/reference-structures

# Install activate/deactivate scripts (both sh and bat - conda on
# Windows scans both depending on which shell is in use).
mkdir -p ${PREFIX}/etc/conda/activate.d
mkdir -p ${PREFIX}/etc/conda/deactivate.d
cp ${RECIPE_DIR}/coot-activate.sh   ${PREFIX}/etc/conda/activate.d/coot-activate.sh
cp ${RECIPE_DIR}/coot-deactivate.sh ${PREFIX}/etc/conda/deactivate.d/coot-deactivate.sh
cp ${RECIPE_DIR}/coot-activate.bat   ${PREFIX}/etc/conda/activate.d/coot-activate.bat
cp ${RECIPE_DIR}/coot-deactivate.bat ${PREFIX}/etc/conda/deactivate.d/coot-deactivate.bat
