#!/bin/bash
set -euo pipefail

if [ ! -d third_party ]; then
    mkdir -p third_party
fi

if [ ! -f third_party/cairo/meson.build ]; then
    rm -rf third_party/cairo
    git clone --depth 1 https://gitlab.freedesktop.org/cairo/cairo.git third_party/cairo
else
    echo 'Cairo directory already exists.'
fi
