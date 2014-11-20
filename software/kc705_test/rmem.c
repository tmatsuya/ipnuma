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
unsigned long pa, mem0p, mmuaddr, baraddr;


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
	int rdata = -1, rdata2, sdata = 0;
	int fd, i;
	unsigned int st,len=0x40000,poff;

	init_numa();
	printf("baraddr=%x,mmuaddr=%x\n", baraddr, mmuaddr);

	st = mmuaddr;
	poff=st % 4096;
	if ((fd=open(MEM_DEVICE,O_RDWR)) <0) {
		fprintf(stderr,"cannot open %s\n",MEM_DEVICE);
		return 1;
	}

	printf("remote physical address?");
	scanf("%lx", &mem0p);
	i = htonl(mem0p);
	if ( ioctl( numa_fd, IPNUMA_IOCTL_SETIFV4ADDR, &i) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}

	fprintf(stdout,"mmap: start %08X len:%08X Total=%dMB\n",st-poff,len+poff, len/1000);
	mmapped = mmap(0, len+poff, PROT_READ|PROT_WRITE, MAP_SHARED, fd, st-poff);
	if(mmapped==MAP_FAILED) {
		fprintf(stderr,"cannot mmap\n");
		return 1;
	}


#ifdef NO
	rdata2 = rdata;
	*(int *)(mmapped + 0x37760) = sdata;
#endif

	munmap(mmapped,len);
	close(fd);
	return (0);
}
