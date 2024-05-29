#!/bin/sh
#file: adv-new-system-setup.sh

DEV=$1
BOOT_DEV=$2
ROOTFS_DEV=$3
RECOVERY_DEV=$4
HOME_DEV=$5
POST_SHELL=post_factory_recovery.sh

#echo $DEV
#echo $BOOT_DEV
#echo $ROOTFS_DEV
#echo $RECOVERY_DEV


#mkdir /media/${ROOTFS_DEV}/otapart
mkdir -p /media/${ROOTFS_DEV}/media/recovery
sync
sleep 1
mount /dev/${RECOVERY_DEV} /media/${ROOTFS_DEV}/media/recovery

#bind proc dev tmp
mount --bind /proc /media/${ROOTFS_DEV}/proc
mount --bind /dev  /media/${ROOTFS_DEV}/dev
mount --bind /tmp  /media/${ROOTFS_DEV}/tmp
mount --bind /sys  /media/${ROOTFS_DEV}/sys


copy_grub_cfg()
{
	cp -rf /etc/grub.d/10_linux /media/${ROOTFS_DEV}/etc/grub.d/	
	cp -rf /etc/grub.d/40_custom /media/${ROOTFS_DEV}/etc/grub.d/
	#cp -xarf /etc/grub.d/* /media/${ROOTFS_DEV}/etc/grub.d/
	cp -xarf /etc/default/grub /media/${ROOTFS_DEV}/etc/default/
	rm -rf /media/${ROOTFS_DEV}/etc/grub.d/20_memtest86+
	rm -rf /media/${ROOTFS_DEV}/etc/grub.d/30_uefi-firmware
	sync
	#rm -rf /media/${ROOTFS_DEV}/etc/grub.d/30_os-prober
}

chmod 777 /media/${ROOTFS_DEV}/media/recovery/advupdate/bin/${POST_SHELL}

copy_grub_cfg

sync

chroot /media/${ROOTFS_DEV} /media/recovery/advupdate/bin/${POST_SHELL} /dev/$DEV || exit $?

sync
umount /media/${ROOTFS_DEV}/proc
umount /media/${ROOTFS_DEV}/dev
umount /media/${ROOTFS_DEV}/tmp
umount /media/${ROOTFS_DEV}/sys
umount /media/${ROOTFS_DEV}/media/recovery
#umount /media/${ROOTFS_DEV}

sync
exit 0
