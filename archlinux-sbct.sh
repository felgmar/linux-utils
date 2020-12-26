#!/bin/bash

#
# Created by Liam Powell (gfelipe099)
# archlinux-sb.sh file
# A tool to enable Secure Boot on Arch Linux systems
# For Arch Linux amd64
#

#
# text formatting codes
# source https://github.com/nbros652/LUKS-guided-manual-partitioning/blob/master/LGMP.sh
#
normalText='\e[0m'
boldText='\e[1m'
yellow='\e[93m'
green='\e[92m'
red='\e[91m'

#
# check if running as root
#
if [ "$(whoami)" != "root" ]; then
    echo -e "${boldText}${red}This script must be executed as root."${normalText}
    exit 0
fi

#
# install this package to check which OS is running
#
pacman -Sy &>/dev/null && pacman -S lsb-release --noconfirm --needed &>/dev/null

# Verify Arch Linux is running
if [ ! -f /usr/bin/pacman ]; then
    echo "Pacman Package Manager was not found in this system, execution aborted."
    exit
    else
    pacman -S lsb-release --noconfirm --needed &>/dev/null
        os=$(lsb_release -ds | sed 's/"//g')
fi

if [ "${os}" != "Arch Linux" ]; then
    echo "You must be using Arch Linux to execute this script."
    exit 1
fi

function welcome() {
    clear
    sudo pacman -S figlet --noconfirm --needed &>/dev/null
    figlet -c "Arch Linux"
    figlet -c "SBCT"
    sudo pacman -Rncsd figlet --noconfirm &>/dev/null
    kernelVer="$(uname -r)"
    echo -e "Welcome to Arch Linux SBCT!\nKernel version: ${kernelVer}\n"
}

function root() {
    dependencies="shim-signed sbsigntools efibootmgr mokutil"

    if ! source main.conf &>/dev/null;  then
        echo -e "${red}${boldText}:: ERROR. Configuration file 'main.conf' was not found. Creating a new one..."${normalText}"\n\n"
        
        while true; do
        read -p ":: Specify your EFI mount location (example: /boot/efi): " bootEfiDir
        if [ ${bootEfiDir} = "" ]; then
            bootEfiDir="null"
            else
                bootEfiDir="${bootEfiDir}"
                break
        fi
        done
        echo -e "\n"
        lsblk
        echo -e "\n"
        read -p ":: Specify the EFI drive (sdX): " disk
        disk="${disk}"
        echo -e "\n"

        echo -e "${yellow}${boldText}:: Leave the option below empty if you are using NVMe SSDs.${normalText}"
        read -p ":: Specify which part is EFI mounted to (/dev/sdXy): " part
        if [ ${part} = "" ]; then
            part="null"
            else
                part="${part}"
        fi

        echo -e "\n"
        read -p ":: Specify a label for the NVRAM entry: " label
        echo -e "\n"

        printf "[Settings]
bootEfiDir="${bootEfiDir}"
disk="${disk}"
part="${part}"
label="${label}"" > main.conf
    
        else
            source main.conf &>/dev/null
            echo -e "${green}${boldText}:: Your configuration file was found and loaded successfully!${normalText}\n"
    fi

    while true; do
        read -p ":: Are you sure you want to continue? <Y/N> " input
        case $input in
            [Yy]* ) echo -e "${yellow}${boldText}:: Please wait ... ${normalText}\n"; sleep 5; break;;
            [Nn]* ) echo -e "${yellow}${boldText}:: Script execution cancelled by ${USER}.${normalText}\n\n"; exit 0;;
            * ) echo -e "${yellow}${boldText}:: Please answer Y or N instead. Try again.${normalText}";;
        esac
    done

    echo -ne "${yellow}${boldText}:: Installing dependencies ... ${normalText}\n\n"
    pacman -S ${dependencies} --noconfirm --needed &>/dev/null && echo -e "${green} done${normalText}" || echo -e "${red} failed${normalText}"

    echo -ne "${yellow}${boldText}:: Copying shim files to "${bootEfiDir}"/EFI ... ${normalText}\n\n"
    cp /usr/share/shim-signed/shimx64.efi ${bootEfiDir}/EFI/archlinux/BOOTX64.efi && cp /usr/share/shim-signed/mmx64.efi ${bootEfiDir}/EFI/archlinux/ && echo -e "${green} done${normalText}" || echo -e "${red} failed"

    echo -ne "${yellow}${boldText}::Creating NVRAM entry ... ${normalText}\n\n"
    if [[ ${part}="" ]]; then
        efibootmgr --disk ${disk} --create --label ${label} &>/dev/null && echo -e "${green}done${normalText}" || echo -e "${red}failed${normalText}"
        else
            efibootmgr --disk ${disk} --part ${part} --create --label ${label} &>/dev/null && echo -e "${green}done${normalText}" || echo -e "${red}failed${normalText}"
    fi

    echo -e "${yellow}${boldText}:: Enabling Secure Boot ... ${normalText}"
    mokutil --enable-validation
    echo -e "\n\n"

    echo -e "${yellow}${boldText}:: Configuration finished.${normalText}\n"

    while true; do
        read -p "Do you want to reboot now?" input
        case $input in
            [Yy]* ) echo -e "${yellow}${boldText}:: Rebooting system...${normalText}\n"; sleep 5; reboot;;
            [Nn]* ) echo -e "${yellow}${boldText}:: Reboot cancelled by ${USER}.${normalText}\n"; exit 0;;
            * ) echo -e "${yellow}${boldText}:: Please answer Y or N instead. Try again.";;
        esac
    done
}
# Initialize script functions in this order
welcome
root
