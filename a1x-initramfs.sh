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
    echo Build step failed!

    #
    # Exit with a failure return code.
    #
    exit 1
}

echo "Extract and copy kernel config to /boot directory"
try cp /proc/config.gz  /tmp
try gzip -df /tmp/config.gz
try sudo cp /tmp/config /boot/config-`uname -r`
echo "Make sure required tools are installed"
try sudo apt-get install -y u-boot-tools initramfs-tools
echo "Generate the initramfs"
try sudo update-initramfs -c -k `uname -r`
echo "Mount the FAT partition"
try sudo mount /dev/mmcblk0p1 /boot
echo "Make initramfs image for u-boot"
try sudo mkimage -A arm -T ramdisk -C none -n "uInitrd" -d /boot/initrd.img-`uname -r` /boot/uInitrd
try sudo umount /boot
try sudo rm -f /boot/initrd* /boot/config-*
echo "Done. Reboot if you want to use the initramfs"

