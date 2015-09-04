#!/bin/bash
#checks a range for arping replies and tells you the mac of the IP and if it is reachable at all and other stuff
#if running in a vlan enviroment the running host must have access to all vlans or a cisco bridge interface
#usage: checkrenumber ipfile.txt
#ipfile must be structured like "IP OPTIONAL ADDITIONAL TEXT OR COMMENT"
#made by William Weber <william @ william.si> 2013, no copyright

#define the function
getipdata(){
        tip=$(echo $@ | awk '{print $1}')
#       echo $tip
#       echo $@
        arpingmac=$(arping -r -c1  $tip)
                if [ -z "$arpingmac" ]; then
                        arpingres="ARPING: no reply"
                else
                        arpingres="ARPING: $arpingmac"
                fi
        ping=$(ping -c 1 $tip | grep from)
                if [ -z "$ping" ]; then
                        pingres="PING: no reply"
                else
                        pingres="PING: $ping"
                fi
        rdns=$(host -t PTR $tip | awk '{print $5}' | grep -v NXDOMAIN)
                if [ -z "$rdns" ]; then
                        rdnsres="RDNS: not set"
                else
                        rdnsres="RDNS: $rdns"
                fi
        #if there is additional input present after the IP (\$1) echo it out here
        addinfo=$(echo $@ | awk -v nr=2 '{ for (x=nr; x<=NF; x++) { printf "%s%s",sep,$x; sep=FS }; print "" }')
                if [ -z "$addinfo" ]; then
                        addres="ADDINFO: none"
                else
                        addres="ADDINFO: $addinfo"
                fi

        echo "IP: $tip - $arpingres - $pingres - $rdnsres - $addinfo"
}


#actual loop for reading data and running
IFS=$'\n'
for line in $(cat ipfile.txt); do
        getipdata $line;
        #echo $line;
done
