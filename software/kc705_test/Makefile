SHELL = /bin/sh

OBJS1 = ipnuma_client.o
OBJS2 = ipnuma_server.o
OBJS3 = mem.o
OBJS4 = demo1.o
OBJS5 = user.o
OBJS6 = rmem.o
CFLAGS = -Wall -g
CC = gcc
INCLUDE =
LIBS =

all: ipnuma_client ipnuma_server mem demo1 user rmem

ipnuma_client: ${OBJS1}
	${CC} ${CFLAGS} ${INCLUDES} -o $@ ${OBJS1} ${LIBS}

ipnuma_server: ${OBJS2}
	${CC} ${CFLAGS} ${INCLUDES} -o $@ ${OBJS2} ${LIBS}

mem: ${OBJS3}
	${CC} ${CFLAGS} ${INCLUDES} -o $@ ${OBJS3} ${LIBS}

demo1: ${OBJS4}
	${CC} ${CFLAGS} ${INCLUDES} -o $@ ${OBJS4} ${LIBS}

user: ${OBJS5}
	${CC} ${CFLAGS} ${INCLUDES} -o $@ ${OBJS5} ${LIBS}

rmem: ${OBJS6}
	${CC} ${CFLAGS} ${INCLUDES} -o $@ ${OBJS6} ${LIBS}

clean:
	-rm -f *.o core *.core ipnuma_client ipnuma_server mem demo1 user rmem

.c.o:
	${CC} ${CFLAGS} ${INCLUDES} -c $<

