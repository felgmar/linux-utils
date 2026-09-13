#!/bin/sh

UBUNTU_CODENAME="$(lsb_release -cs)"

wget -O - https://dl.winehq.org/wine-builds/winehq.key | sudo gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key -

sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/$UBUNTU_CODENAME/winehq-$UBUNTU_CODENAME.sources

sudo dpkg --add-architecture i386

sudo apt update

sudo apt install --install-recommends winehq-staging
