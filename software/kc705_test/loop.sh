# gpu BAR1 as 0xD0000000
mode=0
while true
do
sudo ifconfig eth5 192.168.1.1 up
sudo arp -s 192.168.1.2 00:37:76:00:00:01
mode=0
./ipnuma_client 192.168.1.2 $mode 0xd0000000 0x307000f4
sleep 1
./ipnuma_client 192.168.1.2 $mode 0xd0000000 0x300700f4
sleep 1
mode=1
./ipnuma_client 192.168.1.2 $mode 0xd0000000 0x317000f4
sleep 1
./ipnuma_client 192.168.1.2 $mode 0xd0000000 0x310700f4
sleep 1
mode=2
./ipnuma_client 192.168.1.2 $mode 0xd0000000 0x327000f4
sleep 1
./ipnuma_client 192.168.1.2 $mode 0xd0000000 0x320700f4
sleep 1
mode=3
./ipnuma_client 192.168.1.2 $mode 0xd0000000 0x337000f4
sleep 1
./ipnuma_client 192.168.1.2 $mode 0xd0000000 0x330700f4
sleep 1
done
