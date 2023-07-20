#!/bin/bash
QTintaller_path=../qtinstaller
Installer_rootfs_path=../livecd-rootfs/new-rootfs/
iso_path=../advlinuxtu-iso/
echo "delete old installer."
rm -rf ${QTintaller_path}/advlinux-uefi-installer
cd ${QTintaller_path}/
make clean
make -j4
echo "compile qtinstaller done."
sleep 1
sync;sync
chmod 777 advlinux-uefi-installer 

echo "copy qt installer into filesystem..."
#rm -rf ${Installer_rootfs_path}/usr/local/bin/installer
#cp -xarf installer ${Installer_rootfs_path}/usr/local/bin/
rm -rf ${iso_path}/advantech/sbin/advlinux-uefi-installer 
cp -xarf advlinux-uefi-installer ${iso_path}/advantech/sbin/
sync
exit;
