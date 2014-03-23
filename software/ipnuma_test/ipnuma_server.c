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
	int sock_fd;
	struct sockaddr_in addr;
	int *count;
	int i;
	char buf[BUFSIZE], dest_ip[256];

	// receive
	sock_fd = socket(AF_INET, SOCK_DGRAM, 0);
	addr.sin_family = AF_INET;
	addr.sin_port = htons(APP_PORT);
	addr.sin_addr.s_addr = INADDR_ANY;
	bind(sock_fd, (struct sockaddr *)&addr, sizeof(addr));

	i = 0;

	while (1) {
		if (recv(sock_fd, buf, sizeof(buf), 0) < 0) {
			perror("sendto()");
		}
		printf("%d\n", ++i);
	}
	exit(EXIT_SUCCESS);
}

