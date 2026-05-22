#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
prefix="${root}/third_party/install/pixman"
src="${root}/third_party/pixman"
build="${src}/build"

bash "${root}/tools/clone_pixman.sh"

cd "${src}"

setup_args=(
    --prefix="${prefix}"
    --libdir=lib
    --buildtype=debug
    -Dtests=disabled
    -Ddemos=disabled
    -Dgtk=disabled
    -Dlibpng=disabled
)

if [[ -d "${build}" ]]; then
    meson setup "${build}" --reconfigure "${setup_args[@]}"
else
    meson setup "${build}" "${setup_args[@]}"
fi

ninja -C "${build}" install

echo "installed pixman to ${prefix}"
