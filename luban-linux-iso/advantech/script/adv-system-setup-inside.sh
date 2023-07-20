#!/bin/bash -x
#file: adv-system-setup-inside.sh
#bash -i
#export PATH=/bin:/sbin:/usr/bin:/usr/sbin:$PATH
sync
SYS_PRODUCT_NAME=`dmidecode -s system-product-name`
DEV=`cat /boot-device.tmp`
PASSWORD=`cat /password.tmp`
HOSTNAME=`cat /hostname.tmp`
old_hostname=advantech
DEVICE_NAME=`cat /device_name.tmp`
SPECIFIC_NAME="UNO-328xG"
SYSTEM_MODE=`cat /systemMode.tmp`
grubReq=`cat /grubReq.tmp`
if [ $(echo ${DEVICE_NAME} | grep "3283G/3285G") ];then
COMPUTER_NAME="${HOSTNAME}""-${SPECIFIC_NAME}"
else
COMPUTER_NAME="${HOSTNAME}""-${DEVICE_NAME}"
fi
if [ -e /autologin.tmp ]; then
    LOGIN_MODE=`cat /autologin.tmp`
fi
echo "grub install in:${DEV}" >> /advinstall.log
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
    OldUUID=`cat /etc/grub.d/40_custom | grep 'ahci0' | awk -F ' ' '{print $NF}'`

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
    sed -i '10a GRUB_CMDLINE_LINUX_DEFAULT="quiet splash overlayroot=disabled '$grubReq'"' /etc/default/grub
elif [ $(echo ${SYSTEM_MODE} |grep "Base-system") ] || [ $(echo ${SYSTEM_MODE} |grep "text") ];then
    sed -i '10a GRUB_CMDLINE_LINUX_DEFAULT="quiet overlayroot=disabled consoleblank=0 '$grubReq'"' /etc/default/grub
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
        grub-install --force --target=x86_64-efi $DEV 
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

    #/medial/recovery
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
    PART=`blkid | grep swap | awk -F ":" '{print $1}'`
    [ $PART ] && echo -e "UUID=`blkid -s UUID -o value $PART`\tswap\tswap\tdefaults\t0\t0" >> /etc/fstab
    sync
    echo "fix_fstab_complete" >> /advinstall.log
}

#function:copy rtc time to system time

sync_time()
{
    sed -i '1a hwclock -s' /etc/rc.local
    echo "sync_time_complete" >> /advinstall.log
}

add_Xorg()
{
#Modify-start-by-yk-2016-9-26
  if [ $(echo ${SYSTEM_MODE} |grep "X-window-system") ] ;then
      rm  /etc/systemd/system/display-manager.service
      sed -i '$a Xorg vt7 & \nexport DISPLAY=:0.0\n\n sleep 4\n\n' /etc/rc.local
      echo "add Xorg to rc.local" >> /advinstall.log
      sed -i '$a xterm -geometry 640x480 &' /etc/rc.local
      echo "run xterm to rc.local" >> /advinstall.log
  fi
#Modify-end-by-yk-2016-9-26
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

#function: fix the hostname
fix_hostname()
{
    #hostname $HOSTNAME
    usermod -l "${HOSTNAME}" -d /home/${HOSTNAME} -m "${old_hostname}"
    groupmod -n "${HOSTNAME}" "${old_hostname}"
    chfn -f "${HOSTNAME}" "${HOSTNAME}"
    chown "${HOSTNAME}":"${HOSTNAME}" -R /home/*
    # modify /etc/hosts and /etc/hostname files
    sed -i 's/'${old_hostname}'/'${COMPUTER_NAME}'/g' /etc/hosts
    sed -i 's/'${old_hostname}'/'${COMPUTER_NAME}'/g' /etc/hostname
    echo "fix_hostname_complete" >> /advinstall.log
}

fix_config_by_new_hostname()
{
	sed -i 's/'${old_hostname}'/'${HOSTNAME}'/g' /etc/subuid
	sed -i 's/'${old_hostname}'/'${HOSTNAME}'/g' /etc/subgid
        echo "fix_config_by_new_hostname_complete" >> /advinstall.log
}

#function: fix the password of root
fix_passwd()
{
    #passwd root --stdin < /tmp/password.tmp
    echo "${old_hostname}":"${PASSWORD}" | chpasswd
    echo "fix_passwd_complete" >> /advinstall.log
}

install_advantech_driver_deb_packages()
{
	cd /var/ubuntu-deb-packages/
        for x in $(ls)
        do
            dpkg -i ${x}
            sync
            sync
        done
        if [ -e /rtKernel.tmp ]; then
            rt_kernel_version=`cat /tmp/kernel_version`
            cp -xarf /*.ko /lib/modules/${rt_kernel_version}/kernel/drivers/pci/
			rm /boot/*generic*
			rm -rf /lib/modules/*4.4.0-31*
			rm -rf /usr/src/*4.4.0-31*
            ln -s /usr/src/linux-headers-4.4.0-20171016-rt3 /lib/modules/4.4.0-20171016-rt3/build
        fi
        echo "install_advantech_driver_deb_packages_complete" >> /advinstall.log
}
fix_boot_garbled()
{
    mv /boot/grub/fonts/unicode.pf2 /boot/grub/fonts/unicode.pf2.bak
}
install_deb_packages()
{
    #bulit-in deb
    cp /etc/apt/sources.list /etc/apt/sources.list.bak

    echo "deb file:///media/ x11vnc/" > /etc/apt/sources.list
    echo "deb file:///media/ overlayroot/" >> /etc/apt/sources.list
    echo "deb file:///media/ blueman/" >> /etc/apt/sources.list
    apt-get update
    sync
    apt-get install x11vnc overlayroot blueman -y --allow-unauthenticated
    sync

    if [ $(echo ${SYSTEM_MODE} |grep "Desktop-system") ] || [ $(echo ${SYSTEM_MODE} |grep "desktop") ];then
        dpkg -i /media/udiskUpgrade*
	mkdir -p /usr/src/advantech/eGalaxTouch
        cp -xarf /media/eGalaxMonitorMapping* /usr/src/advantech/eGalaxTouch
        cp -xarf /media/eGTouch* /usr/src/advantech/eGalaxTouch
    fi
    dpkg -i /media/mtools*
    dpkg -i /media/network-manager*
    sync
    mv /etc/apt/sources.list.bak /etc/apt/sources.list

    if [ -e /package.tmp ]; then
        PACKAGES=`cat /package.tmp`
        cp /etc/apt/sources.list /etc/apt/sources.list.bak
        

        if [ $(echo ${PACKAGES} |grep "qt-x11") ];then
            echo "deb file:///media/qt-x11/ qt5-default/" > /etc/apt/sources.list
            apt-get update
            sync
            apt-get install qt5-default -y --allow-unauthenticated
            sync
        fi
        if [ $(echo ${PACKAGES} |grep "qt-creator") ];then
            echo "deb file:///media/qt-x11/ qtcreator/" > /etc/apt/sources.list
            apt-get update
            sync
            apt-get install qtcreator -y --allow-unauthenticated
            sync
        fi
        if [ $(echo ${PACKAGES} |grep "qt-fb") ];then
            dpkg -i /media/qt-fb/qt-fb.deb
            sync
            dpkg -i /media/tslib/tslib.deb
            sync
            #support_qt_Chiness
            cp /wqy-microhei.ttc /usr/local/QT-x86/lib/fonts
            sync

            ln -s /usr/local/QT-x86/bin/qmake /usr/bin/qmake
            cat /env.file >> /etc/bash.bashrc

            #chmod 644 /etc/pointercal
            sync
        fi
        rm -rf /media/*
        mv /etc/apt/sources.list.bak /etc/apt/sources.list
    fi
    
    rm -rf /media/*
}

#function: fix system zone information
fix_zone()
{
    MY_ZONE=$(cat /zone.tmp)
    rm /etc/localtime
    cp /usr/share/zoneinfo/${MY_ZONE} /etc/localtime
    echo "${MY_ZONE}" > /etc/timezone
    #timedatectl set-timezone ${MY_ZONE}
    echo "fix_zone_complete" >> /advinstall.log
}

install_packages()
{
if [ -d /usr/src/advantech ]
then
    cd /usr/src/advantech
    for x in $(ls)
    do
        if [ "${x##*.}"x = "deb"x ]; then
            dpkg -i ${x}
            sync
            sync
            rm -rf ${x}
        elif [ "${x#*.}"x = "tar.gz"x ]; then
            tar zxvf ${x}
            sync
            sync
            rm -rf ${x}
        fi
    done
fi
}

copy_lib()
{
TarPkg_Dir="/usr/src/advantech"

if [ -d "$TarPkg_Dir/advrelay" ]; then
    cp -xarf $TarPkg_Dir/advrelay/lnx_so/libadsrelay.so.0.0.0 /usr/lib
    ln -sf $TarPkg_Dir/advrelay/lnx_so/libadsrelay.so.0.0.0 /usr/lib/libadsrelay.so
fi

if [ -d "$TarPkg_Dir/advpled" ]; then
    cp -xarf $TarPkg_Dir/advpled/lnx_so/libadsled.so.0.0.0 /usr/lib
    ln -sf $TarPkg_Dir/advpled/lnx_so/libadsled.so.0.0.0 /usr/lib/libadsled.so
fi

if [ -d "$TarPkg_Dir/advirig" ]; then
    cp -xarf $TarPkg_Dir/advirig/libs/libbioirig.so /usr/lib
fi
}

#zhangyang add
#function: automatic login
auto_matic_login()
{
    
   #if [ $(echo ${SYSTEM_MODE} |grep "X-window-system") ] || [$(echo ${SYSTEM_MODE} |grep "Desktop-system")];then
   if [ $(echo ${SYSTEM_MODE} |grep "Desktop-system") ] || [ $(echo ${SYSTEM_MODE} |grep "desktop") ];then
       #if [ -e /autologin.tmp ]; then
       #    LOGIN_MODE=`cat /autologin.tmp`
       #fi

       if [ $(echo ${LOGIN_MODE} | grep "autologin") ] || [ $(echo ${LOGIN_MODE} | grep "Yes") ]; then
          if [ -e /etc/lightdm/lightdm.conf ]; then
	      rm /etc/lightdm/lightdm.conf
          fi
          touch /etc/lightdm/lightdm.conf	
          echo -e "[Seat:*]" >> /etc/lightdm/lightdm.conf
	  echo -e "autologin-guest=false" >> /etc/lightdm/lightdm.conf
	  echo -e "autologin-user=$HOSTNAME" >> /etc/lightdm/lightdm.conf
	  echo -e "autologin-user-timeout=0" >> /etc/lightdm/lightdm.conf
       fi
   elif [ $(echo ${SYSTEM_MODE} | grep "Base-system") ] || [ $(echo ${SYSTEM_MODE} |grep "text") ];then
       #if [ -e /autologin.tmp ]; then
       #    LOGIN_MODE=`cat /autologin.tmp`
       #fi
	   if [ $(echo ${LOGIN_MODE} | grep "autologin") ] || [ $(echo ${LOGIN_MODE} | grep "Yes") ]; then
           sed -i '28d' /lib/systemd/system/getty@.service 
           sed -i '27a ExecStart=-/sbin/agetty --noclear %I $TERM --autologin '$HOSTNAME'' /lib/systemd/system/getty@.service 
       fi

       #fix_boot_garbled
   fi
   echo "auto_matic_login_complete" >> /advinstall.log
}


#function: insmod advantech driver code
insmod_dri()
{

sync
rm /etc/rc.local

echo  '#!/bin/bash' >> /etc/rc.local
echo  'if [ -d /usr/src/advantech ]' >> /etc/rc.local
echo  'then' >> /etc/rc.local
echo  '	cd /usr/src/advantech' >> /etc/rc.local
echo  '	for x in $(ls)' >> /etc/rc.local
echo  '	do' >> /etc/rc.local
echo  '	        if [ -d "$x" ]; then' >> /etc/rc.local
echo  '		    cd $x' >> /etc/rc.local
echo  '		    if [ -e advloader ]' >> /etc/rc.local
echo  '		    then' >> /etc/rc.local
echo  '			./advloader > /dev/null 2>&1' >> /etc/rc.local
echo  '		    fi' >> /etc/rc.local
echo  '		    cd ..' >> /etc/rc.local
echo  '		fi' >> /etc/rc.local
echo  '	done' >> /etc/rc.local
echo  'fi' >> /etc/rc.local

chmod 777 /etc/rc.local
sync
echo "insmod_dri_complete" >> /advinstall.log

}

special_configuration()
{
if [ $(echo ${DEVICE_NAME} |grep "TPC-1782H") ];then
   sed -i '24d' /etc/systemd/logind.conf
   sed -i '23a HandleLidSwitch=ignore' /etc/systemd/logind.conf
   echo "fix TPC-1782H sleep in the tty1" >> /advinstall.log

   cp /xorg.conf /etc/X11
   echo "fix login resolution" >> /advinstall.log
fi


chmod 755 /usr/bin/xfsettingsd
}
optimize_boot_time()
{
#if [ $(echo ${SYSTEM_MODE} |grep "text") ];then
    rm /var/lib/ureadahead/pack
    systemctl disable NetworkManager-wait-online.service
#fi    
}

add_adspname()
{
    ln -s /usr/src/advantech/adspname/example/Adspname /usr/sbin/Adspname
}

off_screen()
{
    
    if [ $(echo ${SYSTEM_MODE} |grep "Base-system") ];then
        echo '
/sbin/advPreventMonitorTurnOff.sh & > /dev/null 2>&1' >> /etc/profile
        sync
        echo '#! /bin/bash
##########################################################
#function:Disable the automatically blanked of the screen#
##########################################################
while true
do
    sleep 5
    if [ `ps -ef|grep bash|wc -l` -ge "2" ];then
        setterm --blank 0
        sync;sync
        sleep 1
        value=`cat /sys/module/kernel/parameters/consoleblank`
        if [ "$value" -eq "0" ];then
            exit
        fi
    fi
done' > /sbin/advPreventMonitorTurnOff.sh
        sync;sync
        chmod 777 /sbin/advPreventMonitorTurnOff.sh
        echo "off_screen_complete" >> /advinstall.log 
    fi   

}

install_telnet()
{
    mv /etc/securetty /etc/securetty.bak
    echo 'service telnet
{
flags = REUSE IPv6
socket_type = stream
wait = no
user = root
server = /usr/sbin/in.telnetd
log_on_failure += USERID
disable = no
}' > /etc/xinetd.d/telnet
sync
}

install_ssh()
{
sed -i '28d' /etc/ssh/sshd_config
sed -i '27a PermitRootLogin yes' /etc/ssh/sshd_config
sync
}

install_ftp()
{
sed -i '31d' /etc/vsftpd.conf
sed -i '30a write_enable=YES' /etc/vsftpd.conf

sed -i '99d' /etc/vsftpd.conf
sed -i '98a ascii_upload_enable=YES' /etc/vsftpd.conf
sed -i '100d' /etc/vsftpd.conf
sed -i '99a ascii_download_enable=YES' /etc/vsftpd.conf

sed -i '3d' /etc/ftpusers           #SUPPORT ROOT USER
sed -i '2a #root' /etc/ftpusers     #SUPPORT ROOT USER
sync
}

fix_wdt_issue()
{

#if [ $(echo ${DEVICE_NAME} |grep "PPC-31x0S") ];then
   echo '#!/bin/bash
if [ -c "/dev/watchdog" ];then
rm /dev/watchdog
fi
if [ -c "/dev/watchdog0" ];then
rm /dev/watchdog0
fi' > /bin/rm_adv_wdt

   chmod 777 /bin/rm_adv_wdt
   sync
   sed -i '17d' /lib/systemd/system/systemd-reboot.service
   sed -i '16a ExecStart=/bin/rm_adv_wdt ; /bin/systemctl --force reboot' /lib/systemd/system/systemd-reboot.service
   
#disable sys_watchdog
   sed -i '27d' /etc/systemd/system.conf 
   sed -i '26a ShutdownWatchdogSec=0' /etc/systemd/system.conf

   sync
#fi
}
install_idoor()
{
cd /lib/modules/
ls > /tmp/kernel_version
kernel_version=`cat /tmp/kernel_version`
depmod -a ${kernel_version}
}

start_pulseaudio_daemon()
{
    if [ $(echo ${SYSTEM_MODE} |grep "Base-system") ];then
        echo '
pulseaudio --start' >> /etc/profile
        sync;sync
        echo "start_pulseaudio_daemon" >> /advinstall.log 
    fi
}

update_release_version()
{
    echo "DISTRIB_ID=AdvLinuxTU" > /etc/lsb-release
    echo "DISTRIB_RELEASE=5/17/2018" >> /etc/lsb-release
    echo "DISTRIB_CODENAME=AdvLinuxTU" >> /etc/lsb-release
    echo "DISTRIB_DESCRIPTION=\"AdvLinuxTU 1.0.8\"" >> /etc/lsb-release

}

modify_readonly()
{

   sed -i '168d' /etc/overlayroot.conf
   sed -i '167a overlayroot="tmpfs"' /etc/overlayroot.conf

   sed -i '6d' /etc/apparmor.d/sbin.dhclient
   sed -i '5a /sbin/dhclient flag=(attach_disconnected=/) {' /etc/apparmor.d/sbin.dhclient

}

support_udisk_upgrade()
{
   if [ $(echo ${SYSTEM_MODE} |grep "Desktop-system") ] || [ $(echo ${SYSTEM_MODE} |grep "desktop") ];then
      echo '
      xhost local:root' >> /etc/profile

      sed -i '25a mtools_skip_check=1' /etc/mtools.conf
      sync;sync
   fi
}

fix_3g4g_keyring()
{
	rm /home/${HOSTNAME}/.local/share/keyrings/login.keyring
}

cust_for_edgelink()
{
	chown -h sysuser:sysuser /home/sysuser -R
}

ifplugd_cfg()
{
for netname in `ifplugstatus | cut -d \: -f 1`
do 
	if [ "$netname" != 'lo' ]; then
	 	#echo $netname
		echo ifplugd -d 2 -I -p -i  $netname -r /etc/ifplugd/if.sh >> /etc/ifplugd/start_ifplugd.sh 
	fi
	chmod +x /etc/ifplugd/start_ifplugd.sh
done
}

#add by pengcheng.du
switch_console_mode()
{
CMDLINE=$(awk '{i=1;while(i<=NF){print $i;i++}}' /proc/cmdline | grep "console")

if [ $(echo ${CMDLINE}| grep "install_mode=console") ]; then

    /usr/sbin/switch_gui_or_console_mode.sh console

    sync

fi
}

#############main###############
#if [ ! -d "onlineFlag" ]; then
#install_advantech_driver_deb_packages
#fi
modify_40_custom
modify_grub_pic
modify_grub
grub_install
cfg_grub
fix_fstab
#fix_usr_permissions
add_execute_permission
cust_for_edgelink
ifplugd_cfg
#fix_passwd
#fix_hostname
#fix_config_by_new_hostname
#auto_matic_login
#fix_zone
#if [ ! -d "onlineFlag" ]; then
#install_advantech_driver_deb_packages
#install_deb_packages
install_packages
copy_lib
#install_telnet
#install_ssh
#install_ftp
#fi

#insmod_dri
#special_configuration
optimize_boot_time
#fix the xubuntu16.04 bug
#sync_time
#add_Xorg
chmod_chvt
#add_adspname
#start_pulseaudio_daemon
#off_screen
#fix_wdt_issue
#update_release_version
#install_idoor
#modify_readonly
#support_udisk_upgrade
#fix_3g4g_keyring
switch_console_mode

update-initramfs -u
sync;sync
#depmod -a
#############clean tmp files###############
rm /package.tmp
rm /systemMode.tmp
rm /grubReq.tmp
rm /vmlinuz
rm /initrd.img
rm /ppa.key
rm /env.file
rm /boot-device.tmp
rm /password.tmp
rm /hostname.tmp
rm /adv-system-setup-inside.sh
mv /advinstall.log /var/log/
rm /screenHotPlugReq.tmp
rm /autologin.tmp
rm /device_name.tmp
rm /wqy-microhei.ttc
rm /xorg.conf
rm /zone.tmp
rm /*.ko
rm /rtKernel.tmp
rm /kernel_version
sync;sync
