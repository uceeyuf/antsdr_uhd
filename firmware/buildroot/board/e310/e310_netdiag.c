// SPDX-License-Identifier: GPL-3.0-or-later
// Minimal ethtool ioctl helper for the RAM-only E310 diagnostic image.
#include <linux/ethtool.h>
#include <linux/sockios.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
static int fd; static struct ifreq req;
static void query(void *p) { req.ifr_data=p; if(ioctl(fd,SIOCETHTOOL,&req)<0){perror("SIOCETHTOOL");exit(1);} }
static unsigned number(const char *s) {char *end;unsigned long n=strtoul(s,&end,10);if(!*s||*s=='-'||*end||n>8192){fprintf(stderr,"invalid count\n");exit(2);}return n;}
int main(int argc,char **argv) {
 if(argc!=3 && argc!=5){fprintf(stderr,"Usage: e310-netdiag {rings|coalesce|stats} INTERFACE [RX TX]\n");return 2;}
 if(strlen(argv[2])>=IFNAMSIZ)return 2;
 strncpy(req.ifr_name,argv[2],IFNAMSIZ-1);fd=socket(AF_INET,SOCK_DGRAM,0);if(fd<0){perror("socket");return 1;}
 if(!strcmp(argv[1],"rings")) {
  struct ethtool_ringparam p={.cmd=ETHTOOL_GRINGPARAM};query(&p);
  if(argc==5){unsigned rx=number(argv[3]),tx=number(argv[4]);if(!rx||!tx||rx>p.rx_max_pending||tx>p.tx_max_pending)return 2;p.cmd=ETHTOOL_SRINGPARAM;p.rx_pending=rx;p.tx_pending=tx;query(&p);p.cmd=ETHTOOL_GRINGPARAM;query(&p);}
  printf("rx=%u tx=%u rx_max=%u tx_max=%u\n",p.rx_pending,p.tx_pending,p.rx_max_pending,p.tx_max_pending);
 } else if(!strcmp(argv[1],"coalesce")) {
  struct ethtool_coalesce p={.cmd=ETHTOOL_GCOALESCE};
  if(argc==5){unsigned rx=number(argv[3]),tx=number(argv[4]);if(!rx||!tx||rx>255||tx>255)return 2;p.cmd=ETHTOOL_SCOALESCE;p.rx_max_coalesced_frames=rx;p.tx_max_coalesced_frames=tx;query(&p);}else{query(&p);printf("rx_frames=%u tx_frames=%u\n",p.rx_max_coalesced_frames,p.tx_max_coalesced_frames);}
 } else if(!strcmp(argv[1],"stats") && argc==3) {
  struct ethtool_drvinfo info={.cmd=ETHTOOL_GDRVINFO};query(&info);unsigned n=info.n_stats;
  if(n>4096)return 2;
  struct ethtool_gstrings *names=calloc(1,sizeof(*names)+n*ETH_GSTRING_LEN);
  struct ethtool_stats *stats=calloc(1,sizeof(*stats)+n*sizeof(uint64_t));if(!names||!stats)return 1;
  names->cmd=ETHTOOL_GSTRINGS;names->string_set=ETH_SS_STATS;names->len=n;query(names);
  stats->cmd=ETHTOOL_GSTATS;stats->n_stats=n;query(stats);
  for(unsigned i=0;i<n;i++)printf("%.*s %llu\n",ETH_GSTRING_LEN,names->data+i*ETH_GSTRING_LEN,(unsigned long long)stats->data[i]);
  free(names);free(stats);
 } else return 2;
 close(fd);return 0;
}
