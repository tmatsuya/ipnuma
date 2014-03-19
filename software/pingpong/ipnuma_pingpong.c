#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <arpa/inet.h>

#define	USE_MEMCPY
//#define DEBUG

#define	MEM_DEVICE	"/dev/mem"

int main(int argc,char **argv)
{
	unsigned int *mmapped, *buf;
	int i, j, d, r, fd;
	unsigned int st=0xe9000000,len=0x8000,poff;
	if (argc!=3) {
		fprintf(stderr,"%s address r|w\n", argv[0]);
		return 1;
	}
	st = strtol( argv[1], NULL, 16);
	printf("%X\n", st);
	poff=st % 4096;
	buf = malloc(len);
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
	if ( !strcmp( argv[2], "w") ) {
		for ( i=0; i < 1000; ++i )
#ifdef USE_MEMCPY
			memcpy(mmapped, buf, len);
#else
			for ( j=0; j < len/4; ++j ) {
				*(int *)(mmapped  + j) = j;
			}
#endif
	}
	if ( !strcmp( argv[2], "r") ) {
		for ( i=0; i < 1000; ++i )
#ifdef USE_MEMCPY
			memcpy(buf, mmapped, len);
#else
			for ( j=0; j < len/4; ++j ) {
				if ( *(int *)(mmapped  + j) != j )
					fprintf(stderr,"data error j=%x,mem=%x\n", j, *(int *)(mmapped + j));
			}
#endif
	}
	munmap(mmapped,len);
	close(fd);
}
