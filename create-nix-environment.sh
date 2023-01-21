#!/bin/sh

#
# A modified version for PCs from ChrisTitusTech's
# Steam Deck as a Desktop cheat sheet
# source: https://christitus.com/steamdeck-as-a-desktop/
#

if test `whoami` = root
then
    echo "Do not run this script as root"
    exit 1
fi

if test ! /etc/systemd/system/nix-directory.service
then
    echo "[Unit]
Description=Create a `/nix` directory to be used for bind mounting
PropagatesStopTo=nix-daemon.service
PropagatesStopTo=nix.mount
DefaultDependencies=no
After=grub-recordfail.service
After=steamos-finish-oobe-migration.service

[Service]
Type=oneshot
ExecStart=mkdir -vp /nix
ExecStart=chmod -v 0755 /nix
ExecStart=chown -v root /nix
ExecStart=chgrp -v root /nix
ExecStop=rmdir /nix
RemainAfterExit=true
" | sudo tee /etc/systemd/system/nix-directory.service
elif test ! /etc/systemd/system/nix.mount
then
    echo "[Unit]
Description=Mount `/home/nix` on `/nix`
PropagatesStopTo=nix-daemon.service
PropagatesStopTo=nix-directory.service
After=nix-directory.service
Requires=nix-directory.service
ConditionPathIsDirectory=/nix
DefaultDependencies=no

[Mount]
What=/home/nix
Where=/nix
Type=none
DirectoryMode=0755
Options=bind
" | sudo tee /etc/systemd/system/nix.mount
elif test ! /etc/systemd/system/ensure-symlinked-units-resolve.service
then
    echo "[Unit]
Description=Ensure Nix related units which are symlinked resolve
After=nix.mount
Requires=nix-directory.service
Requires=nix.mount
PropagatesStopTo=nix-directory.service
PropagatesStopTo=nix.mount
DefaultDependencies=no

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/systemctl daemon-reload
ExecStart=/usr/bin/systemctl restart --no-block sockets.target timers.target multi-user.target

[Install]
WantedBy=sysinit.target
" | sudo tee /etc/systemd/system/ensure-symlinked-units-resolve.service
fi

(sudo systemctl daemon-reload) | exit 1

(sh <(curl -L https://nixos.org/nix/install) --daemon) | tee -a nix-installation.log

