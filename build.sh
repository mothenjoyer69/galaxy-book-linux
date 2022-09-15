#!/bin/bash
set -e
KERN_DTB="qcom/sdm850-samsung-w737.dtb"
KERN_DIR="linux"
BR2_DIR="buildroot-2022.05.1"
BUILD_CROSS="CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64"
OUT_DIR="out"
ROOTFS="rootfs.cpio"
CMD=$1$2
CONFIG=samsung-w737_defconfig
#functions
#partition USB and write kernel + rootfs + grub to USB
flash_usb () {
    read -p "target device " USB
    echo "you entered $USB"
    while true; do
        read -p "is $USB the correct device? " yn
        case $yn in
            [Yy]* ) echo "yes"; break;;
            [Nn]* ) flash_usb; break;;
            * ) echo "yes or no";;
        esac
    done
    parted -s $USB mklabel gpt
    parted -s $USB mkpart "EFI" fat32 1MiB 977MiB
    parted -s $USB set 1 esp on
    mkfs.vfat /dev/sda1
    mount $USB'1' /mnt
    cp -r $OUT_DIR/* /mnt
    cp -r extras/grub.cfg /mnt/EFI/BOOT/grub.cfg
    umount $USB'1'
    echo "lmao maybe this will work" && exit
}

arch_install () { 
    if [[ ! -d 'linux' ]]
        then echo "downloading kernel" && git clone https://github.com/mothenjoyer69/linux
        else echo "kernel exists, skipping download"
    fi
    cd linux && git checkout w737 && git pull && make $BUILD_CROSS w737_defconfig && make $BUILD_CROSS -j$(nproc) && cd ..
    mkdir $OUT_DIR
    for i in Image /dts/$KERN_DTB; do cp linux/arch/arm64/boot/$i $OUT_DIR; done
    read -p "target device " USB
    echo "you entered $USB"
    while true; do
        read -p "is $USB the correct device? " yn
        case $yn in
            [Yy]* ) echo "yes"; break;;
            [Nn]* ) echo "you said no"; break;;
            * ) echo "yes or no";;
        esac
    done
    parted -s $USB mklabel gpt
    parted -s $USB mkpart "EFI" fat32 1MiB 977MiB
    parted -s $USB set 1 esp on
    parted -s $USB mkpart "ROOT" ext4 977MiB 100%
    echo "partitions created"
    mkfs.vfat /dev/sda1
    mkfs.ext4 /dev/sda2
    echo "filesystems created"
    mount $USB'2' /mnt
    wget http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz && bsdtar xzvf ArchLinuxARM-aarch64-latest.tar.gz -C /mnt
    echo "arch rootfs created on $USB'2'"
    sudo rm -rf /mnt/boot/*
    mount $USB'1' /mnt/boot
    cp -r $OUT_DIR/* /mnt/boot
    cp -r extras/EFI /mnt/boot
    cp -r extras/debian_grub.cfg /mnt/boot/EFI/BOOT/grub.cfg
    cd linux && make $CROSS_COMPILE INSTALL_MOD_PATH=/mnt modules_install
    echo "linux modules installed"
    sed -i 's/root\:\*/root\:\$6\$I9Q9AyTL\$Z76H7wD8mT9JAyrp\/vaYyFwyA5wRVN0tze8pvM\.MqScC7BBm2PU7pLL0h5nSxueqUpYAlZTox4Ag2Dp5vchjJ0/' /mnt/etc/shadow #this sets password as 'gentoo'
    chroot /mnt pacman-key --init
    chroot /mnt pacman-key --populate archlinuxarm
    mkdir /mnt/lib/firmware/qcom/sdm845 && git clone https://github.com/edk2-porting/sdm845-drivers && cp sdm845-drivers/qcsubsys850/* /mnt/lib/firmware/qcom/sdm845/
    umount $USB'1'
    umount $USB'2'
    echo "lmao maybe this will work" && exit
}

buildroot_install () {
    if [[ ! -d 'buildroot' ]]
        then echo "downloading buildroot" && echo "mkdir $BR2_DIR" && wget https://buildroot.org/downloads/buildroot-2022.05.1.tar.gz && bsdtar xzf buildroot-2022.05.1.tar.gz && cp extras/$CONFIG $BR2_DIR/configs/$CONFIG
        else echo "buildroot exists"
    fi
    echo "moving files"
    [[ ! -d $OUT_DIR ]] && mkdir $OUT_DIR/
    export OUTPUT_FILES=$BR2_DIR/output/images
    for i in $OUTPUT_FILES/Image $OUTPUT_FILES/efi-part/EFI $OUTPUT_FILES/rootfs.cpio $OUTPUT_FILES/sdm850-samsung-w737.dtb; do cp -r $i $OUT_DIR; done
    echo "$PWD/$OUT_DIR contains built files"
    read -p "install to usb? " yn
    case $yn in
        [Yy]* ) flash_usb; break;;
        [Nn]* ) echo "skipping flash, done" && exit;;
        * ) echo "please answer yes or no";;
    esac
}

case $CMD in
    -norootfs ) echo "not building rootfs" flash_usb ;;
    -arch) echo "arch" && arch_install ;;
    -clean ) echo "cleaning directory" && cd $BR2_DIR && make clean && cd .. && rm -rf $OUT_DIR && echo "cleaned" && exit;;
    -buildroot ) echo "buildroot" && buildroot_install;;
esac
#moving built files to working directory

#USB install
while true; do
    read -p "install to usb? " yn
    case $yn in
        [Yy]* ) flash_usb; break;;
        [Nn]* ) echo "skipping flash, done" && exit;;
        * ) echo "please answer yes or no";;
    esac
done
