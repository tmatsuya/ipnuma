# gpu BAR1 as 0xD0000000
mode=0
addr="0xd0000000"
while true
do
sudo ifconfig enp3s0f0 192.168.1.1 up
sudo ifconfig eth1 192.168.1.1 up
sudo arp -s 192.168.1.2 00:37:76:00:00:01
mode=0
./ipnuma_client 192.168.1.2 $mode $addr 0x307000f4
sleep 1
./ipnuma_client 192.168.1.2 $mode $addr 0x300700f4
sleep 1
mode=1
./ipnuma_client 192.168.1.2 $mode $addr 0x317000f4
sleep 1
./ipnuma_client 192.168.1.2 $mode $addr 0x310700f4
sleep 1
mode=2
./ipnuma_client 192.168.1.2 $mode $addr 0x327000f4
sleep 1
./ipnuma_client 192.168.1.2 $mode $addr 0x320700f4
sleep 1
mode=3
./ipnuma_client 192.168.1.2 $mode $addr 0x337000f4
sleep 1
./ipnuma_client 192.168.1.2 $mode $addr 0x330700f4
sleep 1
done
