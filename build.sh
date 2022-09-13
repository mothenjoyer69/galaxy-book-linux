#!/bin/bash
set -e
BR2_DIR="buildroot"
BUILD_CROSS="CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64"
OUT_DIR="out"
CMD=$1$2
CONFIG=samsung-w737_defconfig
#functions
flash_usb () {
    read -p "target device " USB
    echo "you entered $USB"
    #make sure you aren't about to nuke your primary drive or anything
    while true; do
        read -p "is $USB the correct device? " yn
        case $yn in
            [Yy]* ) echo "yes"; break;;
            [Nn]* ) flash_usb; break;;
            * ) echo "yes or no";;
        esac
    done
    #create partition, only EFI for now as initramfs, bootloader, kernel, and dtb are all in the EFI partition.
    parted -s $USB mklabel gpt
    parted -s $USB mkpart "EFI" fat32 1MiB 261MiB
    parted -s $USB set 1 esp on
    mkfs.vfat /dev/sda1
    mount $USB'1' /mnt
    cp -r $OUT_DIR/* /mnt
    cp -r extras/grub.cfg /mnt/EFI/BOOT/grub.cfg
    umount $USB'1'
    echo "now boot it" && exit
}
#download latest linux and buildroot tarball
if [[ ! -d 'buildroot' ]]
    then echo "looking for buildroot directory" && mkdir $BR2_DIR && wget https://buildroot.org/downloads/buildroot-2022.05.1.tar.gz -o buildroot.tar.gz && bsdtar xzf buildroot.tar.gz -C $BR2_DIR/
    else echo "buildroot exists"
fi
#check if user wants to skip the rootfs, or wants to prepare for a clean build
case $CMD in
    -norootfs ) echo "not building rootfs" ;;
    -clean ) echo "cleaning directory" cd $BR2_DIR && make clean && cd .. && rm -rf $OUT_DIR && echo "cleaned" && exit;;
    *) cd $BR2_DIR && make $CONFIG && make BR2_JLEVEL=$(nproc) && cd ..
esac
#moving files
echo "moving files"
[[ ! -d $OUT_DIR ]] && mkdir $OUT_DIR/
export OUTPUT_FILES=$BR2_DIR/output/images/
for i in $OUTPUT_FILES/Image $OUTPUT_FILES/efi-part/EFI $OUTPUT_FILES/rootfs.cpio $OUTPUT_FILES/sdm850-samsung-w737.dtb; do cp -r $i $OUT_DIR; done
echo "$PWD/$OUT_DIR contains built files"
while true; do
    read -p "install to usb? " yn
    case $yn in
        [Yy]* ) flash_usb; break;;
        [Nn]* ) echo "skipping flash, done" && exit;;
        * ) echo "please answer yes or no";;
    esac
done
