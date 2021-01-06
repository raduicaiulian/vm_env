#include <linux/netlink.h>
#include <sys/socket.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>

#define NETLINK_TESTFAMILY 25
#define MAX_PAYLOAD 1024

int main(int argc, char *argv[]) {
  int fd = socket(AF_NETLINK, SOCK_RAW, NETLINK_TESTFAMILY);
  if (fd < 0)
	printf("eroare la crearea socketului");

  struct sockaddr_nl addr; memset(&addr, 0, sizeof(addr));
  addr.nl_family = AF_NETLINK;
  addr.nl_pid = 0;  // For Linux kernel
  addr.nl_groups = 0;

  struct nlmsghdr *nlh = (struct nlmsghdr *) malloc(NLMSG_SPACE(MAX_PAYLOAD));
  memset(nlh, 0, NLMSG_SPACE(MAX_PAYLOAD));
  nlh->nlmsg_len = NLMSG_SPACE(MAX_PAYLOAD);
  nlh->nlmsg_pid = getpid();
  nlh->nlmsg_flags = 0;
  strcpy((char *) NLMSG_DATA(nlh), "Hello");

  struct iovec iov; memset(&iov, 0, sizeof(iov));
  iov.iov_base = (void *) nlh;
  iov.iov_len = nlh->nlmsg_len;

  struct msghdr msg; memset(&msg, 0, sizeof(msg));
  msg.msg_name = (void *) &addr;
  msg.msg_namelen = sizeof(addr);
  msg.msg_iov = &iov;
  msg.msg_iovlen = 1;

  printf("Sending message to kernel\n");
  sendmsg(fd, &msg, 0);

  return 0;
}