#include <linux/module.h>
#include <linux/miscdevice.h>
#include <linux/fs.h>
#include <linux/poll.h>
#include <linux/string.h>
#include <linux/pci.h>
#include <linux/wait.h>		/* wait_queue_head_t */
#include <linux/sched.h>	/* wait_event_interruptible, wake_up_interruptible */
#include <linux/interrupt.h>
#include <linux/version.h>
#include "ipnuma_ioctl.h"
#include "virt2phys.h"

#ifndef DRV_NAME
#define DRV_NAME	"ipnuma"
#endif

#define	DRV_VERSION	"0.0.1"
#define	ipnuma_DRIVER_NAME	DRV_NAME " IP-NUMA driver " DRV_VERSION
#define	DMA_BUF_SIZE	(1024*1024)

#if LINUX_VERSION_CODE > KERNEL_VERSION(3,8,0)
#define	__devinit
#define	__devexit
#define	__devexit_p
#endif

static DEFINE_PCI_DEVICE_TABLE(ipnuma_pci_tbl) = {
	{0x3776, 0x8010, PCI_ANY_ID, PCI_ANY_ID, 0, 0, 0 },
	{0,}
};
MODULE_DEVICE_TABLE(pci, ipnuma_pci_tbl);

static unsigned char *mmio0_ptr = 0L, *mmio1_ptr = 0L, *dma_virt_ptr = 0L;
static dma_addr_t dma_phys_ptr = 0L;
static unsigned long mmio0_start, mmio0_end, mmio0_flags, mmio0_len;
static unsigned long mmio1_start, mmio1_end, mmio1_flags, mmio1_len;
static struct pci_dev *pcidev = NULL;
static wait_queue_head_t write_q;
static wait_queue_head_t read_q;

extern unsigned long any_v2p(unsigned long);


static irqreturn_t ipnuma_interrupt(int irq, void *pdev)
{

	// not my interrupt
	if (1) {
		return IRQ_NONE;
	}

#ifdef DEBUG
	printk("%s\n", __func__);
#endif

	wake_up_interruptible( &read_q );

	return IRQ_HANDLED;
}

static int ipnuma_open(struct inode *inode, struct file *filp)
{
	printk("%s\n", __func__);

//	*mmio0_ptr = 0x02;		/* IRQ clear and Request receiving PHY#0 */

	return 0;
}

static ssize_t ipnuma_read(struct file *filp, char __user *buf,
			   size_t count, loff_t *ppos)
{
	int copy_len;

#ifdef DEBUG
	printk("%s\n", __func__);
#endif

#if 0
	if ( wait_event_interruptible( read_q, ( pbuf0.rx_read_ptr != pbuf0.rx_write_ptr ) ) )
		return -ERESTARTSYS;
#endif

	copy_len = count;

#if 0
	if ( copy_to_user( buf, pbuf0.rx_read_ptr, copy_len ) ) {
		printk( KERN_INFO "copy_to_user failed\n" );
		return -EFAULT;
	}
#endif

	return copy_len;
}

static ssize_t ipnuma_write(struct file *filp, const char __user *buf,
			    size_t count, loff_t *ppos)

{
	int copy_len;

	copy_len = count;

#ifdef DEBUG
	printk("%s\n", __func__);
#endif

#if 0
	if ( copy_from_user( mmio0_ptr, buf, copy_len ) ) {
		printk( KERN_INFO "copy_from_user failed\n" );
		return -EFAULT;
	}
#endif

	return copy_len;
}

static int ipnuma_release(struct inode *inode, struct file *filp)
{
	printk("%s\n", __func__);

//	*mmio0_ptr = 0x00;		/* IRQ clear and not Request receiving PHY#0 */

	return 0;
}

static unsigned int ipnuma_poll(struct file *filp, poll_table *wait)
{
	printk("%s\n", __func__);
	return 0;
}


static int ipnuma_ioctl(struct file *filp,
			unsigned int cmd, unsigned long arg)
{
	unsigned long *ptr, ret;
	printk("%s(cmd=%x)\n", __func__, cmd);
	switch (cmd) {
		// Get Physical addr
		case IPNUMA_IOCTL_GETPADDR: ptr = (unsigned long *)arg;
printk( "VA=%p\n", *ptr);
			ret = any_v2p(*ptr);
printk( "PA=%p\n", ret);
			*ptr = ret;
			break;
		// Get I/F IPv4
		case IPNUMA_IOCTL_GETIFV4ADDR: ptr = (unsigned long *)arg;
			memcpy(ptr, mmio0_ptr + 0, 4);
			break;
		// Set I/F IPv4
		case IPNUMA_IOCTL_SETIFV4ADDR: ptr = (unsigned long *)arg;
			memcpy(mmio0_ptr + 0, ptr, 4);
			break;
		// Get I/F MAC
		case IPNUMA_IOCTL_GETIFMACADDR: ptr = (unsigned long *)arg;
			memcpy(ptr, mmio0_ptr + 4, 6);
			break;
		// Set I/F MAC
		case IPNUMA_IOCTL_SETIFMACADDR: ptr = (unsigned long *)arg;
			memcpy(mmio0_ptr + 4, ptr, 6);
			break;
		// Get Dest IPv4
		case IPNUMA_IOCTL_GETDESTV4ADDR: ptr = (unsigned long *)arg;
			memcpy(ptr, mmio0_ptr + 0x10, 4);
			break;
		// Set Dest IPv4
		case IPNUMA_IOCTL_SETDESTV4ADDR: ptr = (unsigned long *)arg;
			memcpy(mmio0_ptr + 0x10, ptr, 4);
			break;
		// Get Dest MAC
		case IPNUMA_IOCTL_GETDESTMACADDR: ptr = (unsigned long *)arg;
			memcpy(ptr, mmio0_ptr + 0x14, 6);
			break;
		// Set Dest MAC
		case IPNUMA_IOCTL_SETDESTMACADDR: ptr = (unsigned long *)arg;
			memcpy(mmio0_ptr + 0x14, ptr, 6);
			break;
		// Get Mem0 Physical Address
		case IPNUMA_IOCTL_GETMEM0PADDR: ptr = (unsigned long *)arg;
			memcpy(ptr, mmio0_ptr + 0x28, 8);
			break;
		// Set Mem0 Physical Address
		case IPNUMA_IOCTL_SETMEM0PADDR: ptr = (unsigned long *)arg;
			memcpy(mmio0_ptr + 0x28, ptr, 8);
			break;
		// Get BAR2 Physical Address
		case IPNUMA_IOCTL_GETBARADDR: ptr = (unsigned long *)arg;
			*ptr = mmio1_start;
			break;
		default:
			return -ENOTTY;
	}

	return 0;
}

static struct file_operations ipnuma_fops = {
	.owner		= THIS_MODULE,
	.read		= ipnuma_read,
	.write		= ipnuma_write,
	.poll		= ipnuma_poll,
	.unlocked_ioctl	= ipnuma_ioctl,
	.open		= ipnuma_open,
	.release	= ipnuma_release,
};

static struct miscdevice ipnuma_dev = {
	.minor = MISC_DYNAMIC_MINOR,
	.name = DRV_NAME,
	.fops = &ipnuma_fops,
};


static int __devinit ipnuma_init_one (struct pci_dev *pdev,
				       const struct pci_device_id *ent)
{
	int rc;
	static char name[16];
	static int board_idx = -1;

	mmio0_ptr = 0L;
	mmio1_ptr = 0L;
	dma_virt_ptr = 0L;
	dma_phys_ptr = 0L;

	rc = pci_enable_device (pdev);
	if (rc)
		goto err_out;

	rc = pci_request_regions (pdev, DRV_NAME);
	if (rc)
		goto err_out;

	++board_idx;

	printk( KERN_INFO "board_idx: %d\n", board_idx );

	pci_set_master (pdev);		/* set BUS Master Mode */

	mmio0_start = pci_resource_start (pdev, 0);
	mmio0_end   = pci_resource_end   (pdev, 0);
	mmio0_flags = pci_resource_flags (pdev, 0);
	mmio0_len   = pci_resource_len   (pdev, 0);

	printk( KERN_INFO "mmio0_start: %X\n", (unsigned int)mmio0_start );
	printk( KERN_INFO "mmio0_end  : %X\n", (unsigned int)mmio0_end   );
	printk( KERN_INFO "mmio0_flags: %X\n", (unsigned int)mmio0_flags );
	printk( KERN_INFO "mmio0_len  : %X\n", (unsigned int)mmio0_len   );

	mmio0_ptr = ioremap(mmio0_start, mmio0_len);
	if (!mmio0_ptr) {
		printk(KERN_ERR "cannot ioremap MMIO0 base\n");
		goto err_out;
	}

	mmio1_start = pci_resource_start (pdev, 2);
	mmio1_end   = pci_resource_end   (pdev, 2);
	mmio1_flags = pci_resource_flags (pdev, 2);
	mmio1_len   = pci_resource_len   (pdev, 2);

	printk( KERN_INFO "mmio1_start: %X\n", (unsigned int)mmio1_start );
	printk( KERN_INFO "mmio1_end  : %X\n", (unsigned int)mmio1_end   );
	printk( KERN_INFO "mmio1_flags: %X\n", (unsigned int)mmio1_flags );
	printk( KERN_INFO "mmio1_len  : %X\n", (unsigned int)mmio1_len   );

	mmio1_ptr = ioremap_wc(mmio1_start, mmio1_len);
	if (!mmio1_ptr) {
		printk(KERN_ERR "cannot ioremap MMIO1 base\n");
		goto err_out;
	}

	dma_virt_ptr = dma_alloc_coherent( &pdev->dev, DMA_BUF_SIZE, &dma_phys_ptr, GFP_KERNEL);
	if (!dma_virt_ptr) {
		printk(KERN_ERR "cannot dma_alloc_coherent\n");
		goto err_out;
	}
	printk( KERN_INFO "dma_virt_ptr  : %X\n", (unsigned int)dma_virt_ptr );
	printk( KERN_INFO "dma_phys_ptr  : %X\n", (unsigned int)dma_phys_ptr );

	if (request_irq(pdev->irq, ipnuma_interrupt, IRQF_SHARED, DRV_NAME, pdev)) {
		printk(KERN_ERR "cannot request_irq\n");
	}
	
	pcidev = pdev;

	/* reset board */
//	*mmio0_ptr = 0x02;	/* Request receiving PHY#1 */

	sprintf( name, "%s/%d", DRV_NAME,  board_idx );
	ipnuma_dev.name = name,
	rc = misc_register(&ipnuma_dev);
	if (rc) {
		printk("fail to misc_register (MISC_DYNAMIC_MINOR)\n");
		return rc;
	}

	init_waitqueue_head( &write_q );
	init_waitqueue_head( &read_q );
	

	return 0;

err_out:
	pci_release_regions (pdev);
	pci_disable_device (pdev);
	return -1;
}


static void __devexit ipnuma_remove_one (struct pci_dev *pdev)
{
	disable_irq(pdev->irq);
	free_irq(pdev->irq, pdev);

	if (mmio0_ptr) {
		iounmap(mmio0_ptr);
		mmio0_ptr = 0L;
	}
	if (mmio1_ptr) {
		iounmap(mmio1_ptr);
		mmio1_ptr = 0L;
	}
	if ( dma_virt_ptr )
		dma_free_coherent(&pcidev->dev, DMA_BUF_SIZE, dma_virt_ptr, dma_phys_ptr);
	pci_release_regions (pdev);
	pci_disable_device (pdev);
	printk("%s\n", __func__);
	misc_deregister(&ipnuma_dev);
}


static struct pci_driver ipnuma_pci_driver = {
	.name		= DRV_NAME,
	.id_table	= ipnuma_pci_tbl,
	.probe		= ipnuma_init_one,
	.remove		= __devexit_p(ipnuma_remove_one),
#ifdef CONFIG_PM
//	.suspend	= ipnuma_suspend,
//	.resume		= ipnuma_resume,
#endif /* CONFIG_PM */
};


static int __init ipnuma_init(void)
{

#ifdef MODULE
	pr_info(ipnuma_DRIVER_NAME "\n");
#endif

	printk("%s\n", __func__);
	return pci_register_driver(&ipnuma_pci_driver);
}

static void __exit ipnuma_cleanup(void)
{
	printk("%s\n", __func__);
	pci_unregister_driver(&ipnuma_pci_driver);
}

MODULE_LICENSE("GPL");
module_init(ipnuma_init);
module_exit(ipnuma_cleanup);

