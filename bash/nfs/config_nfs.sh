#!/bin/bash
#Auto config mount point and nfs service(level 2)
. ./customfunc.sh

vmount="/export/data"
capacity="18874368" #18GiB for test, large than 9TB in product environment.
fstab="/etc/fstab_bak"
exports="/etc/exports"
sysconfig="/etc/sysconfig/nfs"

sed -i "\,$vmount,d" $fstab
sed  -i 's/\#RPCNFSDCOUNT=8/RPCNFSDCOUNT=64/' /etc/sysconfig/nfs $sysconfig
rm -f $exports

(blkid && cat /proc/partitions) | awk -v vmount="$vmount" -v capacity="$capacity" -F '[ ://=\"]+' '$0!~/ntfs/ {
        if($3~/[s,v]d*/ || $3~/bcache*/) {
                uid[$3]=$5
                fst[$3]=$7
        } else if($4>$capacity) {
                parti[$5]=$4
        }
} END {
                count=1
                for(i in parti){
                        if (uid[i]!="" && fst[i]!="bcache") {
                                print "UUID="uid[i],vmount""count,fst[i],"defaults,noatime",0,2
                                count++
                        }
                }
        }' | while read line
do
	#echo $line
	read uuid mountpoint fstype< <(echo $line | awk -F'[ =]+' '{print $2,$3,$4}')
	sed -i "\,$uuid,d" $fstab
	#echo $uuid $mountpoint $fstype

	#create directory
	if [ ! -d $mountpoint ]
	then
		mkdir -p $mountpoint
	fi
	
	echo "$mountpoint 10.10.10.0(rw,async,no_root_squash) 10.10.10.1(ro,async,no_root_squash) 10.10.10.10(ro,async,no_root_squash) 10.0.0.0/255.0.0.0(rw,async)" >> $exports
	check_err $?

	#rewrite to fstab	
	#echo "rewrite to fstab"
        if [[ $fstype == ext* ]]
        then
          echo UUID=\"$uuid\" $mountpoint $fstype defaults,noatime,acl 0 2 >> $fstab
	  check_err $?
        elif [[ $fstype == "xfs" ]]
        then
          echo UUID=\"$uuid\" $mountpoint $fstype defaults,noatime 0 2 >> $fstab
	  check_err $?
        fi
done

mount -a
check_err $?
chkconfig --level 35 nfs on
check_err $?
/etc/init.d/nfs restart
check_err $?
