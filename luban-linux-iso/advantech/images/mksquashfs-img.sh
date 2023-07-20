#!/bin/sh
#file: adv-new-system-setup.sh
rm -rf advlinux-2.0*.img
mksquashfs advlinux-rootfs advlinux-2.0.img

sync
exit 0
