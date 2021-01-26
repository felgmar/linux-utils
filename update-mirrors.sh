#!/bin/sh

update-mirrors() {
    if [ ! -f /usr/bin/scrcpy ]; then
        echo "srcpy is not installed on this system, install it to use this command"
        exit
    fi
    if [ -z ${country} ]; then
        read -p ":: Specify a country [e.g. United States]: " input1
        country=${input1}
    fi
    if [ -z ${sortBy} ]; then
        read -p ":: Specify how to sort mirrors [age,rate,country,score,delay]: " input2
        sortBy=${input2}
    fi
    echo ":: Updating mirrors from ${country} and sorting them by ${sortBy}, please wait..."
    sudo reflector --country ${country} --sort ${sortBy} --save /etc/pacman.d/mirrorlist
}
