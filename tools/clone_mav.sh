#!/bin/bash
if [ ! -d third_party/mav ]; then 
    git clone git@github.com:josiahls/mav.git third_party/mav
else 
    echo 'MAV directory already exists.'
fi