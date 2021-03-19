VM1 = -drive file=overlay.qcow,format=qcow2,index=0,media=disk \
        -nic tap,ifname=tap0,script=no,downscript=no,mac=52:54:00:12:34:50

VM2 = -drive file=overlay1.qcow,format=qcow2,index=1,media=disk \
        -nic tap,ifname=tap1,script=no,downscript=no,mac=52:54:00:12:34:51

QEMU_OPTS = -machine type=q35,accel=kvm \
        -object rng-random,id=rng0,filename=/dev/urandom \
        -device virtio-rng-pci,rng=rng0 \
        -cpu host \
        -smp 2 -m 1024 \
        -curses
boot1vm:
        sudo qemu-system-x86_64 $(QEMU_OPTS) $(VM1)
boot2vm:
        sudo qemu-system-x86_64 $(QEMU_OPTS) $(VM2)

bridge:
        #make tap interfaces
        sudo ip tuntap add dev tap0 mode tap group kvm
        sudo ip link set dev tap0 up
        sudo ip addr add 0.0.0.0 dev tap0

        sudo ip tuntap add dev tap1 mode tap group kvm
        sudo ip link set dev tap1 up
        sudo ip addr add 0.0.0.0 dev tap1
        #make bridge:
        sudo ip link add br0 type bridge
        sudo ip link set br0 up
        #add taps to brifge
        sudo ip link set tap0 master br0
        sudo ip link set tap1 master br0
        #disable stp becouse there is only one bridge
        #sudo bash -c "echo 0 > /sys/class/net/br0/bridge/stp_state"
        sudo ip addr add 10.0.1.1/24 dev br0
        #packet forwarding and NAT(enp2s0=network interface)
        sudo sysctl net.ipv4.conf.tap0.proxy_arp=1
        sudo sysctl net.ipv4.conf.tap1.proxy_arp=1
        sudo sysctl net.ipv4.conf.enp2s0.proxy_arp=1
        sudo sysctl net.ipv4.ip_forward=1 #enable forwarding in kernel
        #firewall rules
        sudo iptables -t nat -A POSTROUTING -o enp2s0 -j MASQUERADE
        sudo iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
        sudo iptables -A FORWARD -i br0 -o enp2s0 -j ACCEPT
gdb2vm:
        sudo qemu-system-x86_64 $(QEMU_OPTS) $(VM2) -s -S

set: bridge dnsmasq

dnsmasq:
        sudo dnsmasq --strict-order \
                --interface=br0 \
                --listen-address=10.0.1.1 \
                --dhcp-host=52:54:00:12:34:50,10.0.1.101 \
                --dhcp-host=52:54:00:12:34:51,10.0.1.102 \
                --except-interface=lo \
                --except-interface=enp2s0 \
                --except-interface=wlp1s0 \
                --bind-interfaces \
                --dhcp-range=10.0.1.100,10.0.1.200 \
                --conf-file="" \
                --pid-file=/var/run/qemu-dnsmasq-br0.pid \
                --dhcp-leasefile=/var/run/qemu-dnsmasq-br0.lease \
                --dhcp-no-override

ssh1vm:
        ssh root@10.0.1.151
ssh2vm:
        ssh root@10.0.1.152

.PHONY: bridge boot1vm dnsmasq gdb2vm set ssh1vm ssh2vm
