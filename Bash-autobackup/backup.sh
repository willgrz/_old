#!/bin/bash

holdbackup=30
tar=/bin/tar
basedir=/backup/
include="/etc/vz/conf /vz/private/18 /vz/private/21 /vz/private/23 /vz/private/25 /vz/private/26 /vz/private/39 /vz/private/56 /vz/private/62"
exclude="/vz/private/39/home/znc/db"
#can be gz, none or bz2 - gz was the fastest in my tests
compression="gz"
#
bomb() { echo ERROR: $1 ; exit 1 ; }                 # bail out

workdir=${basedir}/archive
stampfile=${workdir}/.stampfile
incrementlist=/tmp/tecback_list.$$
hostname=vznode
monthday=`date +%d`
epoch=`date +%d.%m.%y-%H`

[ -x $tar ] || bomb "$tar not found, path wrong?"
if [ ! -d $workdir ] ; then
  mkdir -p $workdir || bomb "not able to create $workdir, no permission?"
fi

for i in $include ; do
  if [ -d $i ] ; then
    includeline="$i $includeline"
  else
    echo "$i in \$include doesnt exist and will be ignored"
  fi
done
for i in $exclude $workdir ; do 
  if [ -d $i ] ; then
    ignoreline="--exclude=$i/* $ignoreline"
  else
    echo "$i in \$exclude doesnt exist and will be ignored"
  fi
done

# kompression
case $compression in
  bz2|bzip2)   endung="tar.bz2"
	       compcom="-j"
	       ;;
  gz|gzip)     endung="tar.gz"
	       compcom="-z"
	       ;;
  keine|none)  endung="tar"
	       compcom=""
	       ;;
  *)           bomb "$compression is not a correct compression"
esac

#we always do fullbackups
kind=full
# set title of backup
title=${workdir}/${hostname}_${kind}_${epoch}.${endung}
# here we do some work
if [ $kind = full ] ; then
  echo "${epoch} ==> performing full backup ..."
  $tar -c $compcom -p $ignoreline --file $title $includeline \
    && touch $stampfile
fi
chmod 600 $title && chown root:root $title
#encrypt the backup
/usr/bin/gpg -e -o /backup/archive/${hostname}_${kind}_${epoch}.${endung}.enc -r "William X" /backup/archive/${hostname}_${kind}_${epoch}.${endung}
#remove the tar
rm /backup/archive/${hostname}_${kind}_${epoch}.${endung}
#create remote folder with date - make sure sshkeys are set up
sshdate=$(date +%d-%m-%y)
ssh root@EXTIP "mkdir /backup/$(hostname)/$sshdate"
#upload the encrypted copy by scp
scp /backup/archive/${hostname}_${kind}_${epoch}.${endung}.enc root@EXTIP:/backup/$(hostname)/$sshdate/
#md5check the copys
localmd5=$(md5sum /backup/archive/${hostname}_${kind}_${epoch}.${endung}.enc | awk '{print $1}')
foreignmd5=$(ssh root@EXTIP "md5sum /backup/$(hostname)/$sshdate/${hostname}_${kind}_${epoch}.${endung}.enc" | awk '{print $1}')
if [ $localmd5 = $foreignmd5 ]; then
	echo "${epoch} OK - Backup ${hostname}_${kind}_${epoch}.${endung}.enc MD5 matches"
else
	echo "${epoch} NOT OK - Backup ${hostname}_${kind}_${epoch}.${endung}.enc MD5 does not match"
#delete file and repeat transfer (uncomment to enable)
#	ssh root@EXTIP  "rm /backup/$(hostname)/$sshdate/${hostname}_${kind}_${epoch}.${endung}.enc"
#	scp /backup/archive/${hostname}_${kind}_${epoch}.${endung}.enc root@EXTIP:/backup/$(hostname)/$sshdate/
#exit at error, uncomment to disable
	bomb "${epoch} Backup NOT OK - try again"
fi
# delete old backups
find $workdir -type f -name "${hostname}_*" -ctime +$holdbackup -exec rm {} \;
echo "${epoch} ==> ... done with backup"
