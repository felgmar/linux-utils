#!/bin/sh
#
# Created by Ken Hoo (mrkenhoo)
# swtpm-builder file
# For Debian GNU/Linux 11 (bullseye) amd64
#

help() {
    printf "\nUsage: ${0} [PARAMETER]\n\nAccepted parameters are:
    - install
    - uninstall
    - build
    - setup
    - fix-trousers-service
    - clean\n\n"
}

if [ "$(lsb_release -ds)" != "Debian GNU/Linux 11 (bullseye)" ]; then
    echo "==> ERROR: You are not using Debian GNU/Linux 11 (bullseye) which this script was developed for."
    exit
fi

fixTrousersService() {
    echo '#!/bin/sh

### BEGIN INIT INFO
# Provides:     tcsd trousers
# Required-Start:   $local_fs $remote_fs $network
# Required-Stop:    $local_fs $remote_fs $network
# Should-Start:
# Should-Stop:
# Default-Start:    2 3 4 5
# Default-Stop:     0 1 6
# Short-Description:    starts tcsd
# Description:      tcsd belongs to the TrouSerS TCG Software Stack
### END INIT INFO

PATH=/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=/usr/sbin/tcsd
NAME=tcsd
DESC="Trusted Computing daemon"
USER="tss"

test -x "${DAEMON}" || exit 0

# Read configuration variable file if it is present
[ -r /etc/default/$NAME ] && . /etc/default/$NAME

. /lib/lsb/init-functions

case "${1}" in
    start)
        if [ ! -e /dev/tpmrm ]
        then
            log_warning_msg "device driver not loaded, skipping."
            exit 0
        fi

        for tpm_dev in /dev/tpmrm; do
            TPM_OWNER=$(stat -c %U $tpm_dev)
            if [ "x$TPM_OWNER" != "xtss" ]
            then
                log_warning_msg "TPM device owner for $tpm_dev is not 'tss', this can cause problems."
            fi
        done

        if [ ! -e /dev/tpm0 ]
        then
            log_warning_msg "device driver not loaded, skipping."
            exit 0
        fi

        for tpm_dev in /dev/tpm0; do
            TPM_OWNER=$(stat -c %U $tpm_dev)
            if [ "x$TPM_OWNER" != "xtss" ]
            then
                log_warning_msg "TPM device owner for $tpm_dev is not 'tss', this can cause problems."
            fi
        done
        ;;

    stop)
        log_daemon_msg "Stopping $DESC" "$NAME"

        start-stop-daemon --stop --quiet --oknodo --pidfile /var/run/${NAME}.pid --user ${USER} --exec ${DAEMON}
        RETVAL="$?"
        log_end_msg $RETVAL
        rm -f /var/run/${NAME}.pid
        exit $RETVAL
        ;;

    restart|force-reload)
        "${0}" stop
        sleep 1
        "${0}" start
        exit $?
        ;;

    status)
        status_of_proc -p /var/run/${NAME}.pid "${DAEMON}" "${NAME}" && exit 0 || exit $?
        ;;

    *)
        echo "Usage: ${NAME} {start|stop|restart|force-reload|status}" >&2
        exit 3
        ;;
esac

exit 0' > /etc/init.d/trousers
}

install() {
    if [ ! -f libtpms0_0.9.2-2_amd64.deb ]; then
        echo "Fetching package: libtpms0_0.9.2-2_amd64.deb..."
        curl -sL http://ftp.us.debian.org/debian/pool/main/libt/libtpms/libtpms0_0.9.2-2_amd64.deb > libtpms0_0.9.2-2_amd64.deb
    fi

    if [ ! -f libtpms-dev_0.9.2-2_amd64.deb ]; then
        echo "Fetching package: libtpms-dev_0.9.2-2_amd64.deb..."
        curl -sL http://ftp.us.debian.org/debian/pool/main/libt/libtpms/libtpms-dev_0.9.2-2_amd64.deb > libtpms-dev_0.9.2-2_amd64.deb
    fi

    echo "==> Installing dependencies..."
    if [ -x /usr/bin/sudo ] && [ -x /usr/bin/apt ]; then
        sudo apt install -y gdebi build-essential libfuse-dev libglib2.0-dev \
        libgmp-dev expect libtasn1-dev socat tpm-tools python3-twisted \
        gnutls-dev gnutls-bin libjson-glib-dev python3-setuptools softhsm2 \
        libseccomp-dev automake autoconf libtool gcc libssl-dev dh-exec \
        pkg-config dh-autoreconf net-tools gawk > /dev/null 2>&1

        gdebi -n -q libtpms0_0.9.2-2_amd64.deb
        gdebi -n -q libtpms-dev_0.9.2-2_amd64.deb
    fi
}

uninstall() {
    echo "==> Purging dependencies..."
    if [ -x /usr/bin/sudo ] && [ -x /usr/bin/apt ]; then
        sudo apt purge --autoremove -y gdebi build-essential libfuse-dev libglib2.0-dev \
        libgmp-dev expect libtasn1-dev socat tpm-tools python3-twisted \
        gnutls-dev gnutls-bin libjson-glib-dev python3-setuptools softhsm2 \
        libseccomp-dev automake autoconf libtool gcc libssl-dev dh-exec \
        dh-autoreconf libtpms-dev libtpms0 net-tools gawk > /dev/null 2>&1
    fi
}

build() {
    if [ ! -d "libtpms" ]; then
        git clone https://github.com/stefanberger/libtpms
        cd libtpms; ./autogen.sh --with-openssl; make dist; dpkg-buildpackage -us -uc -j$(nproc --all)
        sudo apt purge --autoremove -y libtpms0 libtpms-dev
        sudo dpkg -i ../libtpms0_0*_amd64.deb ../libtpms-dev_0*_amd64.deb
        cd ..
    fi
    if [ ! -d "swtpm" ]; then
        git clone -b stable-0.6 https://github.com/stefanberger/swtpm
        cd swtpm; dpkg-buildpackage -us -uc -j$(nproc --all); cd ..; sudo dpkg -i swtpm-tools_0.*.deb \
                                                                            swtpm-libs_0.*.deb \
                                                                            swtpm-dev_0.*.deb \
                                                                            swtpm_0.*.deb
    fi
}

setup() {
    if [ -d "/var/lib/swtpm-localca" ]; then
        if [ -x /usr/bin/swtpm_setup ]; then
            swtpm_setup --tpm2 --tpm-state /var/lib/swtpm-localca
        fi
        chown -R tss:tss /var/lib/swtpm-localca
        chmod -R 755 /var/lib/swtpm-localca
    fi
}

if [ -z "$1" ]; then
    help
    exit
elif [ "$1" = "install" ]; then
    install
    exit
elif [ "$1" = "uninstall" ]; then
    uninstall
    exit
elif [ "$1" = "build" ]; then
    build
    exit
elif [ "$1" = "setup" ]; then
    setup
    exit
elif [ "$1" = "fix-trousers-service" ]; then
    fixTrousersService
    exit
elif [ "$1" = "clean" ]; then
    rm -rfv swtpm libtpms *.tar.xz *.dsc *.deb *.ddeb *.changes *.buildinfo
    else
        help
fi
