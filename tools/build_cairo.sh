#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
prefix="${root}/third_party/install/cairo"
src="${root}/third_party/cairo"
build="${src}/build"

if ! pkg-config --exists pixman-1; then
    echo "pixman-1 not found via pkg-config; install the pixi pixman dependency" >&2
    exit 1
fi

bash "${root}/tools/clone_cairo.sh"

export PKG_CONFIG_PATH="${CONDA_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

cd "${src}"

setup_args=(
    --prefix="${prefix}"
    --libdir=lib
    --buildtype=debug
    --wrap-mode=nofallback
    -Dtests=auto
    -Dpng=enabled
    -Dzlib=disabled
    -Dfontconfig=enabled
    -Dxlib=disabled
    -Dxcb=disabled
    -Dxlib-xcb=disabled
    -Dquartz=disabled
    -Dfreetype=disabled
    -Ddwrite=disabled
    -Dglib=disabled
)

if [[ -d "${build}" ]]; then
    meson setup "${build}" --reconfigure "${setup_args[@]}"
else
    meson setup "${build}" "${setup_args[@]}"
fi

ninja -C "${build}" install
ninja -C "${build}" perf/cairo-perf-micro

echo "installed cairo to ${prefix}"
echo "built cairo-perf-micro at ${build}/perf/cairo-perf-micro"
