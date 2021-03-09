sett_up:
	sudo apt install qemu qemu-kvm bridge-utils iptables dnsmasq &&\
	echo "INSTALAT CU SUCCES!" ||\
	echo "EROARE LA INSTALARE!"
QEMU_OPTS = -machine type=q35,accel=kvm \
        -object rng-random,id=rng0,filename=/dev/urandom \
        -device virtio-rng-pci,rng=rng0 \
        -cpu host \
        -smp 3 -m 1536 \
        -drive file=overlay.qcow,format=qcow2,index=0,media=disk \
        -nic tap,ifname=tap0,script=no,downscript=no \
        -curses
boot:
        sudo qemu-system-x86_64 $(QEMU_OPTS)

bridge:
        #make tap interface
        sudo ip tuntap add dev tap0 mode tap group kvm
        sudo ip link set dev tap0 up promisc on
        sudo ip addr add 0.0.0.0 dev tap0
        #make bridge
        sudo ip link add br0 type bridge
        sudo ip link set br0 up
        sudo ip link set tap0 master br0
        #disable stp becouse there is only one bridge
        sudo bash -c "echo 0 > /sys/class/net/br0/bridge/stp_state"
        sudo ip addr add 10.0.1.1/24 dev br0
        #packet forwarding and NAT(enp2s0=network interface)
        sudo sysctl net.ipv4.conf.tap0.proxy_arp=1
        sudo sysctl net.ipv4.conf.enp2s0.proxy_arp=1
        sudo sysctl net.ipv4.ip_forward=1 #enable forwarding in kernel
        #firewall rules
        sudo iptables -t nat -A POSTROUTING -o enp2s0 -j MASQUERADE
        sudo iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
        sudo iptables -A FORWARD -i br0 -o enp2s0 -j ACCEPT
gdb:
        sudo qemu-system-x86_64 $(QEMU_OPTS) -s -S

set: bridge dnsmasq

dnsmasq:
        sudo dnsmasq --strict-order \
                --interface=br0 \
                --listen-address=10.0.1.1 \
                --except-interface=lo \
                --except-interface=enp2s0 \
                --except-interface=wlp1s0 \
                --bind-interfaces \
                --dhcp-range=10.0.1.100,10.0.1.200 \
                --conf-file="" \
                --pid-file=/var/run/qemu-dnsmasq-br0.pid \
                --dhcp-leasefile=/var/run/qemu-dnsmasq-br0.lease \
                --dhcp-no-override

make_serial_pipes:
        mkfifo pipe1.in
        mkfifo pipe1.out

.PHONY: bridge boot make_serial_pipe dnsmasq gdb set sett_up
