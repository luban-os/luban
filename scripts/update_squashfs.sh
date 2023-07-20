#! /bin/bash

ISO_path=../advlinuxtu-iso
Installer_rootfs_path=../livecd-rootfs/new-rootfs

echo "deleting old filesystem.manifest in ${ISO_path},we will create a new one..."
rm -rf ${ISO_path}/casper/filesystem*
echo "deleting swap file in ${Installer_rootfs_path}..."
find ${Installer_rootfs_path}/ -name "*~" -exec rm -rf {} \;

echo "compress new rootfs to filesystem.squashfs,please wait..."
mksquashfs ${Installer_rootfs_path} ${ISO_path}/casper/filesystem.squashfs -e boot -e lib/firmware -e lib/modules -e var/cache/apt -e var/lib/apt -e usr/src  -e var/lib/dpkg -e usr/share/doc -e usr/local/QT-x64 #-e boot
#Modify yaokang start
#mksquashfs ${Installer_rootfs_path} ${ISO_path}/casper/filesystem.squashfs -e boot -e var/cache/apt -e var/lib/apt -e usr/src  -e var/lib/dpkg -e usr/share/doc -e usr/local/QT-x64  #-e boot
#Modify yaokang end
echo "squashfs compress done"

echo "create new filesystem.manifest..."
chroot ${Installer_rootfs_path} dpkg-query -W --showformat='${Package} ${Version}\n' | tee ${ISO_path}/casper/filesystem.manifest
cp -v ${ISO_path}/casper/filesystem.manifest ${ISO_path}/casper/filesystem.manifest-desktop
printf $(du -sx --block-size=1 ${Installer_rootfs_path} | cut -f1) > ${ISO_path}/casper/filesystem.size
sync

echo "everything is done!!!"
sync
exit;
