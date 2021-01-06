#!/bin/bash
#make tap interface
ip tuntap add dev tap0 mode tap group kvm 
ip link set dev tap0 up promisc on
ip addr add 0.0.0.0 dev tap0 
#make bridge
ip link add br0 type bridge
ip link set br0 up
ip link set tap0 master br0
#disable stp becouse there is only one bridge
echo 0 > /sys/class/net/br0/bridge/stp_state
ip addr add 10.0.1.1/24 dev br0 
#packet forwarding and NAT(enp2s0=network interface)
sysctl net.ipv4.conf.tap0.proxy_arp=1
sysctl net.ipv4.conf.enp2s0.proxy_arp=1
sysctl net.ipv4.ip_forward=1 #enable forwarding in kernel

iptables -t nat -A POSTROUTING -o enp2s0 -j MASQUERADE
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i br0 -o enp2s0 -j ACCEPT

#parameters for starting the vm
#-nic tap,ifname=tap0,script=no,downscript=no
#remove bridge
#brctl delif br0 enp2s0
#ip link delete br0
#delete tap interface
#sudo ip tuntap delete tap0 mode tap
