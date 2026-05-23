#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src="${root}/third_party/cairo"
build="${src}/build"
prefix="${root}/third_party/install/cairo"

bash "${root}/tools/clone_cairo.sh"

export PKG_CONFIG_PATH="${CONDA_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

cd "${src}"

if [[ -d "${build}" ]]; then
    meson setup "${build}" --reconfigure --prefix="${prefix}" --libdir=lib
else
    meson setup "${build}" --prefix="${prefix}" --libdir=lib
fi

ninja -C "${build}"
ninja -C "${build}" install
