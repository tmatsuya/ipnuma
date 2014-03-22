#ifndef ___ipnuma_ioctl_h_included_
#define ___ipnuma_ioctl_h_included_
      
#include <linux/ioctl.h>
  
/* 
 * /dev/ipnuma に対する ioctl() コマンドに使うマジックナンバー
 *
 * /usr/src/linux/Documentation/ioctl-number.txt に記述されている 
 * Code とぶつからないものを選ぶ
 */
#define IPNUMA_IOCTL_MAGIC  0xAE
 

#define IPNUMA_IOCTL_RESET		_IOC( _IOC_NONE,  IPNUMA_IOCTL_MAGIC,  0, 0 )
#define IPNUMA_IOCTL_GETPADDR		_IOC( _IOC_READ,  IPNUMA_IOCTL_MAGIC,  1, sizeof( long ) )
#define IPNUMA_IOCTL_GETIFV4ADDR	_IOC( _IOC_READ,  IPNUMA_IOCTL_MAGIC,  2, 4 )
#define IPNUMA_IOCTL_SETIFV4ADDR	_IOC( _IOC_WRITE, IPNUMA_IOCTL_MAGIC,  3, 4 )
#define IPNUMA_IOCTL_GETIFMACADDR	_IOC( _IOC_READ,  IPNUMA_IOCTL_MAGIC,  4, 6 )
#define IPNUMA_IOCTL_SETIFMACADDR	_IOC( _IOC_WRITE, IPNUMA_IOCTL_MAGIC,  5, 6 )
#define IPNUMA_IOCTL_GETDESTV4ADDR	_IOC( _IOC_READ,  IPNUMA_IOCTL_MAGIC,  6, 4 )
#define IPNUMA_IOCTL_SETDESTV4ADDR	_IOC( _IOC_WRITE, IPNUMA_IOCTL_MAGIC,  7, 4 )
#define IPNUMA_IOCTL_GETDESTMACADDR	_IOC( _IOC_READ,  IPNUMA_IOCTL_MAGIC,  8, 6 )
#define IPNUMA_IOCTL_SETDESTMACADDR	_IOC( _IOC_WRITE, IPNUMA_IOCTL_MAGIC,  9, 6 )
#define IPNUMA_IOCTL_GETMEM0PADDR	_IOC( _IOC_READ,  IPNUMA_IOCTL_MAGIC, 10, 8 )
#define IPNUMA_IOCTL_SETMEM0PADDR	_IOC( _IOC_WRITE, IPNUMA_IOCTL_MAGIC, 11, 8 )
#define IPNUMA_IOCTL_GETBARADDR		_IOC( _IOC_READ,  IPNUMA_IOCTL_MAGIC, 12, sizeof( long ) )


#endif


/* End of ipnumav_ioctl.h */
