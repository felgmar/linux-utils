#!/bin/sh
[ `whoami` != "root" ] && \
    echo "Please execute this script as root" || \
        sysctl kernel.unprivileged_userns_clone=1
