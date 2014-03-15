#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <memory.h>

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define		APP_PORT	3422		// USB over IP
#define		BUFSIZE		4

int main(int argc, char **argv)
{
	int sock_s, sock_r;
	struct sockaddr_in addr_s, addr_r;
	int *count_s, *count_r;
	int i;
	char buf_s[BUFSIZE], buf_r[BUFSIZE], dest_ip[256];

	if ( argc != 2) {
		fprintf( stderr, "usage: %s [dest IP]\n", argv[0] );
		exit(-1);
	}

	strcpy( dest_ip, argv[1] );

	// send
	memset(&addr_s, 0, sizeof(addr_s));
	addr_s.sin_family = AF_INET;
	addr_s.sin_port = htons(APP_PORT);
	inet_aton(dest_ip, &addr_s.sin_addr);
	sock_s = socket(AF_INET, SOCK_DGRAM, 0);
	if(sock_s < 0){
		perror("socket()");
		exit(EXIT_FAILURE);
	}

	// receive
	sock_r = socket(AF_INET, SOCK_DGRAM, 0);
	addr_r.sin_family = AF_INET;
	addr_r.sin_port = htons(APP_PORT);
	addr_r.sin_addr.s_addr = INADDR_ANY;
	bind(sock_r, (struct sockaddr *)&addr_r, sizeof(addr_r));

	count_s = (int *)&buf_s[BUFSIZE-4];
	count_r = (int *)&buf_r[BUFSIZE-4];

	*count_s = 0;
	*count_r = 0;
	i = 0;

	while (*count_s < 200000) {
		if (sendto(sock_s, buf_s, BUFSIZE, 0, (struct sockaddr *)&addr_s, sizeof(addr_s)) < 0){
			perror("sendto()");
		}

		if (recv(sock_r, buf_r, sizeof(buf_r), 0) < 0) {
			perror("sendto()");
		}
		*count_s = *count_r + 1;
		++i;
	}
	printf("%d,%d,%d\n", i, *count_s, *count_r);

	exit(EXIT_SUCCESS);
}

