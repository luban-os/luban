#!/bin/bash -x

ISO_path=../luban-linux-iso
ISO_name=../openEuler_install_v2.0.7.iso

echo "delete old LiveCD iso..."
rm -rf ${ISO_name}

echo "deleting swap file in ${ISO_path}..."
find ${ISO_path} -name "*~" -exec rm -rf {} \;

echo "deleting old md5sum.txt in ${ISO_path},we will create a new one..."
rm -rf ${ISO_path}/md5sum.txt

echo "create same as advclone openEuler filesystem.squashfs"
cat ${ISO_path}/casper/filesystem-base/filesystem-advclone-openEuler.squashfs-* > ${ISO_path}/casper/filesystem.squashfs

echo "create new md5sum.txt..."
cd ${ISO_path} && find -type f -print0 | xargs -0 md5sum | grep -v isolinux/boot.cat | tee md5sum.txt
sync
mkisofs -D -r -V "AdvLinuxTU" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -allow-limited-size -no-emul-boot -boot-load-size 4 -boot-info-table -o ${ISO_name} ${ISO_path}/
sync

