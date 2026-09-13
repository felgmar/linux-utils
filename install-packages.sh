#!/bin/sh

LACT_PACKAGE="https://github.com/ilya-zlobintsev/LACT/releases/download/v0.10.1/lact-0.10.1-0.x86_64.fedora-44.rpm"

sudo dnf install git \
                 steam \
                 lutris \
                 cascadia-code-ttf \
                 virt-manager \
                 $LACT_PACKAGE
