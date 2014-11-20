#include <sys/types.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <arpa/inet.h>
#include <time.h>

#include "../driver/ipnuma_ioctl.h"

#define	USE_MEMCPY
//#define DEBUG

#define	NUMA_DEVICE	"/dev/ipnuma/0"
#define	MEM_DEVICE	"/dev/mem"

int numa_fd = -1;
unsigned long pa, mem0p, mmuaddr, baraddr, sdata;


int init_numa(void)
{
	if ((numa_fd=open(NUMA_DEVICE,O_RDONLY)) <0) {
		fprintf(stderr,"cannot open %s\n",NUMA_DEVICE);
		return 1;
	}
	if ( ioctl( numa_fd, IPNUMA_IOCTL_GETIFV4ADDR, &mmuaddr) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}
	mmuaddr = ntohl(mmuaddr);

	if ( ioctl( numa_fd, IPNUMA_IOCTL_GETBARADDR, &baraddr) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}
	return 0;
}

int main(int argc,char **argv)
{
	unsigned char *mmapped;
	int fd, i;
	unsigned int st,len=0x100,poff;

	init_numa();
	printf("baraddr=%x,mmuaddr=%x\n", baraddr, mmuaddr);

	st = baraddr;
	poff=st % 4096;
	if ((fd=open(MEM_DEVICE,O_RDWR)) <0) {
		fprintf(stderr,"cannot open %s\n",MEM_DEVICE);
		return 1;
	}

	mmapped = mmap(0, len+poff, PROT_READ|PROT_WRITE, MAP_SHARED, fd, st-poff);
	if(mmapped==MAP_FAILED) {
		fprintf(stderr,"cannot mmap\n");
		return 1;
	}

	i = htonl(0xd0000000);
	if ( ioctl( numa_fd, IPNUMA_IOCTL_SETIFV4ADDR, &i) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}

	while (1) {
		printf("data?");
		scanf("%d", &sdata);
		*(int *)(mmapped + 0) = sdata;
	}

	munmap(mmapped,len);
	close(fd);
	return (0);
}
