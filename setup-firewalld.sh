#!/bin/sh

DEFAULT_ZONE="$(firewall-cmd --get-default-zone)"
SERVICES=("kdeconnect")
SOURCES=("192.168.1.0/28")
PORTS=('57621')

set_default_zone_block()
{
    if test "${DEFAULT_ZONE}" = "public"
    then
        sudo firewall-cmd --set-default-zone block
    else
        echo "[warn] The firewalld default zone is already set to: ${DEFAULT_ZONE}"
        return 2
    fi

    return $?
}

open_ports()
{
    for port in ${PORTS[@]}
    do
        if test ! "$(sudo firewall-cmd --list-ports)" = "${port}/tcp ${port}/udp"
        then
            sudo firewall-cmd --permanent --add-port "${port}"
        else
            echo "[error] ${service}: service already enabled"
        fi
    done

    if test $? -ne 0
    then
        sudo firewall-cmd --complete-reload
    fi

    return $?
    firewall-cmd --permanent --add-port="57621/tcp" --add-port="57621/udp"
    return $?
}

add_services()
{
    for service in ${SERVICES[@]}
    do
        if test ! "$(sudo firewall-cmd --list-service | grep -o ${service})" = "${service}"
        then
            sudo firewall-cmd --permanent --add-service "${service}"
        else
            echo "[error] ${service}: service already enabled"
        fi
    done

    if test $? -ne 0
    then
        sudo firewall-cmd --complete-reload
    fi

    return $?
}

add_sources()
{
    for source in ${SOURCES[@]}
    do
        if test ! "$(sudo firewall-cmd --list-service | grep -o ${source})" = "${source}"
        then
            sudo firewall-cmd --permanent --add-sources "${source}"
        else
            echo "[error] ${source}: source already enabled"
        fi
    done

    if test $? -ne 1
    then
        sudo firewall-cmd --complete-reload
    fi

    return $?
}

set_default_zone_block
open_ports
add_services

