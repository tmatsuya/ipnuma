SHELL = /bin/sh

OBJS1 = socket_pingpong.o util.c
OBJS2 = ipnuma_pingpong.o util.c
CFLAGS = -Wall
CC = gcc
INCLUDE =
LIBS =

all: socket_pingpong ipnuma_pingpong

socket_pingpong: ${OBJS1}
	${CC} ${CFLAGS} ${INCLUDES} -o $@ ${OBJS1} ${LIBS}

ipnuma_pingpong: ${OBJS2}
	${CC} ${CFLAGS} ${INCLUDES} -o $@ ${OBJS2} ${LIBS}

clean:
	-rm -f *.o core *.core socket_pingpong ipnuma_pingpong

.c.o:
	${CC} ${CFLAGS} ${INCLUDES} -c $<

