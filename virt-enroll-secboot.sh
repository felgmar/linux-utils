#!/bin/sh
set -eou pipefail

QEMU_NVRAM_DIR="/var/lib/libvirt/qemu/nvram"

help()
{
    cat <<EOF
Usage: $0 [-a] [-h]

Enroll Red Hat Secure Boot keys into QEMU OVMF NVRAM files.

Options:
  -a    Enroll keys into all *_VARS.fd files in ${QEMU_NVRAM_DIR}
  -h    Show this help message and exit

If no options are given, you will be prompted to select a file interactively.
EOF
    exit 0
}

enroll_file()
{
    nvram="$1"
    new_nvram="${nvram%.fd}.secboot.fd"
    if test ! -f "${new_nvram}"
    then
        virt-fw-vars --enroll-redhat -i "${nvram}" -o "${new_nvram}"
    else
        echo "The file ${new_nvram} already exists."
        return 1
    fi

    return $?
}

enroll_secboot()
{
    case "${ENROLL_ALL}" in
        0)
            PS3="Select a file: "
            select nvram in "${QEMU_NVRAM_DIR}"/*_VARS.fd
            do
                if test "${nvram}"
                then
                    enroll_file "${nvram}"
                    break
                else
                    echo "The file ${nvram} already exists"
                fi
            done
        ;;

        1)
            for nvram in "${QEMU_NVRAM_DIR}"/*_VARS.fd
            do
                enroll_file "${nvram}" || true
            done
        ;;
    esac

    return $?
}

if test -z "${1}"
then
    help
fi

while getopts 'ah' arg
do
   case "${arg}" in
        'a')
            ENROLL_ALL=1 enroll_secboot
            exit $?
        ;;

        'h')
            help
        ;;

        ?)
            if test -z "${arg}"
            then
                help
            fi
        ;;
    esac
done
