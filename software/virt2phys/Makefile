ifneq ($(KERNELRELEASE),)
obj-m		:= virt2phys.o
else
KDIR		:= /lib/modules/$(shell uname -r)/build/
PWD		:= $(shell pwd)

all:
	$(MAKE) -C $(KDIR) SUBDIRS=$(PWD) V=1 modules

clean:
	$(MAKE) -C $(KDIR) SUBDIRS=$(PWD) clean 

install:
	install -m 644 $(PWD)/*.ko /lib/modules/`uname -r`/kernel/drivers/misc
	if [ -d /etc/udev/rules.d -a ! -f /etc/udev/rules.d/99-virt2phys.rules ] ; then \
		install -m 644 99-virt2phys.rules /etc/udev/rules.d ; \
	fi
	if [ -d /etc/modules-load.d -a ! -f /etc/modules-load.d/virt2phys.conf ] ; then \
		install -m 644 virt2phys.conf /etc/modules-load.d ; \
	fi
	depmod -a
endif
