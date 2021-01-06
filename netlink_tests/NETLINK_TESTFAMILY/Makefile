KDIR := /lib/modules/$(shell uname -r)/build

obj-m += kernel_module.o

all:
		$(MAKE) -C $(KDIR) SUBDIRS=$(PWD) modules
		gcc -o user_exec user_exec.c

clean:
		rm -rf *.o *.ko *.mod.* *.cmd .module* modules* Module* .*.cmd .tmp*
		make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
		rm user_exec
insmod:
	sudo insmod kernel_module.ko
rmmod:
	sudo rmmod kernel_module
lsmod:
	lsmod | grep kernel_module | wc -l
