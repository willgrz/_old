#!/bin/bash

####config
backup=/backup
bklimit=5
####/config

#date.d=$(date +%d)
#date.m=$(date +%m)
#date.y=$(date +%y)

for backupnode in $(ls -1 $backup/); do
        echo "################## $backupnode ##################"
                for datedir in $(ls -1 $backup/$backupnode/ | tail -n $bklimit); do
                        ls -la $backup/$backupnode/$datedir | grep ".tar.gz.enc" | awk '{print "\n" "Date:", $7 "." $6 ,$8 "\n" "File:", $9, "\n" "Size:", $5/1073741824 ,"Gb"}'
                done
done
