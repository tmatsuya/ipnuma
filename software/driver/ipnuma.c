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

#ifndef DRV_NAME
#define DRV_NAME        "pcidma"
#endif
#ifndef RX_ADDR
#define RX_ADDR         0x8000
#endif
#ifndef TX_ADDR
#define TX_ADDR         0x9000
#endif

#define	DRV_VERSION	"0.0.2"
#define	pcidma_DRIVER_NAME	DRV_NAME " PCIDMA driver " DRV_VERSION
#define	PACKET_BUF_MAX	(1024*1024)
#define	TEMP_BUF_MAX	2000

#define HEADER_LEN	16

#if LINUX_VERSION_CODE > KERNEL_VERSION(3,8,0)
#define	__devinit
#define	__devexit
#define	__devexit_p
#endif

static DEFINE_PCI_DEVICE_TABLE(pcidma_pci_tbl) = {
	{0x3776, 0x8010, PCI_ANY_ID, PCI_ANY_ID, 0, 0, 0 },
	{0,}
};
MODULE_DEVICE_TABLE(pci, pcidma_pci_tbl);

static unsigned char *mmio0_ptr = 0L, *mmio1_ptr = 0L, *dma_virt_ptr = 0L;
static dma_addr_t dma_phys_ptr = 0L;
static unsigned long mmio0_start, mmio0_end, mmio0_flags, mmio0_len;
static unsigned long mmio1_start, mmio1_end, mmio1_flags, mmio1_len;
static struct pci_dev *pcidev = NULL;
static wait_queue_head_t write_q;
static wait_queue_head_t read_q;

/* receive and transmitte buffer */
struct _pbuf_dma {
	unsigned char	*rx_start_ptr;		/* buf start */
	unsigned char 	*rx_end_ptr;		/* buf end */
	unsigned char	*rx_write_ptr;		/* write ptr */
	unsigned char	*rx_read_ptr;		/* read ptr */
} static pbuf0={0,0,0,0,0}, pbuf1={0,0,0,0,0};


static irqreturn_t pcidma_interrupt(int irq, struct pci_dev *pdev)
{
	unsigned int frame_len;

	frame_len = *(short *)(mmio0_ptr + RX_ADDR + 0x0c);
#ifdef DEBUG
	printk("%s\n", __func__);
	printk( "frame_len=%d\n", frame_len);
#endif

	if (frame_len < 64)
		frame_len = 64;

	if (frame_len > 1518)
		frame_len = 1518;

	if ( (pbuf0.rx_write_ptr +  frame_len + 0x10) > pbuf0.rx_end_ptr ) {
		memcpy( pbuf0.rx_start_ptr, pbuf0.rx_write_ptr, (pbuf0.rx_write_ptr - pbuf0.rx_start_ptr ));
		pbuf0.rx_read_ptr -= (pbuf0.rx_write_ptr - pbuf0.rx_start_ptr );
		if ( pbuf0.rx_read_ptr < pbuf0.rx_start_ptr )
			pbuf0.rx_read_ptr = pbuf0.rx_start_ptr;
		pbuf0.rx_write_ptr = pbuf0.rx_start_ptr;
	}

	memcpy(pbuf0.rx_write_ptr+0x04, mmio0_ptr+RX_ADDR, 0x0c);
	memcpy(pbuf0.rx_write_ptr+0x10, mmio0_ptr+RX_ADDR+0x10, frame_len);
	
	pbuf0.rx_write_ptr[0x00] = 0x55;			/* magic code 0x55d5 */
	pbuf0.rx_write_ptr[0x01] = 0xd5;
	*(short *)(pbuf0.rx_write_ptr + 2) = frame_len;

	pbuf0.rx_write_ptr += (frame_len + 0x10);

	*mmio0_ptr = 0x02;		/* IRQ clear and Request receiving PHY#0 */

	wake_up_interruptible( &read_q );

	return IRQ_HANDLED;
}

static int pcidma_open(struct inode *inode, struct file *filp)
{
	printk("%s\n", __func__);

	*mmio0_ptr = 0x02;		/* IRQ clear and Request receiving PHY#0 */

	return 0;
}

static ssize_t pcidma_read(struct file *filp, char __user *buf,
			   size_t count, loff_t *ppos)
{
	int copy_len, available_read_len;

#ifdef DEBUG
	printk("%s\n", __func__);
#endif

	if ( wait_event_interruptible( read_q, ( pbuf0.rx_read_ptr != pbuf0.rx_write_ptr ) ) )
		return -ERESTARTSYS;

	available_read_len = (pbuf0.rx_write_ptr - pbuf0.rx_read_ptr);

	if ( count > available_read_len )
		copy_len = available_read_len;
	else
		copy_len = count;


	if ( copy_to_user( buf, pbuf0.rx_read_ptr, copy_len ) ) {
		printk( KERN_INFO "copy_to_user failed\n" );
		return -EFAULT;
	}

	pbuf0.rx_read_ptr += copy_len;

	return copy_len;
}

static ssize_t pcidma_write(struct file *filp, const char __user *buf,
			    size_t count, loff_t *ppos)

{
	int copy_len;
	if ( count > 256 )
		copy_len = 256;
	else
		copy_len = count;
#ifdef DEBUG
	printk("%s\n", __func__);
#endif

	if ( copy_from_user( mmio0_ptr, buf, copy_len ) ) {
		printk( KERN_INFO "copy_from_user failed\n" );
		return -EFAULT;
	}

	return copy_len;
}

static int pcidma_release(struct inode *inode, struct file *filp)
{
	printk("%s\n", __func__);

	*mmio0_ptr = 0x00;		/* IRQ clear and not Request receiving PHY#0 */

	return 0;
}

static unsigned int pcidma_poll(struct file *filp, poll_table *wait)
{
	printk("%s\n", __func__);
	return 0;
}


static int pcidma_ioctl(struct inode *inode, struct file *filp,
			unsigned int cmd, unsigned long arg)
{
	printk("%s\n", __func__);
	return  -ENOTTY;
}

static struct file_operations pcidma_fops = {
	.owner		= THIS_MODULE,
	.read		= pcidma_read,
	.write		= pcidma_write,
	.poll		= pcidma_poll,
	.compat_ioctl	= pcidma_ioctl,
	.open		= pcidma_open,
	.release	= pcidma_release,
};

static struct miscdevice pcidma_dev = {
	.minor = MISC_DYNAMIC_MINOR,
	.name = DRV_NAME,
	.fops = &pcidma_fops,
};


static int __devinit pcidma_init_one (struct pci_dev *pdev,
				       const struct pci_device_id *ent)
{
	int rc;

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

	pci_set_master (pdev);		/* set BUS Master Mode */

	mmio0_start = pci_resource_start (pdev, 0);
	mmio0_end   = pci_resource_end   (pdev, 0);
	mmio0_flags = pci_resource_flags (pdev, 0);
	mmio0_len   = pci_resource_len   (pdev, 0);

	printk( KERN_INFO "mmio0_start: %X\n", mmio0_start );
	printk( KERN_INFO "mmio0_end  : %X\n", mmio0_end   );
	printk( KERN_INFO "mmio0_flags: %X\n", mmio0_flags );
	printk( KERN_INFO "mmio0_len  : %X\n", mmio0_len   );

	mmio0_ptr = ioremap(mmio0_start, mmio0_len);
	if (!mmio0_ptr) {
		printk(KERN_ERR "cannot ioremap MMIO0 base\n");
		goto err_out;
	}

	mmio1_start = pci_resource_start (pdev, 2);
	mmio1_end   = pci_resource_end   (pdev, 2);
	mmio1_flags = pci_resource_flags (pdev, 2);
	mmio1_len   = pci_resource_len   (pdev, 2);

	printk( KERN_INFO "mmio1_start: %X\n", mmio1_start );
	printk( KERN_INFO "mmio1_end  : %X\n", mmio1_end   );
	printk( KERN_INFO "mmio1_flags: %X\n", mmio1_flags );
	printk( KERN_INFO "mmio1_len  : %X\n", mmio1_len   );

	mmio1_ptr = ioremap_wc(mmio1_start, mmio1_len);
	if (!mmio1_ptr) {
		printk(KERN_ERR "cannot ioremap MMIO1 base\n");
		goto err_out;
	}

	dma_virt_ptr = dma_alloc_coherent( &pdev->dev, 1024*1024, &dma_phys_ptr, GFP_KERNEL);
	if (!dma_virt_ptr) {
		printk(KERN_ERR "cannot dma_alloc_coherent\n");
		goto err_out;
	}
	printk( KERN_INFO "dma_virt_ptr  : %X\n", dma_virt_ptr );
	printk( KERN_INFO "dma_phys_ptr  : %X\n", dma_phys_ptr );

	if (request_irq(pdev->irq, pcidma_interrupt, IRQF_SHARED, DRV_NAME, pdev)) {
		printk(KERN_ERR "cannot request_irq\n");
	}
	
	/* reset board */
	pcidev = pdev;
	*mmio0_ptr = 0x02;	/* Request receiving PHY#1 */

	return 0;

err_out:
	pci_release_regions (pdev);
	pci_disable_device (pdev);
	return -1;
}


static void __devexit pcidma_remove_one (struct pci_dev *pdev)
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
	pci_release_regions (pdev);
	pci_disable_device (pdev);
	printk("%s\n", __func__);
}


static struct pci_driver pcidma_pci_driver = {
	.name		= DRV_NAME,
	.id_table	= pcidma_pci_tbl,
	.probe		= pcidma_init_one,
	.remove		= __devexit_p(pcidma_remove_one),
#ifdef CONFIG_PM
//	.suspend	= pcidma_suspend,
//	.resume		= pcidma_resume,
#endif /* CONFIG_PM */
};


static int __init pcidma_init(void)
{
	int ret;

#ifdef MODULE
	pr_info(pcidma_DRIVER_NAME "\n");
#endif

	ret = misc_register(&pcidma_dev);
	if (ret) {
		printk("fail to misc_register (MISC_DYNAMIC_MINOR)\n");
		return ret;
	}

	if ( ( pbuf0.rx_start_ptr = kmalloc( PACKET_BUF_MAX, GFP_KERNEL) ) == 0 ) {
		printk("fail to kmalloc\n");
		return -1;
	}
	pbuf0.rx_end_ptr = (pbuf0.rx_start_ptr + PACKET_BUF_MAX - 1);
	pbuf0.rx_write_ptr = pbuf0.rx_start_ptr;
	pbuf0.rx_read_ptr  = pbuf0.rx_start_ptr;

	init_waitqueue_head( &write_q );
	init_waitqueue_head( &read_q );
	
	printk("%s\n", __func__);
	return pci_register_driver(&pcidma_pci_driver);
}

static void __exit pcidma_cleanup(void)
{
	printk("%s\n", __func__);
	misc_deregister(&pcidma_dev);
	pci_unregister_driver(&pcidma_pci_driver);
	if ( pbuf0.rx_start_ptr )
		kfree( pbuf0.rx_start_ptr );
	if ( dma_virt_ptr )
		dma_free_coherent(&pcidma_dev, 1024*1024, dma_virt_ptr, dma_phys_ptr);
}

MODULE_LICENSE("GPL");
module_init(pcidma_init);
module_exit(pcidma_cleanup);

