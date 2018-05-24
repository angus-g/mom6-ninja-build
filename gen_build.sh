#!/bin/bash

srcdir=../../src

function gen_nfile() {
    nfile="\${srcdir}${1#$srcdir}"
}

function generate() {
    cat << EOF > config.ninja
srcdir = ${srcdir}
EOF

    cat << 'EOF' >> config.ninja
fc = mpif90
cc = mpicc
ld = mpifort
ar = ar

fflags = -fcray-pointer -fdefault-real-8 -fdefault-double-8 -Waliasing -ffree-line-length-none -fno-range-check -g
fflags_opt = $fflags -O2 -fno-expensive-optimizations
fflags_dbg = $fflags -O0 -W -fbounds-check -fbacktrace -Wno-compare-reals
cflags = -D__IFC -g

cppdefs = -Duse_libMPI -Duse_netCDF -DSPMD
arflags = rv

rule fc
     command = $fc $fflags $cppdefs $incflags -c $in

rule cc
     command = $cc $cflags $cppdefs $incflags -c $in

rule link
     command = $ld $in -o $out $ldflags

rule archive
     command = $ar $arflags $out $in
EOF
}

if [ "$0" = "$BASH_SOURCE" ]; then
    generate
fi
