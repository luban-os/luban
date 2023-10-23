#!/bin/bash
OTAPARTDEV=`df | awk '$6=="/otapart" {print $1}'`
RAID_DEV=`dmraid -s | grep name | awk '{print $NF}'`

if [[ $OTAPARTDEV =~ "sda" ]]
then
	bootdev="sda1"
	recoverdev="sda2"
	rootdev="sda3"
	INSTALLDISK="sda"
elif [[ $OTAPARTDEV =~ "sdb" ]]
then
        bootdev="sdb1"
        recoverdev="sdb2"
        rootdev="sdb3"
        INSTALLDISK="sdb"
elif [[ $OTAPARTDEV =~ "mmc" ]]
then
	bootdev="mmcblk0p1"
	recoverdev="mmcblk0p2"
	rootdev="mmcblk0p3"
	INSTALLDISK="mmcblk0"
elif [[ $OTAPARTDEV =~ "nvme" ]]
then
	bootdev="nvme0n1p1"
        recoverdev="nvme0n1p2"
        rootdev="nvme0n1p3"
        INSTALLDISK="nvme0n1"
elif [[ $OTAPARTDEV =~ "dm" ]]
then
        bootdev="mapper/${RAID_DEV}p1"
        recoverdev="mapper/${RAID_DEV}p2"
        rootdev="mapper/${RAID_DEV}p3"
	INSTALLDISK="dm-2"
fi

configfile="advupdate.txt.example"
rebootfile="rebootFlag"

echo_msg()
{
	NOW=$(date +'%Y-%m-%d %H:%M:%S')
	echo "[$NOW] $1" 2>&1 | tee -a /tmp/update.log
	sync
}

recoveryfs () {
	dev=$1
	fsfile=/media/${dev}/rootfs.img
	devnode="/dev/"${dev}
	devdir="/media/"${dev}
	UPDATE_LOGFILE=/media/${dev}/update.log

	if [ -f "/media/${dev}/${configfile}" ]; then
		while read line
		do 
		name=`echo $line|awk -F '=' '{print $1}'`
		value=`echo $line|awk -F '=' '{print $2}'` 
	
		case $name in 
		"advimage")
			advimage=$value
			echo_msg advimage=$advimage
			;;
		"advrootfs")
			advrootfs=$value
			echo_msg advrootfs=$advrootfs
			;;
		"advrecover")
			advrecover=$value
			echo_msg advrecover=$advrecover
			;;
		"advfrim")
			advfrim=$value
			echo_msg advfrim=$advfrim
			;;	
		"advfactory")
			advfactory=$value
			echo_msg advfactory=$advfactory
			;;	
		"advcycle")
			advcycle=$value
			echo_msg advcycle=$advcycle
			;;	
		"advapp")
			advapp=$value
			echo_msg advapp=$advapp
			;;	
		"advpath")
			advpath=$value
			echo_msg advpath=$advpath
			;;	
		"advpartition")
			advpartition=$value
			echo_msg advpartition=$advpartition
			;;	
		*)
			;;
		esac 
		done < /media/${dev}/${configfile}
	else
		echo_msg "No /media/${dev}/${configfile} config file!"
		return 1
	fi

	if [ "$advpartition" = "y" ]; then                                
		echo_msg "create partitions for ${dev}!"
	fi


	if [ "$advfactory" = "y" ]; then  
		echo_msg "Recovery to factory image!"
	       	echo_msg "Please wait patiently. It may take several minutes..."	
		rm -rf /media/${rootdev}/* > /dev/null 2>&1
		rm -rf /media/${bootdev}/* > /dev/null 2>&1
		chmod 777 /otapart/advupdate/bin/*
		chvt3
		clear
		/otapart/advupdate/bin/recovery_installer ${INSTALLDISK} ${bootdev} ${rootdev} ${recoverdev} ${homedev}
	fi

	if [ "$advapp" = "y" ]; then  
		echo_msg "update app!"                              
		unsquashfs -d /media/${rootdev} -f /otapart/advupdate/appupdatedemo.img 
	fi


	if [ "$advimage" = "y" ]; then                                
		echo_msg "update initrd and kernel!"
   		cp -p /media/${dev}/vmlinuz* /media/${bootdev}/            
   		cp -p /media/${dev}/initrd* /media/${bootdev}/     
		sync                                                                             
	fi
                                                                                       
	if [ "$advrecover" = "y" ]; then                                     
		if [ /media/$recoverdev != /media/${dev} ]; then                        
			echo_msg "update recovery file system!"       
   			cp -p /media/${dev}/vmlinuz* /media/${bootdev}/            
   			cp -p /media/${dev}/initrd* /media/${bootdev}/     
			cp -p /media/${dev}/rootfs* /media/${rootdev}/
			sync
		else                               
			echo_msg "recovery part is same!" 
		fi                                                                               
	fi

	if [ -f "$fsfile" ] && [ -f "/media/${dev}/${configfile}" ] && [ "$advrootfs" = "y" ]; then
		echo_msg "update root file system!"
		echo_msg "starting formating disk ${rootdev}..."

		umount -l /media/${rootdev}
		yes | mke2fs -t ext4 /dev/${rootdev}
		e2fsck  /dev/${rootdev}
		echo_msg "unsquashfs files to ${rootdev}..."
		mount -t ext4 /dev/${rootdev} /media/${rootdev}
		sync;sync;sleep 1
		unsquashfs -d /media/${rootdev} -f ${fsfile}
		sync;sync;sleep 2
	
		echo_msg "check the ext4 partition..."
		cd /

		#modify fstab
		rm /media/${rootdev}/etc/fstab
		echo -e  "UUID=`blkid -s UUID -o value /dev/sda2`\t/\t`blkid -s TYPE -o value /dev/sda2`\terrors=remount-ro\t0\t1" >> /media/${rootdev}/etc/fstab
		echo -e  "UUID=`blkid -s UUID -o value /dev/sda1`\t/boot\t`blkid -s TYPE -o value /dev/sda1`\tdefaults\t0\t2" >> /media/${rootdev}/etc/fstab
		sync

		umount -l /media/${rootdev}
		e2fsck  /dev/${rootdev}
		sync;sync	
	else
		echo_msg "${fsfile} not update!!!"
	fi

	#mv /media/${recoverdev}/advupdate.txt /media/${recoverdev}/advupdate.bak
	sync;sync;sleep 1
}

recovery_function()
{
	sleep 5

     	mkdir -p /media/${rootdev}
     	mkdir -p /media/${recoverdev}

	mount /dev/${rootdev} /media/${rootdev}
	mount /dev/${recoverdev} /media/${recoverdev}

	mount /dev/${bootdev} /media/${rootdev}/boot/efi

	recoveryfs ${recoverdev}
	umount /media/${rootdev}/boot/efi
	umount /media/${rootdev}
	umount /media/${recoverdev}
}
recovery_function
