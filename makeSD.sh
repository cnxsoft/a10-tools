#!/bin/sh
# Usage ./makeSD.sh /dev/sdx image.bin

checkSyntax () {
	if [ -z $1 ] | [ -z $2 ]; then
		echo "Usage: $0 [device] [image]"
		exit 1
	fi

	if  [ ! -e $1 ]; then
		echo "Invalid device: $1"
		exit 1
	fi

	if  [ ! -f $2 ]; then
		echo "File $2 missing"
		exit 1
	fi
}

umountSD () {
	partlist=`mount | grep $1 | awk '{ print $1 }'`
	for part in $partlist
	do
		sudo umount $part
	done
}

partitionSD () {

	echo "Delete Existing Partition Table"
	sudo dd if=/dev/zero of=$1 bs=1M count=1 >> makesd.log 

	echo "Creating Partitions"
	sudo parted $1 --script mklabel msdos >> makesd.log
	if [ $? -ne 0 ]; then
		echo "Failed to create label for $1"
		exit 1
	fi 
	echo "Partition 1 - ${1}1"
	sudo parted $1 --script mkpart primary fat32 2048s 16MB >> makesd.log
	if [ $? -ne 0 ]; then
		echo "Failed to create ${1}1 partition" 
		exit 1
	fi 
	vfat_end=` sudo fdisk -lu $1 | grep ${1}1 | awk '{ print $3 }' `
	ext4_offset=`expr $vfat_end + 1`
	echo "Partition 2 (Starts at sector No. $ext4_offset)"
	sudo parted $1 --script mkpart primary ext4 ${ext4_offset}s -- -1 >> makesd.log
	if [ $? -ne 0 ]; then
		echo "Failed to create ${1}2 partition"
		exit 1
	fi 
	echo "Format Partition 1 to VFAT"
	sudo mkfs.vfat ${1}1 >> makesd.log
	if [ $? -ne 0 ]; then
		echo "Failed to format ${1}1 partition"
		exit 1
	fi 
	echo "Format Partition 2 to EXT-4"
	sudo mkfs.ext4 ${1}2 >> makesd.log
	if [ $? -ne 0 ]; then
		echo "Failed to format ${1}2 partition"
		exit 1
	fi 
}

copyUboot ()
{	
	echo "Copy U-Boot to SD Card"
	sudo dd if=$2 bs=1024 skip=8 count=1000 of=$1 seek=8
}

mountPartitions ()
{
	echo "Mount image partitions"
	loop_device=`sudo kpartx -l ../$2 | grep p1 | awk '{ print $5 }' | cut -c10`
	sudo kpartx -a $2 >> makesd.log
	if [ $? -ne 0 ]; then
		echo "Failed to run kpart"
		exit 1
	fi 
	mkdir -p mntIMGvfat mntIMGrootfs >> makesd.log
	if [ $? -ne 0 ]; then
		echo "Failed to create image mount points"
		goto exit
	fi
	echo "Mount VFAT Parition (IMG)" 
	sudo mount -o loop /dev/mapper/loop${loop_device}p1 mntIMGvfat >> makesd.log
	if [ $? -ne 0 ]; then
		echo "Failed to mount VFAT partition (IMG)"
		goto cleanup
	fi 
	echo "Mount EXT4 Parition (IMG)" 
	sudo mount -o loop /dev/mapper/loop${loop_device}p2 mntIMGrootfs >> makesd.log
	if [ $? -ne 0 ]; then
		echo "Failed to mount EXT4 partition (IMG)"
		goto cleanup
	fi 
	echo "Mount SD card partitions"
	mkdir -p mntSDvfat mntSDrootfs >> makesd.log
	if [ $? -ne 0 ]; then
		echo "Failed to create SD card mount points"
		goto cleanup
	fi 
	echo "Mount VFAT Parition (SD)" 
	sudo mount ${1}1 mntSDvfat >> makesd.log
	if [ $? -ne 0 ]; then
		echo "Failed to mount VFAT partition (SD)"
		goto cleanup
	fi 
	echo "Mount EXT4 Parition (SD)" 
	sudo mount ${1}2 mntSDrootfs >> makesd.log
	if [ $? -ne 0 ]; then
		echo "Failed to mount EXT4 partition (SD)"
		goto cleanup
	fi 
}

umountPart() {
	if [ -d $1 ]; then
		mounted=`mount | grep $1`
		if [ ! -z mounted ]; then
			echo "Umount $2"
			sudo umount $1 >> makesd.log
			if [ $? -ne 0 ]; then
				echo "Failed to umount $2)"
			else
				echo "Delete $1"
				rm -rf $1 >> makesd.log
			fi
		else
			echo "Delete $1"
			rm -rf $1 >> makesd.log
		fi	 
	fi
}

copyData () 
{
	echo "Copy VFAT partition files to SD Card"
	sudo cp -a mntIMGvfat/* mntSDvfat >> makesd.log
	if [ $? -ne 0 ]; then
		echo "Failed to copy VFAT partition data to SD Card"
		goto cleanup
	fi 
	echo "Copy rootfs partition files to SD Card"
	sudo cp -a mntIMGrootfs/* mntSDrootfs >> makesd.log
	if [ $? -ne 0 ]; then
		echo "Failed to copy rootfs partition data to SD Card"
		goto cleanup
	fi 
}

cleanup ()
{
	umountPart mntIMGvfat "VFAT Partition (IMG)"
	umountPart mntIMGrootfs "EXT4 Partition (IMG)"
	sudo kpartx -d $imgfile
	umountPart mntSDvfat "VFAT Partition (SD)"
	umountPart mntSDrootfs "EXT4 Partition (SD)"
	exit
}

# "main"
echo "makeSD log file" > makesd.log 
checkSyntax $1 $2
imgfile=$2
umountSD $1
partitionSD $1 
copyUboot $1 $2
mountPartitions $1 $2
copyData 
cleanup
