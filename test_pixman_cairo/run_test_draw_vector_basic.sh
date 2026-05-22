#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

pixman_prefix="${PIXMAN_PREFIX:-${root}/third_party/install/pixman}"
cairo_prefix="${CAIRO_PREFIX:-${root}/third_party/install/cairo}"

export PKG_CONFIG_PATH="${cairo_prefix}/lib/pkgconfig:${pixman_prefix}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

if ! pkg-config --exists cairo; then
    echo "cairo not found; run once: pixi run build_graphics" >&2
    exit 1
fi

cflags="$(pkg-config --cflags cairo)"
libs="$(pkg-config --libs cairo libpng)"

out="${root}/test_pixman_cairo/build/test_draw_vector_basic"
mkdir -p "${root}/test_pixman_cairo/build"
mkdir -p "${root}/test_data/test_rasterize"

gcc -O0 -g -Wall -Wextra \
    test_pixman_cairo/test_draw_vector_basic.c \
    ${cflags} ${libs} \
    -o "${out}"

LD_LIBRARY_PATH="${cairo_prefix}/lib:${pixman_prefix}/lib:${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH:-}" "${out}"
