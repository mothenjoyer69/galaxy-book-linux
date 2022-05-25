#!/bin/bash
KERNEL=https://gitlab.com/sdm845-mainline/linux
DTB=sdm850-samsung-w737.dtb 
DESTDIR=$1
EFI=$11
ROOT=$12
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

prepare_dest () {
    lsblk #check partitions are correct and that you did in fact NOT just nuke your storage drive
    sleep 10
    dd if=/dev/zero of=$1 bs=4m
    parted $1 mklabel gpt && parted $1 mkpart fat32 1MiB 301MiB
    parted $1 mkpart ext4 301MiB 100%
    mkfs.fat -F 32 $EFI
    mkfs.ext4 $ROOT
    
    mount $ROOT /mnt
    mkdir /mnt/boot
    mount $EFI /mnt/boot
    
}

build_kernel () {
    if [ $2 = "-skip-download" ]; 
        then 
            echo "Not downloading kernel git"
        else
            git clone $KERNEL
    fi
    cp linux/arch/arm64/configs/sdm845.config linux/.config
    cd linux
    make menuconfig
    make -j24
    make dtbs
    make install INSTALL_PATH=/mnt/boot
    cp arch/arm64/boot/dts/qcom/$DTB .
    cd ..
}

rootfs_install () { 
    debootstrap --arch="arm64" "testing" "/mnt"  https://deb.debian.org/debian/
    #ugly way to prepare for chroot
    mount --bind /dev /mnt/dev &&
    mount --bind /dev/pts /mnt/dev/pts &&
    mount --bind /proc /mnt/proc &&
    mount --bind /sys /mnt/sys
    mkdir -p /mnt/lib/firmware/qcom/samsung/w737
    cp -r firmware/system/* /mnt/lib/firmware/qcom/samsung/w737
    chroot /mnt apt update
    chroot /mnt apt install 
}

grub_install () {
    chroot /mnt apt install grub-efi-arm64-bin grub2-common
    chroot /mnt grub-install --target=arm64-efi --efi-directory /boot --bootloader-id=GRUB
    chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    cp $DTB /mnt/boot
    cp $DTB /mnt/boot/grub
}

umount_all () {
    umount /mnt/dev/pts
    umount /mnt/dev
    umount /mnt/proc
    umount /mnt/sys
    umount $EFI
    umount $ROOT
    
}

prepare_dest $1
build_kernel
rootfs_install $1
grub_install
umount_all $1