#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cairo_prefix="${CAIRO_PREFIX:-${root}/third_party/install/cairo}"
cairo_build="${CAIRO_BUILD:-${root}/third_party/cairo/build}"
perf_bin="${cairo_build}/perf/cairo-perf-micro"

export PKG_CONFIG_PATH="${cairo_prefix}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

if [[ ! -x "${perf_bin}" ]]; then
    echo "cairo-perf-micro not found; run once: pixi run build_cairo" >&2
    exit 1
fi

LD_LIBRARY_PATH="${cairo_prefix}/lib:${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH:-}" \
    "${perf_bin}" "$@"
