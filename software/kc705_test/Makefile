SHELL = /bin/sh

OBJS1 = ipnuma_client.o
OBJS2 = ipnuma_server.o
OBJS3 = mem.o
OBJS4 = demo1.o
CFLAGS = -Wall -g
CC = gcc
INCLUDE =
LIBS =

all: ipnuma_client ipnuma_server mem demo1

ipnuma_client: ${OBJS1}
	${CC} ${CFLAGS} ${INCLUDES} -o $@ ${OBJS1} ${LIBS}

ipnuma_server: ${OBJS2}
	${CC} ${CFLAGS} ${INCLUDES} -o $@ ${OBJS2} ${LIBS}

mem: ${OBJS3}
	${CC} ${CFLAGS} ${INCLUDES} -o $@ ${OBJS3} ${LIBS}

demo1: ${OBJS4}
	${CC} ${CFLAGS} ${INCLUDES} -o $@ ${OBJS4} ${LIBS}

clean:
	-rm -f *.o core *.core ipnuma_client ipnuma_server mem demo1

.c.o:
	${CC} ${CFLAGS} ${INCLUDES} -c $<

