# gpu BAR1 as 0xD0000000
addr="0xc0000000"
sudo ifconfig eth1 192.168.1.1 up
sudo arp -s 192.168.1.2 00:37:76:00:00:01
mode=4
./ipnuma_client 192.168.1.2 $mode $addr 0x307000f4
