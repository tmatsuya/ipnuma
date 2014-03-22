#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <arpa/inet.h>
#include "ipnuma_ioctl.h"

//#define DEBUG

#define	MEM_DEVICE	"/dev/ipnuma/0"
#define	BUF_SIZE	(256)

int main(int argc,char **argv)
{
	unsigned long pa, mem0p;
	int fd, i;
	unsigned char if_ipv4[4], if_mac[6];
	if ((fd=open(MEM_DEVICE,O_RDONLY)) <0) {
		fprintf(stderr,"cannot open %s\n",MEM_DEVICE);
		return 1;
	}
	if ( ioctl( fd, IPNUMA_IOCTL_GETPADDR, &pa) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}
	printf("physical address=%012lX\n", pa);
	if ( ioctl( fd, IPNUMA_IOCTL_GETIFV4ADDR, if_ipv4) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}
	printf("if_ipv4=%d.%d.%d.%d\n", if_ipv4[0], if_ipv4[1], if_ipv4[2], if_ipv4[3]);
	if ( ioctl( fd, IPNUMA_IOCTL_GETIFMACADDR, if_mac) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}
	printf("if_mac=%02x:%02x:%02x:%02x:%02x:%02x\n", if_mac[0], if_mac[1], if_mac[2], if_mac[3], if_mac[4], if_mac[5] ); 
	if ( ioctl( fd, IPNUMA_IOCTL_GETMEM0PADDR, &mem0p) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}
	printf("mem0paddr=%012lX\n", mem0p);
	close(fd);

	i = 123;
	while (0) {
		printf ("i=%d, &i=%p, Physical Address=%012lx\n", i, &i, pa);
		usleep(10000);
	}
}
