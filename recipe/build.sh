#!/bin/bash

CORES=4

# https://conda-forge.org/docs/maintainer/knowledge_base/#newer-c-features-with-old-sdk
# if [[ ! -z "$MACOSX_DEPLOYMENT_TARGET" ]]; then
#   CXXFLAGS="${CXXFLAGS} -D_LIBCPP_DISABLE_AVAILABILITY"
# fi

# patch glm pkg-config
echo "Creating glm.pc"
mkdir -p ${PREFIX}/share/pkgconfig
ls ${PREFIX}/share/pkgconfig
echo "prefix=${PREFIX}" > ${PREFIX}/share/pkgconfig/glm.pc
cat ${RECIPE_DIR}/glm.pc >> ${PREFIX}/share/pkgconfig/glm.pc
ls ${PREFIX}/share/pkgconfig

export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig

echo "Building dependencies"
echo "====================="
echo

# use updated config.sub if present
for d in fftw mmdb2 ssm libccp4 clipper coot; do
  echo "Checking ${d}"
  echo "============="
  if [[ -f "${d}/config.sub" ]]; then
    cp ${RECIPE_DIR}/patches/config.sub ${d}/config.sub
    echo "Replacing ${d}/config.sub"
  elif [[ -d "${d}/build-aux" ]]; then
    cp ${RECIPE_DIR}/patches/config.sub ${d}/build-aux/config.sub
    echo "Replacing ${d}/build-aux/config.sub"
  else
    echo "${d}/config.sub is not present"
  fi
  echo "============="
  echo
done

# maeparser
echo "Building maeparser"
cd maeparser
mkdir -p build
cd build
cmake -DCMAKE_INSTALL_PREFIX=${PREFIX} -DMAEPARSER_BUILD_TESTS=OFF ..
make && make install
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
    ..
make && make install
cd ../..

# fftw
echo "Building fftw"
cd fftw
./configure --prefix=${PREFIX} --enable-shared --enable-float
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
./configure --prefix=${PREFIX} --enable-shared --disable-static
make -j ${CORES}
make install
cd ..
echo

# libccp4
echo "Building libccp4"
cd libccp4
CFLAGS="${CFLAGS} -Wno-error=incompatible-pointer-types" ./configure --prefix=${PREFIX} --enable-shared --disable-static
make -j ${CORES}
make install
cd ..
echo

# clipper
echo "Building clipper"
cd clipper
./configure \
  --prefix=${PREFIX} \
	--enable-mmdb=${PREFIX} \
	--enable-ccp4=${PREFIX} \
	--enable-shared  \
	--enable-mmdb    \
	--enable-cif     \
	--enable-ccp4    \
	--enable-minimol \
	--enable-cns
make -j ${CORES}
make install
cd ..
echo

# debug info
pkg-config --list-all
cp $PKG_CONFIG_PATH/ccp4c.pc $PKG_CONFIG_PATH/libccp4c.pc

# coot
echo "Building coot"
echo "============="
echo

cd coot

# automake (from build-it-3-3)
rm -rf autom4te.cache
if [ -e ltmain.sh    ] ; then rm ltmain.sh    ; fi
if [ -e config.guess ] ; then rm config.guess ; fi
# if [ -e config.sub   ] ; then rm config.sub   ; fi
./autogen.sh

./configure \
  --prefix=${PREFIX} \
  --disable-static \
  --with-backward \
  --with-boost=${PREFIX}  \
  --with-boost-libdir=${PREFIX}/lib  \
  --with-enhanced-ligand-tools \
  --with-fftw-prefix=${PREFIX} \
  --with-gemmi=${PREFIX} \
  --with-glm=${PREFIX} \
  --with-rdkit-prefix=${PREFIX} \
  --with-guile \
  --with-glib-prefix=${PREFIX} \
  --with-gtk-prefix=${PREFIX}
make -j ${CORES}
make install
cd ..
echo

# Also build libcootapi and coot_headless_api via CMake (alongside the
# autotools GUI build above). The autotools install path doesn't ship
# the headless API libraries, Python bindings, MCP socket bridge +
# skills, or public headers - upstream's CMake target covers those.
# Requires nanobind as a host dep in meta.yaml.
echo "Building cootapi via CMake"
echo "=========================="
echo
cd coot
mkdir -p build-cmake
cd build-cmake
cmake \
  -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DCMAKE_BUILD_TYPE=Release \
  -DPython_EXECUTABLE=${PREFIX}/bin/python \
  -DMMDB2_LIBRARY=${PREFIX}/lib/libmmdb2.dylib \
  -DMMDB2_INCLUDE_DIR=${PREFIX}/include \
  -DSSM_LIBRARY=${PREFIX}/lib/libssm.dylib \
  -DSSM_INCLUDE_DIR=${PREFIX}/include \
  -DCCP4C_LIBRARY=${PREFIX}/lib/libccp4c.dylib \
  -DCLIPPER-CORE_LIBRARY=${PREFIX}/lib/libclipper-core.dylib \
  -DCLIPPER-CORE_INCLUDE_DIR=${PREFIX}/include \
  -DCLIPPER-CCP4_LIBRARY=${PREFIX}/lib/libclipper-ccp4.dylib \
  -DCLIPPER-CCP4_INCLUDE_DIR=${PREFIX}/include \
  -DCLIPPER-MMDB_LIBRARY=${PREFIX}/lib/libclipper-mmdb.dylib \
  -DCLIPPER-MMDB_INCLUDE_DIR=${PREFIX}/include \
  -DCLIPPER-CIF_LIBRARY=${PREFIX}/lib/libclipper-cif.dylib \
  -DCLIPPER-CIF_INCLUDE_DIR=${PREFIX}/include \
  -DCLIPPER-CONTRIB_LIBRARY=${PREFIX}/lib/libclipper-contrib.dylib \
  -DCLIPPER-CONTRIB_INCLUDE_DIR=${PREFIX}/include \
  -DCLIPPER-MINIMOL_LIBRARY=${PREFIX}/lib/libclipper-minimol.dylib \
  -DCLIPPER-MINIMOL_INCLUDE_DIR=${PREFIX}/include \
  -DFFTW2_LIBRARY=${PREFIX}/lib/libfftw.dylib \
  -DRFFTW2_LIBRARY=${PREFIX}/lib/librfftw.dylib \
  -DFFTW2_INCLUDE_DIRS=${PREFIX}/include \
  ..
make -j ${CORES}
make install
cd ../..
echo

# Replace the CMake-installed monomers (coot's own bundled set) with
# the refmac-monomer-library tarball that this recipe pulls in - that
# is the canonical library we want to ship.
mkdir -p ${PREFIX}/share/coot/lib/data
rm -rf ${PREFIX}/share/coot/lib/data/monomers
ln -s monomers ${PREFIX}/share/coot/lib/data/monomers

# reference-structures isn't installed by either build system.
ln -s reference-structures ${PREFIX}/share/coot/reference-structures

# install activate/deactivate scripts to set COOT_DATA_DIR / COOT_PREFIX.
# Without this, baked-in PKGDATADIR is corrupted by conda's NUL-padded
# prefix replacement combined with clang/libc++ compile-time strlen folding,
# producing paths with embedded NULs that fail to locate any data files.
mkdir -p ${PREFIX}/etc/conda/activate.d
mkdir -p ${PREFIX}/etc/conda/deactivate.d
cp ${RECIPE_DIR}/coot-activate.sh   ${PREFIX}/etc/conda/activate.d/coot-activate.sh
cp ${RECIPE_DIR}/coot-deactivate.sh ${PREFIX}/etc/conda/deactivate.d/coot-deactivate.sh
