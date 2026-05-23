#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest_dir="${root}/third_party/rasterizer-shootout"
archive_name="raster-comparison-20070813.tar.bz2"
extract_dir="${dest_dir}/raster-comparison-20070813"
tarball="${dest_dir}/${archive_name}"

primary_url="http://david.freetype.org/rasterizer-shootout/${archive_name}"
mirror_url="https://web.archive.org/web/20170912050843/http://david.freetype.org/rasterizer-shootout/${archive_name}"

force=0
if [[ "${1:-}" == "--force" ]]; then
    force=1
fi

mkdir -p "${dest_dir}"

if [[ -f "${extract_dir}/README" && "${force}" -eq 0 ]]; then
    echo "Rasterizer shootout already present at ${extract_dir}"
    exit 0
fi

download() {
    local url="$1"
    echo "Trying ${url}"
    if curl -fsSL --max-time 120 -L -o "${tarball}.partial" "${url}"; then
        mv "${tarball}.partial" "${tarball}"
        return 0
    fi
    rm -f "${tarball}.partial"
    return 1
}

if [[ ! -f "${tarball}" || "${force}" -eq 1 ]]; then
    if ! download "${primary_url}"; then
        echo "Primary download failed; using Internet Archive mirror." >&2
        download "${mirror_url}"
    fi
fi

rm -rf "${extract_dir}"
tar -xjf "${tarball}" -C "${dest_dir}"

echo "Extracted rasterizer shootout to ${extract_dir}"
