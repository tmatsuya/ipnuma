#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <arpa/inet.h>

#include "util.h"
#include "../driver/ipnuma_ioctl.h"

#define	USE_MEMCPY
//#define DEBUG

#define	NUMA_DEVICE	"/dev/ipnuma/0"
#define	MEM_DEVICE	"/dev/mem"

TimeWatcher tw;
int numa_fd = -1;
unsigned long pa, mem0p, baraddr;
unsigned char if_ipv4[4], if_mac[6];

int init_numa()
{
	if (numa_fd <0)
		if ((numa_fd=open(NUMA_DEVICE,O_RDONLY)) <0) {
			fprintf(stderr,"cannot open %s\n",NUMA_DEVICE);
			return 1;
		}
	if ( ioctl( numa_fd, IPNUMA_IOCTL_GETPADDR, &pa) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}
	printf("physical address=%012lX\n", pa);
	if ( ioctl( numa_fd, IPNUMA_IOCTL_GETIFV4ADDR, if_ipv4) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}
	printf("if_ipv4=%d.%d.%d.%d\n", if_ipv4[0], if_ipv4[1], if_ipv4[2], if_ipv4[3]);
	if ( ioctl( numa_fd, IPNUMA_IOCTL_GETIFMACADDR, if_mac) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}
	printf("if_mac=%02x:%02x:%02x:%02x:%02x:%02x\n", if_mac[0], if_mac[1], if_mac[2], if_mac[3], if_mac[4], if_mac[5] ); 
	if ( ioctl( numa_fd, IPNUMA_IOCTL_GETMEM0PADDR, &mem0p) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}
	printf("mem0paddr=%012lX\n", mem0p);
	if ( ioctl( numa_fd, IPNUMA_IOCTL_GETBARADDR, &baraddr) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}
	printf("baraddr=%012lX\n", baraddr);

	return 0;
}

int main(int argc,char **argv)
{
	unsigned char *mmapped;
	int i, j, d, r, fd;
	unsigned int st=0xe9000000,len=0x40000,poff;

	if (argc!=2) {
		fprintf(stderr,"%s [s|c]\n", argv[0]);
		return 1;
	}

	init_numa();

	st = baraddr;
	printf("%X\n", st);
	poff=st % 4096;
	if ((fd=open(MEM_DEVICE,O_RDWR)) <0) {
		fprintf(stderr,"cannot open %s\n",MEM_DEVICE);
		return 1;
	}
	fprintf(stdout,"mmap: start %08X len:%08X Total=%dMB\n",st-poff,len+poff, len/1000);

	mmapped = mmap(0, len+poff, PROT_READ|PROT_WRITE, MAP_SHARED, fd, st-poff);
	if(mmapped==MAP_FAILED) {
		fprintf(stderr,"cannot mmap\n");
		return 1;
	}

	printf("remote physical address?");
	scanf("%lx", &mem0p);

	if ( ioctl( numa_fd, IPNUMA_IOCTL_SETMEM0PADDR, &mem0p) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}

//	init_numa();

//	if ( !strcmp( argv[1], "s") ) {
		for (i=0; ;++i) {
			*(int *)(mmapped + 0x37760) = i;
			usleep(1000);
		}
//	}
//	if ( !strcmp( argv[1], "c") ) {
//		for (i=0; ;++i) {
//			*(int *)(mmapped) = i;
//			usleep(10000);
//		}
//	}
	munmap(mmapped,len);
	start(&tw);
	end(&tw);
	print_time_sec(&tw);

	close(fd);
}
