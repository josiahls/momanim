#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pixman_prefix="${root}/third_party/install/pixman"
prefix="${root}/third_party/install/cairo"
src="${root}/third_party/cairo"
build="${src}/build"

if [[ ! -f "${pixman_prefix}/lib/pkgconfig/pixman-1.pc" ]]; then
    echo "pixman not installed; run: pixi run build_pixman" >&2
    exit 1
fi

bash "${root}/tools/clone_cairo.sh"

export PKG_CONFIG_PATH="${pixman_prefix}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

cd "${src}"

setup_args=(
    --prefix="${prefix}"
    --libdir=lib
    --buildtype=debug
    -Dtests=disabled
    -Dpng=enabled
    -Dzlib=enabled
    -Dxlib=disabled
    -Dxcb=disabled
    -Dxlib-xcb=disabled
    -Dquartz=disabled
    -Dfontconfig=disabled
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

echo "installed cairo to ${prefix}"
