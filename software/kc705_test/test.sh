sudo ifconfig eth1 down
sudo ifconfig eth1 192.168.1.1 up
sudo arp -s 192.168.1.2 00:37:76:00:00:01
./ipnuma_client 192.168.1.2 1 1
