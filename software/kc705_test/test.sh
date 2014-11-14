sudo ifconfig eth5 down
sudo ifconfig eth5 192.168.1.1 up
sudo arp -s 192.168.1.2 00:37:76:00:00:01
exit
done
#
# gpu BAR1 as 0xD0000000
mode=0
while true
do
sudo ifconfig eth5 192.168.1.1 up
sudo arp -s 192.168.1.2 00:37:76:00:00:01
./ipnuma_client 192.168.1.2 $mode 0xd0000000 0x407000f4
sleep 1
./ipnuma_client 192.168.1.2 $mode 0xd0000000 0x400700f4
sleep 1
done
