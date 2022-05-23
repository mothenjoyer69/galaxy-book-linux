#!/bin/bash
KERNEL=https://gitlab.com/sdm845-mainline/linux
DTB=sdm850-samsung-w737.dtb 
DESTDIR=$1
EFI=$11
ROOT=$12
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

prepare_dest () {
    parted $1 mklabel gpt && parted $1 mkpart fat32 1MiB 301MiB
    parted $1 mkpart ext4 301MiB 100%
    mkfs.fat -F 32 $EFI
    mkfs.ext4 $ROOT
    lsblk #check partitions are correct and that you did in fact NOT just nuke your storage drive
    mount $ROOT /mnt
    mkdir /mnt/boot
    mount $EFI /mnt/boot
}

build_kernel () {
    #git clone $KERNEL
    cp linux/arch/arm64/configs/sdm845.config linux/.config
    cd linux
    make menuconfig
    make -j24
    make install INSTALL_PATH=/mnt/boot
    cp linux/arch/arm64/boot/dts/qcom/$DTB .
}

rootfs_install () { 
    debootstrap --arch="arm64" "testing" "/mnt"  https://deb.debian.org/debian/
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
prepare_dest $1
build_kernel
rootfs_install $1
grub_install
