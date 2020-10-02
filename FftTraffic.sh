#!/bin/bash

sudo dhclient -r ens192
sudo dhclient ens192
IP=$(ip address show ens192 |  sed -En 's/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')
if [[ $IP == "140.118.2."* ]];then
echo "Interface aqueired correct IP"
else 
echo "Interface Didn't get an IP Please check that CM is online and connection to DHCP"
exit
fi
sleep 1 
echo "Checing connection to NSI"
ping -I ens192 -c 1 90.91.92.107
rc=$?
if [[ $rc -eq 0 ]] ; then
echo "Connection to NSI is OK starting traffic"
else
echo "Connection to NSI is NOT OK, Please debug"
exit
fi
ssh harmonic@10.40.22.25 'iperf3 -s' &
echo "Set Traffic timeout [sec]:"
read timeout
iperf3 -B $IP -c 90.91.92.107 -t $timeout
ssh harmonic@10.40.22.25 'killall iperf3'
