#!/bin/sh
#file: adv-new-system-setup.sh


Installer_rootfs_path=./advlinux-rootfs/

#bind proc dev tmp
mount --bind /proc ${Installer_rootfs_path}/proc
mount --bind /dev  ${Installer_rootfs_path}/dev
mount --bind /tmp  ${Installer_rootfs_path}/tmp
mount --bind /sys  ${Installer_rootfs_path}/sys



sync


chroot ${Installer_rootfs_path} 

umount ${Installer_rootfs_path}/proc
umount ${Installer_rootfs_path}/dev
umount ${Installer_rootfs_path}/tmp
umount ${Installer_rootfs_path}/sys
umount ${Installer_rootfs_path}

sync
exit 0
