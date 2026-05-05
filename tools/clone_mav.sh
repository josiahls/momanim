#!/bin/bash
if [ ! -d third_party ]; then
    mkdir -p third_party
fi


if [ ! -d third_party/mav ]; then 
    if [ -d "$HOME/mav" ]; then
        ln -s "$HOME/mav" third_party/mav
    else
        git clone git@github.com:josiahls/mav.git third_party/mav
    fi
else 
    echo 'MAV directory already exists.'
fi