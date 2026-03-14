#!/bin/bash
if [ ! -d third_party/lightbug_http ]; then 
    git clone https://github.com/josiahls/lightbug_http.git third_party/lightbug_http
else 
    echo 'Lightbug HTTP directory already exists.'
fi