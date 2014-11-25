#
# brdige script 
# set /etc/sysctl.conf && sysctl -p
#net.ipv4.ip_forward = 1
# Disable netfilter on bridges.
#net.bridge.bridge-nf-call-ip6tables = 0
#net.bridge.bridge-nf-call-iptables = 0
#net.bridge.bridge-nf-call-arptables = 0
brctl addbr vbr0
brctl stp vbr0 off
brctl addif vbr0 eth1
brctl addif vbr0 eth2
ifconfig eth1 0.0.0.0
ifconfig eth2 0.0.0.0
ifconfig vbr0 192.168.1.1
