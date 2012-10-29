#!/bin/bash
#
# Build script for A10 hardware pack
# a10-hwpack-bld.sh product_name

blddate=`date +%Y.%m.%d`
cross_compiler=arm-linux-gnueabihf-
board=$1

#******************************************************************************
#
# try: Execute a command with error checking.  Note that when using this, if a piped
# command is used, the '|' must be escaped with '\' when calling try (i.e.
# "try ls \| less").
#
#******************************************************************************
try ()
{
    #
    # Execute the command and fail if it does not return zero.
    #
    eval ${*} || failure
}

#******************************************************************************
#
# failure: Bail out because of an error.
#
#******************************************************************************
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

if [ -z $1 ]; then
    echo "Usage: ./a10-hwpack-bld.sh product_name"
    echo ""
    echo "Products currently supported: mele-a1000, mele-a1000-vga, mele-a1000-server. mk802 and oval-elephant"
    exit 1
fi

try mkdir -p bld_a10_hwpack_${blddate}
try pushd bld_a10_hwpack_${blddate}

make_log=`pwd`/${board}_${blddate}.log
echo "Build hwpack for ${board} - ${blddate}" > ${make_log}

num_core=`grep 'processor' /proc/cpuinfo | sort -u | wc -l`
num_jobs=`expr ${num_core} \* 3 / 2`
if [ ${num_jobs} -le 2 ]; then
    num_jobs=2
fi

echo Number of detected cores = ${num_proc} > ${make_log}
echo Number of jobs = ${num_jobs} > ${make_log}

try mkdir -p ${board}_hwpack/bootloader
try mkdir -p ${board}_hwpack/kernel
try mkdir -p ${board}_hwpack/rootfs

# Generate script.bin
if [ ! -f .script.${board} ]
then
    echo "Checking out config files"
    if [ ! -d a10-config ]; then
        try git clone git://github.com/cnxsoft/a10-config.git >> ${make_log}
    fi
    try pushd a10-config/script.fex >> ${make_log} 2>&1
    echo "Generating ${board}.bin file"
    try fex2bin ${board}.fex > ${board}.bin
    popd >> ${make_log} 2>&1
    touch .script.${board}
fi

# Generate boot.scr
if [ ! -f .bootscr.${board} ]
then
    try pushd a10-config/uboot >> ${make_log} 2>&1
    echo "Generating ${board}.scr file"
    try mkimage -A arm -O u-boot -T script -C none -n "boot" -d ${board}.cmd ${board}.scr
    popd >> ${make_log} 2>&1
    touch .bootscr.${board}
fi

# Build u-boot
if [ ! -f .u-boot-sunxi ]
then
    # Build u-boot
    echo "Checking out u-boot source code"
    if [ ! -d u-boot-sunxi ]; then
        try git clone https://github.com/linux-sunxi/u-boot-sunxi.git --depth=1 >> ${make_log}
    fi
    try pushd u-boot-sunxi >> ${make_log} 2>&1
# workaround hardfloat u-boot issue
    try pushd arch/arm/cpu/armv7
    try cat config.mk | sed s/-msoft-float// > config2.mk
    try mv config2.mk config.mk
    try popd
# We're now using boot.scr file, and this part is not needed
#    is_server=`echo $1 | grep "-server"`
#    if [ -z $is_server ]; then
#        echo "Temporarly patch for v2011.09-sun4i"
#        echo "Disable once https://github.com/hno/uboot-allwinner/issues/10 is fixed"
#        try patch -p1 < ../a10-config/patch/u-boot-rootwait.patch
#    else
#        echo "Server build"
#        try patch -p1 < ../a10-config/patch/u-boot-rootwait-server.patch
#    fi
    echo "Building u-boot"
#Following changes in u-boot, only support Mele A1000 for now
    try make mele_a1000 CROSS_COMPILE=${cross_compiler} -j ${num_jobs} >> ${make_log} 2>&1
    popd >> ${make_log} 2>&1
    touch .u-boot-sunxi
fi

# Build the linux kernel
if [ ! -f .linux-sunxi ]
then
    echo "Checking out linux source code `pwd`"
    if [ ! -d linux-sunxi ]; then
        try git clone git://github.com/linux-sunxi/linux-sunxi.git --depth=1 >> ${make_log}
    fi
    try pushd linux-sunxi >> ${make_log} 2>&1
# Just use the default branch
#    try git checkout allwinner-v3.0-android-v2 >> ${make_log} 2>&1
    echo "Building linux"
    # cnxsoft: do we need a separate config per device ?
    if [ -f ../a10-config/kernel/${board}.config ]; then
       echo "Use custom kernel configuration"
       try cp ../a10-config/kernel/${board}.config .config >> ${make_log} 2>&1
       try make ARCH=arm oldconfig >> ${make_log} 2>&1
    else
       echo "Use default kernel configuration"
       try make ARCH=arm sun4i_defconfig >> ${make_log} 2>&1
    fi
    try make ARCH=arm CROSS_COMPILE=${cross_compiler} -j ${num_jobs} uImage >> ${make_log} 2>&1
    echo "Building the kernel modules"
#    try make ARCH=arm CROSS_COMPILE=${cross_compiler} -j ${num_jobs} INSTALL_MOD_PATH=output modules >> ${make_log} 2>&1
# Only build modules with 2 jobs to avoid race condition leading to:
# fixdep: error opening depfile: drivers/gpu/mali/mali/linux/.mali_osk_atomics.o.d: No such file or directory
    try make ARCH=arm CROSS_COMPILE=${cross_compiler} -j 2 INSTALL_MOD_PATH=output modules >> ${make_log} 2>&1
    try make ARCH=arm CROSS_COMPILE=${cross_compiler} -j ${num_jobs} INSTALL_MOD_PATH=output modules_install >> ${make_log} 2>&1
    popd >> ${make_log} 2>&1
    touch .linux-sunxi
fi

# Get binary files
echo "Checking out binary files"
if [ ! -d a10-bin ]; then
    try git clone git://github.com/cnxsoft/a10-bin.git >> ${make_log} 2>&1
fi

# Copy files in hwpack directory
echo "Copy files to hardware pack directory"
try cp linux-sunxi/output/lib ${board}_hwpack/rootfs -rf >> ${make_log} 2>&1
try cp a10-bin/armhf/* ${board}_hwpack/rootfs -rf >> ${make_log} 2>&1
# Only support Debian/Ubuntu for now
try cp a10-config/rootfs/debian-ubuntu/* ${board}_hwpack/rootfs -rf >> ${make_log} 2>&1
try mkdir -p ${board}_hwpack/rootfs/usr/bin >> ${make_log} 2>&1
try cp ../../a10-tools/a1x-initramfs.sh ${board}_hwpack/rootfs/usr/bin >> ${make_log} 2>&1
try chmod 755 ${board}_hwpack/rootfs/usr/bin/a1x-initramfs.sh  >> ${make_log} 2>&1
try mkdir -p ${board}_hwpack/rootfs/a10-bin-backup >> ${make_log} 2>&1
try cp a10-bin/armhf/* ${board}_hwpack/rootfs/a10-bin-backup -rf >> ${make_log} 2>&1
try cp linux-sunxi/arch/arm/boot/uImage ${board}_hwpack/kernel >> ${make_log} 2>&1
try cp a10-config/script.fex/${board}.bin ${board}_hwpack/kernel >> ${make_log} 2>&1
try cp a10-config/uboot/${board}.scr ${board}_hwpack/kernel/boot.scr >> ${make_log} 2>&1
try cp u-boot-sunxi/spl/sunxi-spl.bin ${board}_hwpack/bootloader >> ${make_log} 2>&1
try cp u-boot-sunxi/u-boot.bin ${board}_hwpack/bootloader >> ${make_log} 2>&1

# Compress the hwpack files
echo "Compress hardware pack file"
try pushd ${board}_hwpack >> ${make_log} 2>&1
try 7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on ../${board}_hwpack_${blddate}.7z . >> ${make_log} 2>&1
popd >> ${make_log} 2>&1
popd >> ${make_log} 2>&1
echo "Build completed - ${board} hardware pack: ${board}_hwpack_${blddate}.7z" >> ${make_log} 2>&1
echo "Build completed - ${board} hardware pack: ${board}_hwpack_${blddate}.7z"

