#!/bin/sh

DEFAULT_ZONE="$(firewall-cmd --get-default-zone)"
SERVICES=("kdeconnect" "spotify-sync")
SOURCES=("192.168.1.0/28")

set_default_zone_block()
{
    if test "${DEFAULT_ZONE}" = "public"
    then
        sudo firewall-cmd --set-default-zone "block"
    else
        echo "[warn] The firewalld default zone is already set to: ${DEFAULT_ZONE}"
        return 2
    fi

    return $?
}

add_services()
{
    for service in ${SERVICES[@]}
    do
        if test ! "$(sudo firewall-cmd --list-service | grep -o ${service})" = "${service}"
        then
            sudo firewall-cmd --permanent --add-service "${service}"

            if test $? -eq 0
            then
                echo "Reloading FirewallD..."
                sudo firewall-cmd --complete-reload
            fi
        else
            echo "${service}: service already enabled"
        fi
    done

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
add_services
