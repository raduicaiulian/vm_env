KDIR := /lib/modules/$(shell uname -r)/build

obj-m += netlinkKernel.o

all:
		$(MAKE) -C $(KDIR) SUBDIRS=$(PWD) modules
		gcc -o netlinkUser netlinkUser.c

clean:
		rm -rf *.o *.ko *.mod.* *.cmd .module* modules* Module* .*.cmd .tmp*
		make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
		rm netlinkUser
