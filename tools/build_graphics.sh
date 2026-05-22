#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "${root}/tools/build_pixman.sh"
bash "${root}/tools/build_cairo.sh"
