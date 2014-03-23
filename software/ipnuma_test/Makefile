SHELL = /bin/sh

OBJS1 = ipnuma_client.o
OBJS2 = ipnuma_server.o
CFLAG = -Wall -g
CC = gcc
INCLUDE =
LIBS =

all: ipnuma_client ipnuma_server

ipnuma_client: ${OBJS1}
	${CC} ${CFLAGS} ${INCLUDES} -o $@ ${OBJS1} ${LIBS}

ipnuma_server: ${OBJS2}
	${CC} ${CFLAGS} ${INCLUDES} -o $@ ${OBJS2} ${LIBS}

clean:
	-rm -f *.o core *.core ipnuma_client ipnuma_server

.c.o:
	${CC} ${CFLAGS} ${INCLUDES} -c $<

