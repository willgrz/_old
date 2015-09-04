#!/bin/bash
#KVM node backup script
#LVM edition

ekey=E300E78D
pigz_cmd="-7 --processes 4"
srun=$1

if [[ "$srun" == "daily" ]]; then
        ekvm=$(/sbin/zfs list | grep zvol_ | awk '{print $1}' | sed -e 's/ssd01\///')
        cdate=$(/bin/date +%d.%m.%Y.d)
elif [[ "$srun" == "weekly" ]];then
        ekvm=$(/sbin/zfs list | grep zvol_ | awk '{print $1}' | sed -e 's/ssd01\///')
        cdate=$(/bin/date +%d.%m.%Y.w)
elif [[ "$srun" == "monthly" ]];then
        ekvm=$(/sbin/zfs list | grep zvol_ | awk '{print $1}' | sed -e 's/ssd01\///')
        cdate=$(/bin/date +%d.%m.%Y.m)
else
echo "need date - daily weekly or monthly"
exit 1
fi

mkdir /backup/$cdate
mkdir /backup/$cdate/kvm-snapshot
mkdir /backup/$cdate/kvm-config
mkdir /backup/$cdate/host-config
mkdir /backup/$cdate/host-fs

#kvm config
cp -ar /etc/libvirt/qemu/*.xml /backup/$cdate/kvm-config/
sleep 2
cd /backup/$cdate/kvm-config/
tar -czf kvm-config.tar.gz .
gpg --trust-model always -r $ekey -e -o kvm-config.tar.gz.enc kvm-config.tar.gz
rm kvm-config.tar.gz
rm *.xml

#host config
mkdir /backup/$cdate/host-config/etc
cp -ar /etc/sysctl.conf /backup/$cdate/host-config/etc
mkdir /backup/$cdate/host-config/etc/network
cp -ar /etc/network/interfaces /backup/$cdate/host-config/etc/network
mkdir /backup/$cdate/host-config/etc/libvirt
cp -ar /etc/libvirt/qemu/* /backup/$cdate/host-config/etc/libvirt/
mkdir /backup/$cdate/host-config/etc/nagios
cp -ar /etc/nagios/* /backup/$cdate/host-config/etc/nagios/
mkdir /backup/$cdate/host-config/etc/munin
cp -ar /etc/munin/* /backup/$cdate/host-config/etc/munin
cd /backup/$cdate/host-config/
tar -czf host-config.tar.gz .
gpg --trust-model always -r $ekey -e -o host-config.tar.gz.enc host-config.tar.gz
rm -r etc/
rm host-config.tar.gz

#host-fs
#rsync --numeric-ids -avzq --exclude=/run --exclude=/proc --exclude=/sys --exclude=/backup --exclude=/dev/ --exclude=/kvm/ --exclude=/remote --exclude=/tmp --exclude=/mnt --exclude=/var/cache / /backup/$cdate/host-fs/
rsync --numeric-ids -avzq --exclude=/run --exclude=/proc --exclude=/sys --exclude=/backup --exclude=/dev --exclude=/zfs --exclude=/zfs_snapshot --exclude=/kvm --exclude=/remote --exclude=/tmp --exclude=/mnt --exclude=/var/cache / /backup/$cdate/host-fs/
cd /backup/$cdate/
tar -czf host-fs.tar.gz host-fs/
rm -r host-fs/*
gpg --trust-model always -r E300E78D -e -o host-fs.tar.gz.enc host-fs.tar.gz
rm host-fs.tar.gz
mv host-fs.tar.gz.enc host-fs/


for zvol in $ekvm; do
#       date
#       echo "Creating snapshot of $zvol"
        /sbin/zfs snapshot ssd01/$zvol@$cdate
#       date
#       echo "Dumping snapshot /dev/raid10-vol/$zvol.$cdate to /backup/$cdate/kvm-snapshot/$zvol.gz.enc"
        #echo ionice -c2 dd if=/dev/ssd01/zvol_$zvol.$cdate | pigz $pigz_cmd | gpg --trust-model always -r $ekey -e > /backup/$cdate/kvm-snapshot/$zvol.gz.enc
        /sbin/zfs send ssd01/$zvol@$cdate | pigz $pigz_cmd | gpg --trust-model always -r $ekey -e > /backup/$cdate/kvm-snapshot/$zvol.gz.enc
#       date
#       echo "Deleting snapshot /dev/raid10-vol/$zvol.$cdate"
        /sbin/zfs destroy ssd01/$zvol@$cdate
done

echo "Doing RSYNC to Austria"

#if [[ "$srun" == "daily" ]]; then
#rsync -zurq --bwlimit=512 /backup/$cdate/  root@EXTIP:/zfs/backups/_servers/_computing02/$cdate/
#elif [[ "$srun" == "weekly" ]];then
#rsync -zurq --bwlimit=1024 /backup/$cdate/  root@EXTIP:/zfs/backups/_servers/_computing02/$cdate/
#elif [[ "$srun" == "monthly" ]];then
#rsync -zurq --bwlimit=2048 /backup/$cdate/  root@EXTIP:/zfs/backups/_servers/_computing02/$cdate/
#else
#echo "Stalled - need sync date to determine speed but none given"
#exit 1
#fi

#echo rsync -ur /backup/kvm/$cdate*  /remote/backups/_servers/_computing02/
rsync -zurq /backup/$cdate/ root@10.76.138.2:/zfs/backups/_servers/_computing01/$cdate/
#echo "Removing Daydir"
#echo rm -rf /backup/kvm/$cdate/
