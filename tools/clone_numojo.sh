#!/bin/bash
if [ ! -d third_party/NuMojo ]; then 
    git clone git@github.com:josiahls/NuMojo.git third_party/NuMojo --branch pre-0.9
else 
    echo 'NuMojo directory already exists.'
fi