sudo ifconfig eth1 192.168.1.1 up
sudo arp -s 192.168.1.2 00:37:76:00:00:01
sudo tcpdump -i eth1 -n -xxx port 3422
