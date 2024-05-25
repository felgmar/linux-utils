#!/bin/sh

gsettings list-recursively | \
    sed 's/  */\n/;s/  */\n/;s/\&/\&amp;/g' | \
        zenity --list \
            --title "gsettings" \
            --column=Group \
            --column=Key \
            --column=Setting \
            --width=1600 \
            --height=900 \
            --separator="\n" \
            --editable
