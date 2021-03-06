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

#define	MEM_DEVICE	"/dev/mem"

int main(int argc,char **argv)
{
	unsigned char *mmapped;
	int fd, i;
	unsigned int st,len=0x1000,poff;

	st = 0x80000000;
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

	for (i=0x40; i<=0xff; i+=4)
		*(int *)(mmapped + i) = i<<8 |  i;
	munmap(mmapped,len);
	close(fd);
	return (0);
}
