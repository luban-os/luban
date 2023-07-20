#!/bin/sh -x
cd /otapart/advupdate/bin
unsquashfs -d $1 -f ../../advlinux-*.img
sync;sync;sleep 1

