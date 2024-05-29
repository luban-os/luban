#!/bin/bash -x
#file: adv-system-setup-inside.sh
#bash -i
#export PATH=/bin:/sbin:/usr/bin:/usr/sbin:$PATH
sync
SYS_PRODUCT_NAME=`dmidecode -s system-product-name`
DEV=$1
echo "To Install Grub Bootloader......"
#echo $DEV

echo "grub instll in:${DEV}" >> /advinstall.log
echo "new host name:${HOSTNAME},new password:${PASSWORD}" >> /advinstall.log
old_uuid=$(grep "root=UUID" /boot/grub/grub.cfg | head -n 1 |sed 's/^.*root=UUID=//g' | awk '{print $1}')

modify_10_linux()
{
    line_old='initrd	${rel_dirname}/${initrd}'
    line_new='initrd /boot/adv_gpio_dsdt.cpio ${rel_dirname}/${initrd}'

    if [ "${SYS_PRODUCT_NAME}"x = "UNO-420"x ]; then
        sed -i "s%$line_old%$line_new%g" /etc/grub.d/10_linux
	depmod
    fi
}

modify_40_custom()
{
    PART=""
    RAID_DEV=`dmraid -s | grep name | awk '{print $NF}'`
    #OldUUID=`cat /etc/grub.d/40_custom | grep 'ahci0' | awk -F ' ' '{print $NF}'`
	#OldUUID=`cat /etc/grub.d/40_custom | grep 'uuid=' | awk -F '=' '{print $4}' | awk -F ' ' '{print $1}'`
	OldUUID=`cat /etc/grub.d/40_custom | tail -n 3| grep 'uuid=' | awk -F '=' '{print $4}' | awk -F ' ' '{print $1}'`

    if [ "${RAID_DEV}"x = x ]; then
        PART=`df | awk '{if($6=="/media/recovery"&&$1~/dev/&&$1!~/dev\/mapper/) print $1}'`
    else
        PART=`df | awk '{if($6=="/media/recovery"&&$1~/dev/) print $1}'`
    fi

    NewUUID=`blkid -s UUID -o value $PART`

    sed -i "s/$OldUUID/$NewUUID/g" /etc/grub.d/40_custom
}

modify_grub_pic()
{
	sed -i '176d' /etc/grub.d/05_debian_theme 
	sed -i '175a if set_background_image "${WALLPAPER=/usr/share/images/desktop-base/grub.png}" "${COLOR_NORMAL}" "${COLOR_HIGHLIGHT}"; then' /etc/grub.d/05_debian_theme

}

#modify grub
modify_grub()
{
sed -i '11d' /etc/default/grub
   
if [ $(echo ${SYSTEM_MODE} |grep "X-window-system") ] || [ $(echo ${SYSTEM_MODE} |grep "Desktop-system") ] || [ $(echo ${SYSTEM_MODE} |grep "desktop") ]; then
    sed -i '10a GRUB_CMDLINE_LINUX_DEFAULT="quiet splash overlayroot=disabled"' /etc/default/grub
elif [ $(echo ${SYSTEM_MODE} |grep "Base-system") ] || [ $(echo ${SYSTEM_MODE} |grep "text") ];then
    sed -i '10a GRUB_CMDLINE_LINUX_DEFAULT="quiet overlayroot=disabled consoleblank=0"' /etc/default/grub
    systemctl enable multi-user.target --force
    systemctl set-default multi-user.target
fi
   
sed -i 's/;/ /g' /etc/default/grub
sync
sync

}
#install grub
grub_install()
{
	if [ -d /sys/firmware/efi ]; then
        grub-install --force -d /usr/lib/grub/x86_64-efi/ --target=x86_64-efi --efi-directory=/boot/efi --boot-directory=/boot --bootloader-id=ubuntu
	else
        grub-install --force --target=i386-pc --boot-directory=/media/recovery/boot/ $DEV 
	fi
    	sync
    	sleep 2
    
    	echo "grub_install_complete" >> /advinstall.log
}

#configure the /boot/grub2/grub.conf
cfg_grub()
{
	if [ -d /sys/firmware/efi ]; then
		#rm -rf /boot/efi/EFI/openEuler/grub.cfg
        #grub2-mkconfig -o /boot/efi/EFI/openEuler/grub.cfg
		rm -rf /boot/grub/grub.cfg
		grub-mkconfig -o /boot/grub/grub.cfg
	else
		rm -rf /media/recovery/boot/grub/grub.cfg
        grub-mkconfig -o /media/recovery/boot/grub/grub.cfg
	fi
        sync
        sync
	sleep 1
   	echo "cfg_grub_complete" >> /advinstall.log
}

#function: fix the /ect/fstab
fix_fstab()
{
    #PART=`df | awk '{if($6=="/"&&$1~/dev/&&$1!~/dev\/mapper/) print $1}'`
    #if [ "$VERSION" = "AdvLinuxTU_1.0.0" ]; then
    #    #clear 
    #    echo "rootfs:${PART}" >> /advinstall.log
    #    #old_uuid = $(cat /old_UUID.ini)
     #   new_uuid=$(blkid -s UUID -o value $PART)
     #   echo "old uuid: $old_uuid,new uuid: $new_uuid" >> /advinstall.log
     #   sed -i 's/'$old_uuid'/'$new_uuid'/g' /etc/fstab
    #fi
    
    #delete uuid
    #sed -i '9d' /etc/fstab
    sed -i '/^#/!d' /etc/fstab
    sleep 1
    #/
    PART=""
    RAID_DEV=`dmraid -s | grep name | awk '{print $NF}'`

    if [ "${RAID_DEV}"x = x ]; then
        PART=`df | awk '{if($6=="/"&&$1~/dev/&&$1!~/dev\/mapper/) print $1}'`
    else
        PART=`df | awk '{if($6=="/"&&$1~/dev/) print $1}'`
    fi
    [ $PART ] && echo -e "UUID=`blkid -s UUID -o value $PART`\t/\t`blkid -s TYPE -o value $PART`\terrors=remount-ro\t0\t1" >> /etc/fstab
  
    #/boot
    PART=`df | awk '{if($6=="/boot"&&$1~/dev/&&$1!~/dev\/mapper/) print $1}'`
    [ $PART ] && echo -e "UUID=`blkid -s UUID -o value $PART`\t/boot\t`blkid -s TYPE -o value $PART`\tdefaults\t0\t2" >> /etc/fstab

    #/boot/efi
    PART=`df | awk '{if($6=="/boot/efi"&&$1~/dev/&&$1!~/dev\/mapper/) print $1}'`
    [ $PART ] && echo -e "UUID=`blkid -s UUID -o value $PART`\t/boot/efi\t`blkid -s TYPE -o value $PART`\tumask=0077,shortname=winnt\t0\t2" >> /etc/fstab

    #/media/recovery
    if [ "${RAID_DEV}"x = x ]; then
        PART=`df | awk '{if($6=="/media/recovery"&&$1~/dev/&&$1!~/dev\/mapper/) print $1}'`
    else
        PART=`df | awk '{if($6=="/media/recovery"&&$1~/dev/) print $1}'`
    fi
    [ $PART ] && echo -e "UUID=`blkid -s UUID -o value $PART`\t/media/recovery\t`blkid -s TYPE -o value $PART`\tdefaults\t0\t0" >> /etc/fstab

    #/home
    PART=`df | awk '{if($6=="/home"&&$1~/dev/&&$1!~/dev\/mapper/) print $1}'`
    [ $PART ] && echo -e "UUID=`blkid -s UUID -o value $PART`\t/home\t`blkid -s TYPE -o value $PART`\tdefaults\t0\t0" >> /etc/fstab

    #/tmp
    PART=`df | awk '{if($6=="/tmp"&&$1~/dev/&&$1!~/dev\/mapper/) print $1}'`
    [ $PART ] && echo -e "UUID=`blkid -s UUID -o value $PART`\t/tmp\t`blkid -s TYPE -o value $PART`\tdefaults\t0\t2" >> /etc/fstab

    #/usr
    PART=`df | awk '{if($6=="/usr"&&$1~/dev/&&$1!~/dev\/mapper/) print $1}'`
    [ $PART ] && echo -e "UUID=`blkid -s UUID -o value $PART`\t/usr\t`blkid -s TYPE -o value $PART`\tdefaults\t0\t2" >> /etc/fstab

    #/var
    PART=`df | awk '{if($6=="/var"&&$1~/dev/&&$1!~/dev\/mapper/) print $1}'`
    [ $PART ] && echo -e "UUID=`blkid -s UUID -o value $PART`\t/var\t`blkid -s TYPE -o value $PART`\tdefaults\t0\t2" >> /etc/fstab

    #/usr/local
    PART=`df | awk '{if($6=="/usr/local"&&$1~/dev/&&$1!~/dev\/mapper/) print $1}'`
    [ $PART ] && echo -e "UUID=`blkid -s UUID -o value $PART`\t/usr/local\t`blkid -s TYPE -o value $PART`\tdefaults\t0\t2" >> /etc/fstab

    #/opt
    PART=`df | awk '{if($6=="/opt"&&$1~/dev/&&$1!~/dev\/mapper/) print $1}'`
    [ $PART ] && echo -e "UUID=`blkid -s UUID -o value $PART`\t/opt\t`blkid -s TYPE -o value $PART`\tdefaults\t0\t2" >> /etc/fstab

  #swap
  PART=`blkid |grep swap |grep PARTUUID |awk -F ":" '{print $1}'`
  [ $PART ] && echo -e "UUID=`blkid -s UUID -o value $PART`\tswap\tswap\tdefaults\t0\t0" >> /etc/fstab
  sync
  echo "fix_fstab_complete" >> /advinstall.log
}



#function:chmod_chvt
chmod_chvt()
{
    chmod u+s /bin/chvt
    echo "chmod_chvt_complete" >> /advinstall.log
}

#function: fix the permissions for some files
fix_usr_permissions()
{
	chown lightdm:lightdm -R /var/lib/lightdm
	chown avahi-autoipd:avahi-autoipd -R /var/lib/avahi-autoipd
	chown colord:colord -R /var/lib/colord
	chown "${old_hostname}":"${old_hostname}" -R /home/*
	chown -R man:root /var/cache/man
        echo "fix_usr_permissions_complete" >> /advinstall.log
}

add_execute_permission()
{
	chmod o+x /usr/lib/dbus-1.0/dbus-daemon-launch-helper
        echo "add_execute_permission_complete" >> /advinstall.log
}


#modify_grub
modify_40_custom
grub_install
cfg_grub
fix_fstab > /dev/null 2>&1
add_execute_permission
#optimize_boot_time
chmod_chvt
update-initramfs -u > /dev/null 2>&1
sync;sync
#############clean tmp files###############

