#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <memory.h>

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define		SERV_PORT	3422		// USB over IP
#define		BUFSIZE		1024

// sudo arp -s 10.0.21.101 00:30:1b:a0:a4:8e

int main(int argc, char **argv)
{
	int sockfd;
	struct sockaddr_in servaddr;
	int i, j, dwlen;
	char sendline[BUFSIZE], dest_ip[256];

	if ( argc != 2) {
		fprintf( stderr, "usage: %s [dest IP]\n", argv[0] );
		exit(-1);
	}

	strcpy( dest_ip, argv[1] );

	memset(&servaddr, 0, sizeof(servaddr));
	servaddr.sin_family = AF_INET;
	servaddr.sin_port = htons(SERV_PORT);
	inet_aton(dest_ip, &servaddr.sin_addr);

	sockfd = socket(AF_INET, SOCK_DGRAM, 0);
	if(sockfd < 0){
		perror("socket()");
		exit(EXIT_FAILURE);
	}

	dwlen = 16;

	sendline[ 0] = 0xa1;
	sendline[ 1] = 0x11;
	sendline[ 2] = 0x00;
	sendline[ 3] = 0x00;

	sendline[ 4] = 0x80|dwlen;// write command(b7), 32bit(b6), length(b5-b0)=4DW
	sendline[ 5] = 0xff;	// LBE(b8-4), FBE(b3-0)

	sendline[ 6] = 0xd0;	// ADDR=0xD0000000
	sendline[ 7] = 0x00;
	sendline[ 8] = 0x00;
	sendline[ 9] = 0x00;

	for ( j=1 ; ; ++j) {
		for (i=0; i<dwlen; ++i) {
			sendline[ 10+i*4+0 ] = ((i+j)&0xf)*0x10+0;
			sendline[ 10+i*4+1 ] = ((i+j)&0xf)*0x10+1;
			sendline[ 10+i*4+2 ] = ((i+j)&0xf)*0x10+2;
			sendline[ 10+i*4+3 ] = ((i+j)&0xf)*0x10+3;
		}
		sendline[ 10+i*4+0 ] = 0;
		if (sendto(sockfd, sendline, 10+(4*dwlen)+1, 0, (struct sockaddr *)&servaddr, sizeof(servaddr)) < 0){
			perror("sendto()");
		}
		usleep(1);
	}

	exit(EXIT_SUCCESS);
}
