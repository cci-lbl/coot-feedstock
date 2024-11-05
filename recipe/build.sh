#!/bin/bash

CORES=4

# https://conda-forge.org/docs/maintainer/knowledge_base/#newer-c-features-with-old-sdk
if [[ ! -z "$MACOSX_DEPLOYMENT_TARGET" ]]; then
  CXXFLAGS="${CXXFLAGS} -D_LIBCPP_DISABLE_AVAILABILITY"
fi

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
  else:
    echo "${d}/config.sub is not present"
  echo "============="
  echo
done

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
./configure --prefix=${PREFIX} --enable-shared --disable-static --disable-fortran
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

export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig

./configure \
  --prefix=${PREFIX} \
  --with-fftw-prefix=${PREFIX} \
  --with-boost=${PREFIX}  \
  --with-boost-libdir=${PREFIX}/lib  \
  --with-enhanced-ligand-tools \
  --with-rdkit-prefix=${PREFIX} \
  --with-guile \
  --disable-static \
  --with-glib-prefix=${PREFIX} \
  --with-gtk-prefix==${PREFIX} \
  --with-sysroot=${PREFIX}
make -j ${CORES}
make install
cd ..
echo

# copy monomer library and reference structures
mkdir -p ${PREFIX}/share/coot
cp -a monomers ${PREFIX}/share/coot
cp -a reference-structures ${PREFIX}/share/coot
