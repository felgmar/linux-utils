#!/bin/sh

apply_settings()
{
    gsettings set org.gnome.desktop.wm.preferences button-layout appmenu:minimize,maximize,close
    gsettings set org.gnome.desktop.interface icon-theme Papirus
    gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true
    gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-automatic true
    gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature "uint32 4700"
    gsettings set org.gnome.mutter dynamic-workspaces false

    gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view'
    gsettings set org.gnome.nautilus.preferences show-create-link true
    gsettings set org.gnome.nautilus.preferences show-delete-permanently true

    for n in $(seq 1 1 4)
    do
        gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-$n "['<Alt>$n']"
        gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-$n "['<Control>$n']"
    done

    return $?
}

reset_settings()
{
    gsettings reset org.gnome.desktop.wm.preferences button-layout
    gsettings reset org.gnome.desktop.interface icon-theme
    gsettings reset org.gnome.settings-daemon.plugins.color night-light-enabled
    gsettings reset org.gnome.settings-daemon.plugins.color night-light-schedule-automatic
    gsettings reset org.gnome.settings-daemon.plugins.color night-light-temperature
    gsettings reset org.gnome.mutter dynamic-workspaces

    gsettings reset org.gnome.nautilus.preferences default-folder-viewer
    gsettings reset org.gnome.nautilus.preferences search-view
    gsettings reset org.gnome.nautilus.preferences show-create-link
    gsettings reset org.gnome.nautilus.preferences show-delete-permanently

    for n in $(seq 1 1 4)
    do
        gsettings reset org.gnome.desktop.wm.keybindings move-to-workspace-$n
        gsettings reset org.gnome.desktop.wm.keybindings switch-to-workspace-$n
    done

    return $?
}

while getopts 'ar' arg
do
    case "$arg" in
        a) apply_settings; exit $?;;
        r) reset_settings; exit $?;;
        ?) exit 1;;
    esac
done

