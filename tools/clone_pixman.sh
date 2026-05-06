#!/bin/bash
if [ ! -d third_party ]; then
    mkdir -p third_party
fi


if [ ! -d third_party/pixman ]; then 
    git clone  https://gitlab.freedesktop.org/pixman/pixman.git third_party/pixman
else 
    echo 'Pixman directory already exists.'
fi