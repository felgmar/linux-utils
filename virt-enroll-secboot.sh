#!/bin/sh

QEMU_NVRAM_DIR="/var/lib/libvirt/qemu/nvram"

ENROLL_ALL=0

enroll_secboot()
{
    if test "${ENROLL_ALL}" -eq 0
    then
        PS3="Select a file: "
        select nvram in ${QEMU_NVRAM_DIR}/*_VARS.fd
        do
            nvram_secboot_file="$(echo $nvram | sed 's,.fd,_secboot.fd,g')"
            if test ! -f "${nvram_secboot_file}"
            then
                virt-fw-vars --enroll-redhat -i $nvram -o ${nvram_secboot_file}
            else
                echo "The file ${nvram_secboot_file} already exists."
            fi
        done
    elif test "${ENROLL_ALL}" -eq 1
    then
        for nvram in ${QEMU_NVRAM_DIR}/*_VARS.fd
        do
            nvram_secboot_file="$(echo $nvram | sed 's,.fd,_secboot.fd,g')"
            if test ! -f "${nvram_secboot_file}"
            then
                virt-fw-vars --enroll-redhat -i $nvram -o ${nvram_secboot_file}
            else
                echo "The file ${nvram_secboot_file} already exists."
                return 1
            fi
        done
    fi

    return $?
}

while getopts 'a' arg
do
    case "${arg}" in
        'a')
            ENROLL_ALL=1 enroll_secboot
            exit $?
        ;;
        ?)
            enroll_secboot
            exit $?
        ;;
    esac
done
