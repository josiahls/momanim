#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

export PKG_CONFIG_PATH="${CONDA_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

cflags="-I${CONDA_PREFIX}/include/cairo"
libs="-L${CONDA_PREFIX}/lib -lcairo"

out="${root}/test_pixman_cairo/build/test_draw_vector_basic"
mkdir -p "${root}/test_pixman_cairo/build"
mkdir -p "${root}/test_data/test_rasterize"

gcc -O2 -Wall -Wextra \
    test_pixman_cairo/test_draw_vector_basic.c \
    ${cflags} ${libs} \
    -o "${out}"

LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH:-}" "${out}"
