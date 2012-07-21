#!/bin/bash

ppl2mail="cnxsoft@cnx-software.com"

export PATH=$PATH:/opt/gcc-linaro-arm-linux-gnueabihf/bin:/usr/local/bin

blddate=`date +%Y.%m.%d`
bldmail=~/allwinner/build/${blddate}/build_mail.log
bldresult="Success"
echo "Build results - ${blddate}" > ${bldmail}

mkdir -p ~/allwinner/build/${blddate}
pushd ~/allwinner/build/${blddate}
git clone git://github.com/cnxsoft/a10-tools.git

# "Set-top box" builds
mkdir stb
pushd stb
cp ../a10-tools/a10-hwpack-bld.sh .
./a10-hwpack-bld.sh mele-a1000
if [ $? -eq 0 ]; then
    echo "Mele A1000 Hardware Pack... OK"  >> ${bldmail}
else
    echo "Mele A1000 Hardware Pack... FAIL"  >> ${bldmail}
    echo "Log file: Todo"  >> ${bldmail}
    bldresult="Failed"
fi
./a10-hwpack-bld.sh mele-a1000-vga
if [ $? -eq 0 ]; then
    echo "Mele A1000 VGA Hardware Pack... OK"  >> ${bldmail}
else
    echo "Mele A1000 VGA Hardware Pack... FAIL" >> ${bldmail}
    echo "Log file: Todo"  > ${bldmail}
    bldresult="Failed"
fi
./a10-hwpack-bld.sh mk802
if [ $? -eq 0 ]; then
    echo "A10 mini PC Hardware Pack... OK"  >> ${bldmail}
else
    echo "A10 mini PC Hardware Pack... FAIL"  >> ${bldmail}
    echo "Log file: Todo"  >> ${bldmail}
    bldresult="Failed"
fi
popd

#server builds
mkdir server
pushd server
cp ../a10-tools/a10-hwpack-bld.sh .
./a10-hwpack-bld.sh mele-a1000-server
if [ $? -eq 0 ]; then
    echo "Mele A1000 Server Hardware Pack... OK" >> ${bldmail}
else
    echo "Mele A1000 Server Hardware Pack... FAIL" >> ${bldmail}
    echo "Log file: Todo" >> ${bldmail}
    bldresult="Failed"
fi
popd

#Prepare files for upload
mkdir -p ftp/server
echo "Copy STB hardware packs"
cp stb/bld_a10_hwpack_${blddate}/*.7z ftp
echo "Copy STB Kernel"
cp stb/bld_a10_hwpack_${blddate}/linux-allwinner/arch/arm/boot/uImage ftp
echo "Copy STB U-boot"
cp stb/bld_a10_hwpack_${blddate}/uboot-allwinner/u-boot.bin ftp
cp stb/bld_a10_hwpack_${blddate}/uboot-allwinner/spl/sun4i-spl.bin ftp
echo "Copy Log files"
cp stb/bld_a10_hwpack_${blddate}/*.log ftp

echo "Copy server hardware packs"
cp server/bld_a10_hwpack_${blddate}/*.7z ftp/server
echo "Copy server Kernel"
cp server/bld_a10_hwpack_${blddate}/linux-allwinner/arch/arm/boot/uImage ftp/server
echo "Copy server U-boot"
cp server/bld_a10_hwpack_${blddate}/uboot-allwinner/u-boot.bin ftp/server
cp server/bld_a10_hwpack_${blddate}/uboot-allwinner/spl/sun4i-spl.bin ftp/server
echo "Copy Log files"
cp server/bld_a10_hwpack_${blddate}/*.log ftp/server

echo "Copy Files to Server"

mkdir ~/Dropbox/nightly/${blddate}
cp ftp/* ~/Dropbox/nightly/${blddate} -rf

popd

echo "Email build Result"
SUBJECT="A10 Build - ${blddate} - ${bldresult}"

# send an email using /bin/mail
mail -s "$SUBJECT" "$ppl2mail" < ${bldmail}

echo "Done"
