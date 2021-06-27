VM1_IMG=vm1.qcow
VM2_IMG=vm2.qcow
HOST_IP=192.168.1.243

VM1 = -drive file=$(VM1_IMG),format=qcow2,index=0,media=disk \
	-nic tap,ifname=tap0,script=no,downscript=no,mac=52:54:00:12:34:50
	#-netdev user,id=nic0,net=10.0.1.103/2#test

VM2 = -drive file=$(VM2_IMG),format=qcow2,index=1,media=disk \
	-nic tap,ifname=tap1,script=no,downscript=no,mac=52:54:00:12:34:51

QEMU_OPTS = -machine type=q35,accel=kvm \
	-object rng-random,id=rng0,filename=/dev/urandom \
	-device virtio-rng-pci,rng=rng0 \
	-cpu host \
	-smp 2 -m 1024 \
	-vga none -display none 
	#-curses
1VM_IP = 10.0.1.101
2VM_IP = 10.0.1.102

# xxx the case when qemu failed to start due to wrong args is not treated
boot1vm: set 
	if [ $$(ps -ef | grep $(VM1_IMG) | wc -l) -eq 3 ] ;then
		echo "boot 1vm"
		sudo qemu-system-x86_64 $(QEMU_OPTS) $(VM1) &
		sleep 2 # the delay until qemu starts
	else
		echo "1vm is already on!";
	fi;

boot2vm: set
	if [ $$(ps -ef | grep $(VM2_IMG) | wc -l) -eq 3 ] ;then
		echo "boot 2vm";
		sudo qemu-system-x86_64 $(QEMU_OPTS) $(VM2) &
		sleep 2 # the delay until qemu starts
	else
		echo "2vm is already on!";
	fi;

gdb1vm:
	$$(nc -z $(1VM_IP) 22) || sudo qemu-system-x86_64 $(QEMU_OPTS) $(VM1) -s &

gdb2vm:
	$$(nc -z $(2VM_IP) 22) || sudo qemu-system-x86_64 $(QEMU_OPTS) $(VM2) -s &

debug:	bridge dnsmasq boot1vm gdb2vm
	until $$(nc -z $(1VM_IP) 22) ; do echo "wait for 1 vm..."; done; echo "1 vm is on"
	until $$(nc -z $(2VM_IP) 22) ; do echo "wait for 2 vm..."; done; echo "2 vm is on"
	#attach
	ssh -t root@$(1VM_IP) "gdb -ex 'target remote $(HOST_IP):1234' /boot/kernel/kernel"
 
attach:
	ssh -t root@$(1VM_IP) "gdb -ex 'target remote $(HOST_IP):1234' /boot/kernel/kernel" 

ssh1vm: boot1vm
	until $$(nc -z $(1VM_IP) 22) ; do echo "Waiting for 1vm to start"; sleep 1; done
	ssh root@$(1VM_IP)

ssh2vm: boot2vm
	until $$(nc -z $(2VM_IP) 22) ; do echo "Waiting for 2vm to start"; sleep 1; done
	ssh root@$(2VM_IP)

# xxx we use nc instead of ps,even if if is slower, because it ensures us  that poweroff command can be sent vi ssh
poff1vm:
	if ! $$(nc -z $(1VM_IP) 22) ; then
		echo "1vm is already off or it is paused by debugger!";
	else
		ssh root@$(1VM_IP) poweroff &&
		until [ $$(ps -ef | grep $(VM1_IMG) | wc -l) -eq 3 ] ;do
			echo "waiting for 1vm to poweroff(do not boot it again meanwhile)"
			sleep 2
		done
	fi
	
poff2vm:
	if ! $$(nc -z $(2VM_IP) 22) ; then
		echo "2vm is already off or it is paused by debugger!"
	else
		ssh root@$(2VM_IP) poweroff &&
		until [ $$(ps -ef | grep $(VM2_IMG) | wc -l) -eq 3 ] ;do
			echo "waiting for 2vm to poweroff(do not boot it again meanwhile)"
			sleep 2
		done
	fi

status:
	echo "status:"
	ping -c1 $(1VM_IP) | grep -q " 1 received" && echo "1vm is on" || echo "1vm is off"
	ping -c1 $(2VM_IP) | grep -q " 1 received" && echo "2vm is on" || echo "2vm is off"


poweroff: poff1vm poff2vm
set: bridge dnsmasq

dnsmasq:
	if [ $$(ps -e | grep dnsmasq | wc -l) -eq 1 ] ; then
		echo "DHCP server already runing!!!";
		#echo $$(ps -e | grep dnsmasq);
	else
		sudo dnsmasq --strict-order \
			--interface=br0 \
			--listen-address=1
			--except-interface=wlp1s0 \
			--bind-interfaces \
			--dhcp-range=10.0.1.100,10.0.1.200 \
			--conf-file="" \
			--pid-file=/var/run/qemu-dnsmasq-br0.pid \
			--dhcp-leasefile=/var/run/qemu-dnsmasq-br0.lease \
			--dhcp-no-override
	fi

bridge: 
	if [ $$(ip addr | grep br0 | wc -l) -gt 3 ] ; then
		echo "bridge already exist!!!";
		#echo "$$(ip addr | grep br0)";
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
		sudo sysctl net.ipv5.conf.tap1.proxy_arp=1
		sudo sysctl net.ipv4.conf.enp2s0.proxy_arp=1
		sudo sysctl net.ipv4.ip_forward=1 #enable forwarding in kernel
		#firewall rules
		sudo iptables -t nat -A POSTROUTING -o enp2s0 -j MASQUERADE
		sudo iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
		sudo iptables -A FORWARD -i br0 -o enp2s0 -j ACCEPT
	fi

.PHONY: bridge boot1vm boot2vm dnsmasq gdb2vm ssh1vm ssh2vm debug set attach poff1vm poff2vm

#to set in /etc/dnsmasq.conf
#dhcp-host=eth0,00:22:43:4b:18:43,192.168.0.7
#dhcp-host=eth1,00:22:43:4b:18:43,192.168.1.7
.ONESHELL:#required in order to write if/while as we were in a shell script(do not execut each line on a different shell instance)
.SILENT: dnsmasq bridge boot1vm boot2vm ssh1vm ssh2vm poff1vm poff2vm status debug
#https://wiki.ar/chlinux.org/title/QEMU#Creating_and_managing_snapshots_via_the_monitor_console
