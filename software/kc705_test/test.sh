sudo ifconfig eth5 down
while true
do
sudo ifconfig eth5 192.168.1.1 up
sudo arp -s 192.168.1.2 00:37:76:00:00:01
./ipnuma_client 192.168.1.2 0x88442201 0xaabbccdd
sleep 1
./ipnuma_client 192.168.1.2 0x88442202 0xaabbccdd
sleep 1
./ipnuma_client 192.168.1.2 0x88442204 0xaabbccdd
sleep 1
./ipnuma_client 192.168.1.2 0x88442208 0xaabbccdd
sleep 1
./ipnuma_client 192.168.1.2 0x88442210 0xaabbccdd
sleep 1
./ipnuma_client 192.168.1.2 0x88442220 0xaabbccdd
sleep 1
./ipnuma_client 192.168.1.2 0x88442240 0xaabbccdd
sleep 1
./ipnuma_client 192.168.1.2 0x88442280 0xaabbccdd
sleep 1
done
