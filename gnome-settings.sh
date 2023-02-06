#!/bin/sh

apply()
{
    echo "Setting 'clock-show-seconds' to 'true'..."
    gsettings set org.gnome.desktop.interface clock-show-seconds true || return 1
    echo "Setting 'clock-show-date' to 'true'..."
    gsettings set org.gnome.desktop.interface clock-show-date true || return 1
    echo "Setting 'show-weekdate' to 'true'..."
    gsettings set org.gnome.desktop.calendar show-weekdate true || return 1

    if test ! -z `pacman -Qeq | grep papirus-icon-theme`
    then
        echo "Setting 'icon-theme' to 'Papirus'..."
        gsettings set org.gnome.desktop.interface icon-theme Papirus || return 1
    else
        echo "[E]: Could not find the icon-theme named 'Papirus'"
    fi
    echo "Setting 'button-layout' to 'appmenu:minimize,maximize,close'..."
    gsettings set org.gnome.desktop.wm.preferences button-layout appmenu:minimize,maximize,close || return 1

    if test $? -eq 0
    then
        echo "success"
    else
        echo "failure"
    fi

    return $?
}

reset()
{
    echo "Resetting settings to default..."
    gsettings reset org.gnome.desktop.interface clock-show-seconds || return 1
    gsettings reset org.gnome.desktop.interface clock-show-date || return 1
    gsettings reset org.gnome.desktop.calendar show-weekdate || return 1
    gsettings reset org.gnome.desktop.interface icon-theme || return 1
    gsettings reset org.gnome.desktop.wm.preferences button-layout || return 1

    test $? && echo "success" || echo "failure"

    return $?
}

test -z $1 && echo "Usage: `basename $0` [-a|-r]" && exit 1

while getopts 'ar' arg
do
    case $arg in
        a) apply; exit $?;;
        r) reset; exit $?;;
        ?) echo "Usage: `basename $0` [-a|-r]"; exit 1;;
    esac
done

