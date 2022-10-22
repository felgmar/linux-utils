#!/bin/sh

uuid="`adb shell sm list-volumes | grep "private" | cut -d " " -f 3 | head -n 1`"

move_package()
{
    package_name="$1"
    storage_device="$2"
    adb shell pm move-package $package_name $storage_device
}

if [ -f "pkglist" ]
then
    for p in `cat pkglist`
    do
        echo "Moving package $p to $uuid..."
        move_package $p $uuid
    done
else
    echo "Please create a pkglist file containing the packages you want to transfer"
    exit 1
fi

