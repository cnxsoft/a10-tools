a10-tools
=========

Some tools and scripts for Mele A1000/A2000 and Allwinner A10 devices in general

madeSD.sh - Script to write image to (smaller) SD card
            usage: ./makeSD.sh device image

a10-hwpack-bld.sh - Script to build hwpack (evb.bin, u-boot, kernel and bin/config files) for AllWinner A10 devices
            usage: ./a10-hwpack-bld.sh product_name

a1x-media-crete.sh - Script to generate a bootable SD card for A10 devices
            usage (with rootfs): ./a1x-media-create.sh /dev/sdx hwpack.7z rootfs.tar.bz2
            usage (hwpack update only): ./a1x-media-create.sh /dev/sdx hwpack.7z norootfs

nightly.sh - Script to build hwpack for different hardware and flavors

a1x-initramfs.sh - Script to be executed in the target board to generate initramfs and copy it to the boot partition

