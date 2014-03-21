SHELL = /bin/sh

OBJS = ipnuma_client.o
CFLAG = -Wall -g
CC = gcc
INCLUDE =
LIBS =

all: ipnuma_client

ipnuma_client: ${OBJS}
	${CC} ${CFLAGS} ${INCLUDES} -o $@ ${OBJS} ${LIBS}

clean:
	-rm -f *.o core *.core ipnuma_client

.c.o:
	${CC} ${CFLAGS} ${INCLUDES} -c $<

