#!/bin/sh

apply()
{
    echo "Applying settings..."
    gsettings set org.gnome.desktop.interface clock-show-seconds true || return 1
    gsettings set org.gnome.desktop.interface clock-show-date true || return 1
    gsettings set org.gnome.desktop.calendar show-weekdate true || return 1
    gsettings set org.gnome.desktop.interface icon-theme Papirus || return 1
    gsettings set org.gnome.desktop.wm.preferences button-layout appmenu:minimize,maximize,close || return 1

    test $? && echo "success" || echo "failure"

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

