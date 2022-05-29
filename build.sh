#!/bin/bash
KERNEL=https://gitlab.com/sdm845-mainline/linux
DTB=sdm850-samsung-w737.dtb 
DESTDIR=$1
EFI=$11
ROOT=$12
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-


user_menu() {
    echo -ne "
Choose an option:
1) Do everything
2) Build kernel only
3) Prepare drive only
4) Exit
Choose an option:  "
    read -r input
    case $input in
    1)
        prepare_dest $1
        build_kernel
        rootfs_install $1
        grub_install
        umount_all $1
        exit 0
        ;;
    2)
        prepare_dest $1
        build_kernel $1
        cd linux   
        make INSTALL_MOD_PATH=/mnt modules_install
        exit 0
        ;;
    3)
        prepare_dest $1
        umount_all $1
        exit 0
        ;;
    4)
        exit 0
        ;;
    *)
        echo "Invalid selection"
        user_menu
        ;;
    esac
}

prepare_dest () {
    lsblk #check partitions are correct and that you did in fact NOT just nuke your storage drive
    sleep 10
    #dd if=/dev/zero of=$DESTDIR bs=4M
    parted $DESTDIR mklabel gpt
    parted $DESTDIR mkpart fat32 1MiB 301MiB
    parted $DESTDIR set 1 boot on
    parted $DESTDIR mkpart ext4 301MiB 100%
    mkfs.fat -F 32 $EFI
    mkfs.ext4 $ROOT
    mount $ROOT /mnt
    mkdir /mnt/boot
    mount $EFI /mnt/boot
    
}

build_kernel () {
    if [[ $2 = "-skip-download" ]]; 
        then 
            echo "Not downloading kernel git"
        else
            git clone $KERNEL
    fi
    cp linux/arch/arm64/configs/sdm845.config linux/.config
    cd linux
    make defconfig sdm845.config 
    make menuconfig
    make -j$(nproc)
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
    cp -r firmware/system/* /mnt/lib/firmware/qcom/samsung/w737 #lmao firmware is probably signed so uh gotta figure out how to get this done easily for other devices
    cd linux
    make INSTALL_MOD_PATH=/mnt modules_install
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

user_menu