#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/netlink.h>
#include <net/netlink.h>
#include <net/net_namespace.h>

#define NETLINK_TESTFAMILY 25

struct sock *socket;

static void test_nl_receive_message(struct sk_buff *skb) {
  printk(KERN_INFO "Entering: %s\n", __FUNCTION__);

  struct nlmsghdr *nlh = (struct nlmsghdr *) skb->data;
  printk(KERN_INFO "Received message: %s\n", (char*) nlmsg_data(nlh));
}

static int __init test_init(void) {
  printk(KERN_INFO "INSERTING MODULE\n");
  struct netlink_kernel_cfg config = {
    .input = test_nl_receive_message,
  };

  socket = netlink_kernel_create(&init_net, NETLINK_TESTFAMILY, &config);
  if (socket == NULL) {
    return -1;
  }

  return 0;
}

static void __exit test_exit(void) {
  	
  if (socket) {
    netlink_kernel_release(socket);
  }
  printk(KERN_INFO "MODULE UNLOADED\n");
  
}

module_init(test_init);
module_exit(test_exit);

MODULE_LICENSE("GPL");