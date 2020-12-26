# archlinux-sbct
A Secure Boot Configuration Tool for Arch Linux  

---

# debian-dpwi
A Debian installer for RemixDev's deemix-pyweb music downloader tool

## How to use
Copy and paste this command into the terminal to get started quickly:  
`wget -q https://git.io/JUbcn && sh debian-dpwi`

---

# debian-sbct
A Secure Boot Configuration Tool for Debian

## How to use
Simply copy and paste this command into a terminal:  
`wget https://git.io/JUddb && sudo sh debian-sbct`

---

# grub-vfiocfg
A GPU Passthrough configuration tool using VFIO

## How to use
Copy and paste the following command into a terminal to get started:  
`wget https://git.io/JUbV9 && sh grubvfiocfg`

---

# spotify-cc
A Spotify Cache Cleaner

## How to use
In your terminal, copy and paste this to download the script, make it executable and run it:  
`wget -q https://git.io/JUd55 && sh spotify-cc.sh`

---

# usbdev-dapm
A tiny tool for Linux to disable APM devices, specially external HDDs, to prevent crashes, freezing or self-unmounting while still in use.

## How to use
Download and execute the script with this command:  
`curl -L https://git.io/JTa9R > usbdev-damp && sh usbdev-damp configure`

It will save the USB device selected onto the file: `.usb_hdd_device`, so you won't have to type it everytime, in case you didn't swap to a different computer.  

Although, if you did, just run: `usbdev-damp reset` to delete the file and configure it again, if it changed (for example from /dev/sda to /dev/sdb, if there's more than one drive).

---

# vbox-kmst
A VirtualBox kernel module signing tool

## How to use it
1. Use this command: `curl -L https://git.io/JImfC > vbox-kmst` to download it.  
2. It will prompt you for one argument: `import-key` or `sign-kernel-modules`.  
3. First type: `sudo sh vbox-kmst import-key`  
  3.1. Reboot your computer, a blue window will appear (if Secure Boot is enabled).  
  3.2. Select `Import MOK`  
  3.3. Type the password you wrote on the script and now select `Reboot`.  
4. Open a terminal and execute `sudo sh vbox-kmst sign-kernel-modules`.
