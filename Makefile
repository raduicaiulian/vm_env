VM1 = -drive file=overlay.qcow,format=qcow2,index=0,media=disk \
        -nic tap,ifname=tap0,script=no,downscript=no,mac=52:54:00:12:34:50

VM2 = -drive file=overlay1.qcow,format=qcow2,index=1,media=disk \
        -nic tap,ifname=tap1,script=no,downscript=no,mac=52:54:00:12:34:51

QEMU_OPTS = -machine type=q35,accel=kvm \
        -object rng-random,id=rng0,filename=/dev/urandom \
        -device virtio-rng-pci,rng=rng0 \
        -cpu host \
        -smp 2 -m 1024 \
        -vga none -display none
1VM_IP = 10.0.1.101
2VM_IP = 10.0.1.102

set: bridge dnsmasq

boot1vm:
        sudo qemu-system-x86_64 $(QEMU_OPTS) $(VM1) &
boot2vm:
        sudo qemu-system-x86_64 $(QEMU_OPTS) $(VM2) &

bridge:
        if [ $$(ip addr | grep br0 | wc -l) -gt 3 ] ; then
                echo "bridge already exist!!!";
                echo "$$(ip addr | grep br0)";
        else
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
        fi

gdb2vm:
        sudo qemu-system-x86_64 $(QEMU_OPTS) $(VM2) -s &# -S to stop execution at boot

debug:  bridge dnsmasq boot1vm gdb2vm
        while [ 1 -eq 1 ] ; do echo "wait for 1 vm..."; ping -c1 $(1VM_IP) | grep -q " 1 received" && break; done; echo "1 vm is on"
        while [ 1 -eq 1 ] ; do echo "wait for 2 vm..."; ping -c1 $(2VM_IP) | grep -q " 1 received" && break; done; echo "2 vm is on"
        sleep 10
        ssh -t root@$(1VM_IP) "gdb -ex 'target remote 192.168.1.243:1234' /boot/kernel/kernel"

dnsmasq:
        if [ $$(ps -e | grep dnsmasq | wc -l) -eq 1 ] ; then
                echo "DHCP server already runing!!!";
                echo $$(ps -e | grep dnsmasq);
        else
                sudo dnsmasq --strict-order \
                        --interface=br0 \
                        --listen-address=10.0.1.1 \
                        --dhcp-host=52:54:00:12:34:50,$(1VM_IP) \
                        --dhcp-host=52:54:00:12:34:51,$(2VM_IP) \
                        --except-interface=lo \
                        --except-interface=enp2s0 \
                        --except-interface=wlp1s0 \
                        --bind-interfaces \
                        --dhcp-range=10.0.1.100,10.0.1.200 \
                        --conf-file="" \
                        --pid-file=/var/run/qemu-dnsmasq-br0.pid \
                        --dhcp-leasefile=/var/run/qemu-dnsmasq-br0.lease \
                        --dhcp-no-override
        fi

ssh1vm:
        ssh root@$(1VM_IP)
ssh2vm:
        ssh root@$(2VM_IP)
#fails if one of vms is paused by debugger
poweroff:
        ping -c1 $(1VM_IP) | grep -q " 1 received" && ssh root@$(1VM_IP) poweroff
        ping -c1 $(2VM_IP) | grep -q " 1 received" && ssh root@$(2VM_IP) poweroff
        while [ true ] ; do
                if [ $$(ps -e | grep qemu | wc -l) -eq 0 ] ; then
                        break;
                fi;
        done;
                
.PHONY: bridge boot1vm boot2vm dnsmasq gdb2vm ssh1vm ssh2vm debug set

#to set in /etc/dnsmasq.conf
#dhcp-host=eth0,00:22:43:4b:18:43,192.168.0.7
#dhcp-host=eth1,00:22:43:4b:18:43,192.168.1.7

.ONESHELL:#required in order to write if/while as we were in a shell script
.SILENT: dnsmasq bridge
.SILENT: dnsmasq bridge
