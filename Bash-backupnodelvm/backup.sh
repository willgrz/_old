#!/bin/bash
#KVM node backup script
#LVM edition

ekey=E300E78D
pigz_cmd="-7 --processes 4"
srun=$1

if [[ "$srun" == "daily" ]]; then
        ekvm=$(/sbin/lvdisplay | grep "LV Path" | awk '{print $3}' | egrep -v '(localbackup|proxy|revproxy|teamspeak3|ftpshare|win2012|ircd|monitoring|icinga)' | sed -e 's/\/dev\/raid10-vol\///')
        cdate=$(/bin/date +%d.%m.%Y.d)
elif [[ "$srun" == "weekly" ]];then
        ekvm=$(/sbin/lvdisplay | grep "LV Path" | awk '{print $3}' | egrep -v '(localbackup|proxy|revproxy|teamspeak3|ftpshare|ircd)' | sed -e 's/\/dev\/raid10-vol\///')
        cdate=$(/bin/date +%d.%m.%Y.w)
elif [[ "$srun" == "monthly" ]];then
        ekvm=$(/sbin/lvdisplay | grep "LV Path" | awk '{print $3}' | egrep -v '(localbackup)' | sed -e 's/\/dev\/raid10-vol\///')
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
gpg -r $ekey -e -o kvm-config.tar.gz.enc kvm-config.tar.gz
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
gpg -r $ekey -e -o host-config.tar.gz.enc host-config.tar.gz
rm -r etc/
rm host-config.tar.gz

#host-fs
rsync --numeric-ids -avzq --exclude=/run --exclude=/proc --exclude=/sys --exclude=/backup --exclude=/dev/ --exclude=/kvm/ --exclude=/remote --exclude=/tmp --exclude=/mnt --exclude=/var/cache / /backup/$cdate/host-fs/
cd /backup/$cdate/
tar -czf host-fs.tar.gz host-fs/
rm -r host-fs/*
gpg -r E300E78D -e -o host-fs.tar.gz.enc host-fs.tar.gz
rm host-fs.tar.gz
mv host-fs.tar.gz.enc host-fs/


for zvol in $ekvm; do
#       date
#       echo "Creating snapshot of $zvol"
        /sbin/lvcreate -l 500 -s -n $zvol.$cdate /dev/raid10-vol/$zvol
#       date
#       echo "Dumping snapshot /dev/raid10-vol/$zvol.$cdate to /backup/$cdate/kvm-snapshot/$zvol.gz.enc"
        ionice -c3 dd if=/dev/raid10-vol/$zvol.$cdate | pigz $pigz_cmd | gpg -r $ekey -e > /backup/$cdate/kvm-snapshot/$zvol.gz.enc
#       date
#       echo "Deleting snapshot /dev/raid10-vol/$zvol.$cdate"
        /sbin/lvremove -f /dev/raid10-vol/$zvol.$cdate
done

echo "Doing RSYNC to Austria"

if [[ "$srun" == "daily" ]]; then
echo "skipped - daily"
#rsync -zurq --bwlimit=512 /backup/$cdate/  root@149.154.156.23:/zfs/backups/_servers/_computing02/$cdate/
elif [[ "$srun" == "weekly" ]];then
rsync -zurq --bwlimit=2048 /backup/$cdate/  root@149.154.156.23:/zfs/backups/_servers/_computing02/$cdate/
elif [[ "$srun" == "monthly" ]];then
rsync -zurq --bwlimit=2048 /backup/$cdate/  root@149.154.156.23:/zfs/backups/_servers/_computing02/$cdate/
else
echo "Stalled - need sync date to determine speed but none given"
exit 1
fi

#echo rsync -ur /backup/kvm/$cdate*  /remote/backups/_servers/_computing02/
#echo rsync -zurq /backup/kvm/$cdate/  root@EXTIP:/zfs/backups/_servers/_computing02/kvm/
#echo "Removing Daydir"
#echo rm -rf /backup/kvm/$cdate/
