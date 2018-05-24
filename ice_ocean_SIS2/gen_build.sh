#!/bin/bash

# source config variables
. ../gen_build.sh

# recursively expand globs
shopt -s globstar

cat << 'EOF' > build.ninja
include ../config.ninja

incflags = $incflags -I../shared -I${srcdir}/MOM6/config_src/dynamic_symmetric -I${srcdir}/MOM6/src/framework -I${srcdir}/FMS/inclu
de -I${srcdir}/FMS/coupler -I${srcdir}/SIS2/config_src/dynamic_symmetric -I${srcdir}/SIS2/src
ldflags = -lnetcdff -L../shared -lfms
fflags = $fflags_opt
cppdefs = $cppdefs -Duse_AM3_physics -D_USE_LEGACY_LAND_
EOF

# lists of source files
fsrc_files=(${srcdir}/MOM6/src/**/*.[fF]90)
fsrc_files+=(${srcdir}/MOM6/config_src/coupled_driver/*.[fF]90)
fsrc_files+=(${srcdir}/{atmos_null,coupler,land_null,ice_ocean_extras,icebergs,SIS2}/**/*.[fF]90)
csrc_files=(${srcdir}/MOM6/src/**/*.c)
objs=()

# c file rules
for file in "${csrc_files[@]}"; do
    obj="$(basename "${file%.*}").o"
    objs+=("$obj")
    gen_nfile "$file"
    printf 'build %s: cc %s\n' "$obj" "$nfile" >> build.ninja
done

# build module provides for fortran files
declare -A modules products
for file in "${fsrc_files[@]}"; do
    provided=$(sed -rn '/\bprocedure\b/I! s/^\s*module\s+(\w+).*/\1/ip' "$file" | tr '[:upper:]' '[:lower:]')
    gen_nfile "$file"
    for m in $provided; do
        modules[$m]="$nfile"
        products[$file]+="${m}.mod "
    done
done

# fortran file rules
for file in "${fsrc_files[@]}"; do
    deps=$(sed -rn 's/^\s*use\s+(\w+).*/\1/ip' "$file" | uniq | tr '[:upper:]' '[:lower:]')
    mods=()
    srcs=()
    gen_nfile "$file"

    for dep in $deps; do
        if [[ ! -z ${modules[$dep]} && ${modules[$dep]} != $nfile ]]; then
            srcs+=("${modules[$dep]}")
            mods+=("$(basename "${modules[$dep]%.*}").o")
        fi
    done

    obj="$(basename "${file%.*}").o"
    objs+=("$obj")

    printf 'build %s %s: fc %s' "$obj" "${products[$file]}" "$nfile" >> build.ninja

    # print source files and modules, if any
    printf '%s' "${srcs[@]+ | }" >> build.ninja
    printf '%s ' "${srcs[@]}" >> build.ninja
    printf '%s' "${mods[@]+ || }" >> build.ninja
    printf '%s ' "${mods[@]}" >> build.ninja
    printf '\n' >> build.ninja
done

printf 'build MOM6-SIS2: link ' >> build.ninja
printf '%s ' "${objs[@]}" >> build.ninja
printf '\n' >> build.ninja
