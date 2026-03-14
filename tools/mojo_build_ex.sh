#!/usr/bin/env bash
# Makes the output directories and strips the .mojo extension from the path
path="$1"
mkdir -p build/$(dirname "$path")
echo "build/${path%.mojo}"
