#!/bin/bash

ppl2mail="cnxsoft@cnx-software.com"

export PATH=$PATH:/opt/gcc-linaro-arm-linux-gnueabihf/bin:/usr/local/bin

blddate=`date +%Y.%m.%d`
bldmail=~/allwinner/build/${blddate}/build_mail.log
bldresult="Success"

# Functions
# bldhwapack product_name blddir
# product_name must match the fex file name
# directory indicates the build directory, this only needs to be different if
# the kernel and/or u-boot are different
bldhwpack () {
    ./a10-hwpack-bld.sh $1
    if [ $? -eq 0 ]; then
        echo "$1 Hardware Pack... OK"  >> ${bldmail}
    else
        echo "$1 Hardware Pack... FAIL"  >> ${bldmail}
        echo "Log file: http://dl.linux-sunxi.org/nightly/${blddate}/${2}/${1}_${blddate}.log "  >> ${bldmail}
        bldresult="Failed"
    fi
}

# "Main"
mkdir -p ~/allwinner/build/${blddate}
pushd ~/allwinner/build/${blddate}
echo "Build results - ${blddate}" > ${bldmail}

git clone git://github.com/cnxsoft/a10-tools.git

# "Set-top box" builds
mkdir stb
pushd stb
cp ../a10-tools/a10-hwpack-bld.sh .
bldhwpack mele-a1000 .
bldhwpack mele-a1000-vga .
bldhwpack mk802 .
popd

#server builds
mkdir server
pushd server
cp ../a10-tools/a10-hwpack-bld.sh .
bldhwpack mele-a1000-server server
popd

#Prepare files for upload
ftpdir=ftp/${blddate}
mkdir -p ${ftpdir}/server
echo "Copy STB hardware packs"
cp stb/bld_a10_hwpack_${blddate}/*.7z $(ftpdir)
echo "Copy STB Kernel"
cp stb/bld_a10_hwpack_${blddate}/linux-allwinner/arch/arm/boot/uImage ${ftpdir}
echo "Copy STB U-boot"
cp stb/bld_a10_hwpack_${blddate}/uboot-allwinner/u-boot.bin ${ftpdir}
cp stb/bld_a10_hwpack_${blddate}/uboot-allwinner/spl/sun4i-spl.bin $(ftpdir)
echo "Copy Log files"
cp stb/bld_a10_hwpack_${blddate}/*.log $(ftpdir)

echo "Copy server hardware packs"
cp server/bld_a10_hwpack_${blddate}/*.7z $(ftpdir)/server
echo "Copy server Kernel"
cp server/bld_a10_hwpack_${blddate}/linux-allwinner/arch/arm/boot/uImage $(ftpdir)/server
echo "Copy server U-boot"
cp server/bld_a10_hwpack_${blddate}/uboot-allwinner/u-boot.bin ${ftpdir}/server
cp server/bld_a10_hwpack_${blddate}/uboot-allwinner/spl/sun4i-spl.bin ${ftpdir}/server
echo "Copy Log files"
cp server/bld_a10_hwpack_${blddate}/*.log ${ftpdir}/server

echo "Copy Files to Server"
pushd ftp
#scp -r *  buildbot@linux-sunxi.org:nightly
ln -s ${blddate} latest
# We need to tar the file to properly transfer "latest" symlink
tar -c latest  | ssh -C buildbot@linux-sunxi.org "tar -C  nightly/ -x"
if [ $? -eq 0 ]; then
    echo "Copy to http://dl.linux-sunxi.org/nightly... OK" >> ${bldmail}
else
    echo "Copy to http://dl.linux-sunxi.org/nightly... FAIL" >> ${bldmail}
fi
popd

#mkdir ~/Dropbox/nightly/${blddate}
#cp ftp/* ~/Dropbox/nightly/${blddate} -rf

popd

echo "Email build Result"
SUBJECT="A10 Build - ${blddate} - ${bldresult}"

# send an email using /bin/mail
mail -s "$SUBJECT" "$ppl2mail" < ${bldmail}

echo "Done"
