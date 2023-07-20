#!/bin/bash -x
QTintaller_path=/opt/qt-debug
iso_path=../advlinuxtu-iso
sleep 1
sync;sync

echo "delete old installer."
rm -rf ${iso_path}/advantech/sbin/advlinux-uefi-installer 
echo "copy qt installer into filesystem..."
cp -xarf ${QTintaller_path}/advlinux-uefi-installer ${iso_path}/advantech/sbin/
sync
exit;
