#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <arpa/inet.h>

//#define DEBUG

#define	MEM_DEVICE	"/dev/virt2phys"
#define	BUF_SIZE	(256)

int main(int argc,char **argv)
{
	unsigned long long pa;
	int i, fd;
	if ((fd=open(MEM_DEVICE,O_RDONLY)) <0) {
		fprintf(stderr,"cannot open %s\n",MEM_DEVICE);
		return 1;
	}
	pa = (unsigned long long)&i;
	if ( ioctl( fd, 1, &pa) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}
	printf("physical address=%012llX\n", pa);
	close(fd);

	i = 123;
	while (1) {
		printf ("i=%d, &i=%p, Physical Address=%012llx\n", i, &i, pa);
		usleep(10000);
	}
}
