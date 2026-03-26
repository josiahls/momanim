#!/bin/bash
if [ ! -d third_party/NuMojo ]; then 
    git clone git@github.com:josiahls/NuMojo.git third_party/NuMojo --branch feature/update-mojo-26-2-0
else 
    echo 'NuMojo directory already exists.'
fi