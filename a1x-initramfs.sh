#!/bin/bash

try ()
{
    #
    # Execute the command and fail if it does not return zero.
    #
    eval ${*} || failure
}

failure ()
{
    #
    # Indicate that an error occurred.
    #
    echo Script failed!

    #
    # Exit with a failure return code.
    #
    exit 1
}

detect_aptget=`which apt-get`
if [ -z $detect_aptget ]; then
   echo "apt-get not found!"
   echo "Currently this script only supports distributions using apt-get"
   echo "If your system uses another package managers e.g. yum, pacman..."
   echo "Feel free to edit this script @ https://github.com/cnxsoft/a10-tools :)"
   exit 1
fi

echo "Make sure required tools are installed"
try sudo apt-get install -y u-boot-tools initramfs-tools
echo "Mount the FAT partition"
try sudo mount /dev/mmcblk0p1 /boot
echo "Extract and copy kernel config to /boot directory"
try cp /proc/config.gz  /tmp
try gzip -df /tmp/config.gz
try sudo cp /tmp/config /boot/config-`uname -r`
echo "Generate the initramfs"
try sudo update-initramfs -c -k `uname -r`
echo "Make initramfs image for u-boot"
try sudo mkimage -A arm -T ramdisk -C none -n "uInitrd" -d /boot/initrd.img-`uname -r` /boot/uInitrd
try sudo rm -f /boot/initrd* /boot/config-*
try sudo umount /boot
echo "Done. Reboot if you want to use the initramfs"

