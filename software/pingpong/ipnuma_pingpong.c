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

#include "util.h"
#include "../driver/ipnuma_ioctl.h"

#define	USE_MEMCPY
//#define DEBUG

#define	NUMA_DEVICE	"/dev/ipnuma/0"
#define	MEM_DEVICE	"/dev/mem"

volatile int rdata __attribute__((aligned(64)));
TimeWatcher tw;
int numa_fd = -1;
unsigned long long pa, mem0p = 0LL, baraddr;
unsigned char if_ipv4[4], if_mac[6];
unsigned char dest_ipv4[4], dest_mac[6];

unsigned char srv_ipv4[4] = {192,168,1,1};
unsigned char srv_mac[6]  = {0x00,0x37,0x76,0x10,0x00,0x01};
unsigned char cli_ipv4[4] = {192,168,1,2};
unsigned char cli_mac[6]  = {0x00,0x37,0x76,0x10,0x00,0x02};


int init_numa(int server_flag)
{
	if (numa_fd <0)
		if ((numa_fd=open(NUMA_DEVICE,O_RDONLY)) <0) {
			fprintf(stderr,"cannot open %s\n",NUMA_DEVICE);
			return 1;
		}
	if (server_flag) {
		memcpy(if_ipv4, srv_ipv4, 4);
		memcpy(if_mac,  srv_mac, 6);
		memcpy(dest_ipv4, cli_ipv4, 4);
		memcpy(dest_mac, cli_mac, 6);
	} else {
		memcpy(if_ipv4, cli_ipv4, 4);
		memcpy(if_mac,  cli_mac, 6);
		memcpy(dest_ipv4, srv_ipv4, 4);
		memcpy(dest_mac, srv_mac, 6);
	}
	if ( ioctl( numa_fd, IPNUMA_IOCTL_GETPADDR, &pa) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}
	printf("physical address=%012llX\n", pa);
	if ( ioctl( numa_fd, IPNUMA_IOCTL_SETIFV4ADDR, if_ipv4) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}
	printf("if_ipv4=%d.%d.%d.%d\n", if_ipv4[0], if_ipv4[1], if_ipv4[2], if_ipv4[3]);
	if ( ioctl( numa_fd, IPNUMA_IOCTL_SETIFMACADDR, if_mac) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}
	printf("if_mac=%02x:%02x:%02x:%02x:%02x:%02x\n", if_mac[0], if_mac[1], if_mac[2], if_mac[3], if_mac[4], if_mac[5] ); 
	if ( ioctl( numa_fd, IPNUMA_IOCTL_SETDESTV4ADDR, dest_ipv4) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}
	printf("dest_ipv4=%d.%d.%d.%d\n", dest_ipv4[0], dest_ipv4[1], dest_ipv4[2], dest_ipv4[3]);
	if ( ioctl( numa_fd, IPNUMA_IOCTL_SETDESTMACADDR, dest_mac) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}
	printf("dest_mac=%02x:%02x:%02x:%02x:%02x:%02x\n", dest_mac[0], dest_mac[1], dest_mac[2], dest_mac[3], dest_mac[4], dest_mac[5] ); 
	if ( ioctl( numa_fd, IPNUMA_IOCTL_GETMEM0PADDR, &mem0p) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}
	printf("mem0paddr=%012llX\n", mem0p);
	if ( ioctl( numa_fd, IPNUMA_IOCTL_GETBARADDR, &baraddr) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}
	printf("baraddr=%012llX\n", baraddr);

	return 0;
}

int main(int argc,char **argv)
{
	unsigned char *mmapped;
	int rdata2, sdata = 0;
	int fd;
	unsigned int st,len=0x40000,poff;
	struct timespec treq;

	if (argc!=2) {
		fprintf(stderr,"%s [s|c]\n", argv[0]);
		return 1;
	}

	pa = (unsigned long)&rdata;
	if ( !strcmp( argv[1], "s") )
		init_numa(1);
	else
		init_numa(0);

	rdata = -1;
	st = baraddr;
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

	printf("local physical address=%012llX\n", pa);
	printf("remote physical address?");
	scanf("%llx", &mem0p);

	if ( ioctl( numa_fd, IPNUMA_IOCTL_SETMEM0PADDR, &mem0p) < 0 ) {
		fprintf(stderr,"cannot IOCTL\n");
		return 1;
	}

//	init_numa();
	treq.tv_sec = (time_t)0;
	treq.tv_nsec = 1;

	if ( !strcmp( argv[1], "s") ) {
		while (rdata < 0) {
				asm volatile ("clflush (%0)" :: "r"(&rdata));
				asm volatile("mfence":::"memory");
		}
		start(&tw);
		while (rdata < 2000000) {
			rdata2 = rdata;
			*(int *)(mmapped + (mem0p & 0xfff)) = sdata;
			do {
				asm volatile ("clflush (%0)" :: "r"(&rdata));
//				usleep(1);
//				nanosleep(&treq, NULL);
//				clock_nanosleep(CLOCK_REALTIME, 0, &treq, NULL);
//				asm volatile("rep; nop" ::: "memory");
				asm volatile("mfence":::"memory");
			} while (rdata == rdata2);
			sdata = rdata+1;
		
		}
		end(&tw);
		printf("loop=%lld\n", rdata);
		print_time_sec(&tw);
	}
	if ( !strcmp( argv[1], "c") ) {
		sdata = 0;
		while (1) {
			rdata2 = rdata;
			*(int *)(mmapped + (mem0p & 0xfff)) = sdata;
			do {
				asm volatile ("clflush (%0)" :: "r"(&rdata));
//				usleep(1);
//				nanosleep(&treq, NULL);
//				clock_nanosleep(CLOCK_REALTIME, 0, &treq, NULL);
//				asm volatile("rep; nop" ::: "memory");
				asm volatile("mfence":::"memory");
			} while (rdata == rdata2);
			sdata = rdata+1;
		}
	}
	munmap(mmapped,len);

	close(fd);
	return (0);
}
