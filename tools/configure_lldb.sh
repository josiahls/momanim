if [ -f ~/.lldbinit ]; then
    echo "~/.lldbinit already exists"
else
    echo "~/.lldbinit does not exist"
    touch ~/.lldbinit
    echo "settings set target.disable-aslr false" >> ~/.lldbinit
fi