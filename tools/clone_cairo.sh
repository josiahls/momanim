#!/bin/bash
if [ ! -d third_party ]; then
    mkdir -p third_party
fi


if [ ! -d third_party/cairo ]; then 
    git clone https://github.com/msteinert/cairo.git third_party/cairo
else 
    echo 'Cairo directory already exists.'
fi