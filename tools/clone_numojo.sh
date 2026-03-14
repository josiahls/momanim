#!/bin/bash
if [ ! -d third_party/NuMojo ]; then 
    git clone https://github.com/josiahls/NuMojo.git third_party/NuMojo --branch pre-0.9 --single-branch
else 
    echo 'NuMojo directory already exists.'
fi