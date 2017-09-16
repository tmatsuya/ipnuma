#include <linux/semaphore.h>
#include <linux/etherdevice.h>
#include <linux/module.h>
#include <linux/miscdevice.h>
#include <linux/fs.h>
#include <linux/poll.h>
#include <linux/string.h>
#include <linux/pci.h>
#include <linux/wait.h>		/* wait_queue_head_t */
#include <linux/interrupt.h>
#include <linux/version.h>

#include <linux/types.h>
#include <linux/socket.h>
#include <linux/kernel.h>
#include <linux/netlink.h>
#include <linux/rtnetlink.h>
#include <linux/inet.h>
#include <linux/errno.h>
#include <linux/net.h>
#include <linux/in.h>
#include <linux/uaccess.h>
#include <linux/netdevice.h>
#include <linux/skbuff.h>
#include <linux/init.h>

#include <linux/if_packet.h>

#include <asm/pgtable_types.h>

//#define	DEBUG

#ifndef	DRV_NAME
#define	DRV_NAME	"virt2phys"
#endif
#define	DRV_VERSION	"0.1.0"
#define	virt2phys_DRIVER_NAME	DRV_NAME " Generic Etherpipe driver " DRV_VERSION

#if LINUX_VERSION_CODE > KERNEL_VERSION(3,8,0)
#define	__devinit
#define	__devexit
#define	__devexit_p
#endif

static int bad_address(void *p)
{
	unsigned long dummy;
	return probe_kernel_address((unsigned long*)p, dummy);
}

/*
 * map any virtual address of the current process to its
 * physical one.
 */
static unsigned long long any_v2p(unsigned long long vaddr)
{
	pgd_t *pgd = pgd_offset(current->mm, vaddr);
#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 12, 0)
	p4d_t *p4d;
#endif
	pud_t *pud;
	pmd_t *pmd;
	pte_t *pte;

	/* to lock the page */
	struct page *pg;
	unsigned long long paddr;

	if (bad_address(pgd)) {
		printk(KERN_ALERT "[nskk] Alert: bad address of pgd %p\n", pgd);
		goto bad;
	}
	if (!pgd_present(*pgd)) {
		printk(KERN_ALERT "[nskk] Alert: pgd not present %lu\n", *pgd);
		goto out;
	}

#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 12, 0)
	p4d = p4d_offset(pgd, vaddr);
	if (p4d_none(*p4d))
		return 0;
	pud = pud_offset(p4d, vaddr);
#else
	pud = pud_offset(pgd, vaddr);
#endif
#if 1
	if (bad_address(pud)) {
		printk(KERN_ALERT "[nskk] Alert: bad address of pud %p\n", pud);
		goto bad;
	}
	if (!pud_present(*pud) || pud_large(*pud)) {
		printk(KERN_ALERT "[nskk] Alert: pud not present %lu\n", *pud);
		goto out;
	}

	pmd = pmd_offset(pud, vaddr);
	if (bad_address(pmd)) {
		printk(KERN_ALERT "[nskk] Alert: bad address of pmd %p\n", pmd);
		goto bad;
	}
	if (!pmd_present(*pmd) || pmd_large(*pmd)) {
		printk(KERN_ALERT "[nskk] Alert: pmd not present %lu\n", *pmd);
		goto out;
	}

	pte = pte_offset_kernel(pmd, vaddr);
	if (bad_address(pte)) {
		printk(KERN_ALERT "[nskk] Alert: bad address of pte %p\n", pte);
		goto bad;
	}
	if (!pte_present(*pte)) {
		printk(KERN_ALERT "[nskk] Alert: pte not present %lu\n", *pte);
		goto out;
	}

	pg = pte_page(*pte);
#if 1
	paddr = (pte_val(*pte) & PHYSICAL_PAGE_MASK) | (vaddr&(PAGE_SIZE-1));
#else
	pte->pte |= _PAGE_RW; // | _PAGE_USER;
	paddr = pte_val(*pte);
#endif
#endif

out:
	return paddr;
bad:
	printk(KERN_ALERT "[nskk] Alert: Bad address\n");
	return 0;
}

static int virt2phys_open(struct inode *inode, struct file *filp)
{
	printk("%s\n", __func__);

	return 0;
}

static ssize_t virt2phys_read(struct file *filp, char __user *buf,
			   size_t count, loff_t *ppos)
{
	int copy_len;
#ifdef DEBUG
	printk("%s\n", __func__);
#endif
	copy_len = 0;

	return copy_len;
}

static ssize_t virt2phys_write(struct file *filp, const char __user *buf,
			    size_t count, loff_t *ppos)

{
	int copy_len;

	copy_len = 0;

	return copy_len;
}

static int virt2phys_release(struct inode *inode, struct file *filp)
{
	printk("%s\n", __func__);

	return 0;
}

static unsigned int virt2phys_poll( struct file* filp, poll_table* wait )
{
	unsigned int retmask = 0;

#ifdef DEBUG
	printk("%s\n", __func__);
#endif

	retmask |= POLLHUP;
/* 
   読み込みデバイスが EOF の場合は retmask に POLLHUP を設定
   デバイスがエラー状態である場合は POLLERR を設定
   out-of-band データが読み出せる場合は POLLPRI を設定
 */

	return retmask;
}


static long virt2phys_ioctl(struct file *filp,
			unsigned int cmd, unsigned long arg)
{
	unsigned long long *ptr, ret;
	printk("%s\n", __func__);
	if (cmd == 1) {
		ptr = (unsigned long long *)arg;
printk( "VA=%p\n", (unsigned long long *)*ptr);
		ret = any_v2p(*ptr);
printk( "PA=%p\n", (unsigned long long *)ret);
		*ptr = ret;
		return 0;
	}

	return  -ENOTTY;
}

static struct file_operations virt2phys_fops = {
	.owner		= THIS_MODULE,
	.read		= virt2phys_read,
	.write		= virt2phys_write,
	.poll		= virt2phys_poll,
	.unlocked_ioctl		= virt2phys_ioctl,
	.open		= virt2phys_open,
	.release	= virt2phys_release,
};

static struct miscdevice virt2phys_dev = {
	.minor = MISC_DYNAMIC_MINOR,
	.name = DRV_NAME,
	.fops = &virt2phys_fops,
};

static int __init virt2phys_init(void)
{
	int ret;

#ifdef MODULE
	pr_info(virt2phys_DRIVER_NAME "\n");
#endif
	printk("%s\n", __func__);

	ret = misc_register(&virt2phys_dev);
	if (ret) {
		printk("fail to misc_register (MISC_DYNAMIC_MINOR)\n");
		goto error;
	}

	return 0;

error:
	return ret;
}

static void __exit virt2phys_cleanup(void)
{
	misc_deregister(&virt2phys_dev);

	printk("%s\n", __func__);
}

MODULE_LICENSE("GPL");
module_init(virt2phys_init);
module_exit(virt2phys_cleanup);

